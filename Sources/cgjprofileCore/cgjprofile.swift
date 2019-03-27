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
import SPMUtility
import Darwin

public final class cgjprofileTool {
    private let arguments: [String]

    
    public init(arguments: [String] = CommandLine.arguments) { 
        self.arguments = Array(arguments.dropFirst()) // Don't include the command name
    }
    
    static var mobileProvisionURL : Foundation.URL = {
        let fm = FileManager.default
        let librayURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return librayURL.appendingPathComponent("MobileDevice/Provisioning Profiles")
    }()
    
    static let mobileprovisionExtension = "mobileprovision"

    static func profilePaths (paths : [String]? = nil) -> [String] {
        
        let urls = try! FileManager.default.contentsOfDirectory(at: self.mobileProvisionURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        return urls.map({ (url) -> String in
            url.path
        })
    }
    
    static func profileURL (path : String) throws -> Foundation.URL {
        let fm = FileManager.default
        var url : Foundation.URL! = URL(fileURLWithPath: path)
        if !fm.fileExists(atPath: url.path) {
            url = mobileProvisionURL.appendingPathComponent(path)
        }
        if !fm.fileExists(atPath: url.path) {
            url = url.appendingPathExtension(mobileprovisionExtension)
        }
        if !fm.fileExists(atPath: url.path) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [NSFilePathErrorKey:path])
        }
        return url
    }
    
    public func analyzeMobileProfiles (format: String? = nil, pathsUDIDsOrNames : [String]? = nil,  warnDays : Int? = nil, quiet quietArg: Bool? = false) throws -> Int32 {
        
        var result = EXIT_SUCCESS

        let workingPaths : [String] = pathsUDIDsOrNames ?? cgjprofileTool.profilePaths()
        let quiet = quietArg ?? false
        
        let identifyCertificates = try Mobileprovision.identifyCertificates()
        
        for path in workingPaths {
            var url : Foundation.URL! = URL(fileURLWithPath: path)
            if url == nil {
                url = cgjprofileTool.mobileProvisionURL.appendingPathComponent(path)
            }
            if let provision = PrettyProvision(url: url) {
                if !quiet {
                    provision.print(format: format ?? "%u %t %n", warnDays:warnDays)
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
                let output = "Error decoding \(url?.absoluteString ?? "No URL")\n"
                fputs(output, stderr)
            }
        }
        return result
    }
    
    public func run() throws -> Int32 {
        
        let parser = ArgumentParser(usage: "[--format=\"format string\"] [--warn-expiration days] [--quiet] [path]", overview: "Lists all mobileprovision files, or a single one")
        
        let formatOption: OptionArgument<String> = parser.add(option: "--format", shortName: "-f", kind: String.self, usage: "Optional format String\n      %e  ExpirationDate\n      %c  CreationDate\n      %u  UUID\n      %a  AppIDName\n      %t  TeamName\n      %n  Name")
        let warningsOption: OptionArgument<Int> = parser.add(option: "--warnExpiration", shortName: "-w", kind: Int.self, usage: "Set days to warn about expiration")
        let quietOption: OptionArgument<Bool> = parser.add(option: "--quiet", shortName: "-q", kind: Bool.self, usage: "Don't print any output")
        let pathsOption = parser.add(positional: "path", kind: [String].self, optional:true, usage:"Optional paths to, or UDIDs of, mobileprovision files")

        let parsedArguments = try parser.parse(arguments)
        
        let workingPaths = parsedArguments.get(pathsOption)
        let format = parsedArguments.get(formatOption)
        let warnDays = parsedArguments.get(warningsOption)
        let quiet = parsedArguments.get(quietOption)
        
        return try analyzeMobileProfiles(format: format, pathsUDIDsOrNames: workingPaths, warnDays: warnDays, quiet: quiet)
    }
}

