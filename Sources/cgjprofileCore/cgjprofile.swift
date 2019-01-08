/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import Foundation
import Security
import Utility
import Darwin

public final class cgjprofileTool {
    private let arguments: [String]

    public init(arguments: [String] = CommandLine.arguments) { 
        self.arguments = Array(arguments.dropFirst()) // Don't include the command name
    }
    
    // No clue why I have to specify Foundation here
    func workingURLs (paths : [String]? = nil) -> [Foundation.URL] {
        if let paths = paths {
            return paths.map {
                URL(fileURLWithPath: $0)
            }
        }
        else {
            let fm = FileManager.default
            let librayURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let profilesURL = librayURL.appendingPathComponent("MobileDevice/Provisioning Profiles")
            return try! FileManager.default.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        }
    }
    
    public func run() throws -> Int32 {
        
        var result = EXIT_SUCCESS
        
        let parser = ArgumentParser(usage: "[--format=\"format string\" [path]", overview: "Lists all mobileprovision files, or a single one")
        
        let formatOption: OptionArgument<String> = parser.add(option: "--format", shortName: "-f", kind: String.self, usage: "Optional format String\n      %e  ExpirationDate\n      %c  CreationDate\n      %u  UUID\n      %a  AppIDName\n      %t  TeamName\n      %n  Name")
        let warningsOption: OptionArgument<Int> = parser.add(option: "--warnExpiration", shortName: "-w", kind: Int.self, usage: "Set days to warn about expiration")
        let quietOption: OptionArgument<Bool> = parser.add(option: "--quiet", shortName: "-q", kind: Bool.self, usage: "Don't print any output")
        let pathsOption = parser.add(positional: "path", kind: [String].self, optional:true, usage:"Optional paths to mobileprovision files")

        let parsedArguments = try parser.parse(arguments)
        
        let workingPaths = workingURLs(paths: parsedArguments.get(pathsOption))
        var format : String!
        format = parsedArguments.get(formatOption)
        if format == nil {
            format = "%u %t %n"
        }
        let warnDays = parsedArguments.get(warningsOption)
        let quiet = parsedArguments.get(quietOption) ?? false
        
        let identifyCertificates = try Mobileprovision.identifyCertificates()
        
        for url in workingPaths {
            if let provision = PrettyProvision(url: url) {
                if !quiet {
                    provision.print(format: format, warnDays:warnDays)
                }
                let ANSI_COLOR_RED = "\u{001b}[31m"
                let ANSI_COLOR_YELLOW = "\u{001b}[33m"
                let ANSI_COLOR_RESET = "\u{001b}[0m"
                let daysToExpiration = provision.daysToExpiration
                if daysToExpiration <= 0 {

                    let description = "\(ANSI_COLOR_RED)ERROR: \(provision.UUID) \(provision.Name) is expired\(ANSI_COLOR_RESET)\n"
                    fputs(description, stderr)
                    result = EXIT_FAILURE
                } else if let warnDays = warnDays, daysToExpiration <= warnDays {
                    let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.UUID) will expire in \(daysToExpiration) days\(ANSI_COLOR_RESET)\n"
                    fputs(description, stderr)
                }
                
                // Stop checking if the certificate is expired anyway
                guard result == EXIT_SUCCESS else {
                    continue
                }
                
                var validCertificateFound = false
                for certificate in provision.DeveloperCertificates {
                    do {
                        
                        let certName = try certificate.displayName()
                        if let exisitingCertificate = identifyCertificates[certName], exisitingCertificate == certificate {
                            
                            let date = try certificate.enddate()
                            let daysToExpiration = Mobileprovision.daysToExpiration(for: date)
                            
                            if daysToExpiration <= 0 {
                                let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.UUID) \(provision.Name) certificate \(certName) is expired\(ANSI_COLOR_RESET)\n"
                                fputs(description, stderr)
                            } else {
                                
                                validCertificateFound = true
                                
                                if let warnDays = warnDays, daysToExpiration <= warnDays {
                                    let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.UUID) certificate \(certName) will expire in \(daysToExpiration) days\(ANSI_COLOR_RESET)\n"
                                    fputs(description, stderr)
                                }
                            }
                        }
                        else {
                            let description = "\(ANSI_COLOR_YELLOW)WARNING: \(provision.UUID) \(provision.Name) certificate \(certName) is not present in keychain\(ANSI_COLOR_RESET)\n"
                            fputs(description, stderr)
                        }
                    }
                    catch {
                        throw error
                    }
                }
                if !validCertificateFound {
                    result = EXIT_FAILURE
                    let description = "\(ANSI_COLOR_RED)ERROR: \(provision.UUID) \(provision.Name) No valid certificates found\(ANSI_COLOR_RESET)\n"
                    fputs(description, stderr)

                }
            }
            else {
                let output = "Error decoding \(url)\n"
                fputs(output, stderr)
            }
        }
        return result
    }
}

