/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import Darwin
import ArgumentParser
import cgjprofileLib

internal func allowDeletion(items: [String]) -> Bool {
    
    fputs("The following files will be deleted:\n", stdout)
    for item in items {
        fputs("- " + item + "\n", stdout)
    }
    fputs("\nDo you want to proceed (Y/n)?", stdout)
    let result = readLine()
    if result?.prefix(1) == "Y" {
        return true
    }
    return false
}


struct Cgjprofile: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Lists all mobileprovision files, or a single one")

    @Option(name: [.short, .customLong("warnExpiration")], help: "Set days to warn about expiration")
    var warnExpiration: Int = 0

    @Option(name: [.short, .long], help: "%e  ExpirationDate\n%c  CreationDate\n%u  UUID\n%a  AppIDName\n%t  TeamName\n%n  Name")
    var format: String = "%u %t %n"

    @Flag(name: [.short, .long], help: "Don't print any output (only errors")
    var quiet = false

    @Flag(name: [.customLong("r", withSingleDash: true)], help: "Delete expired files after confirmation")
    var delete = false

    @Argument(help: "Optional paths to, or UDIDs of, mobileprovision files")
    var paths = [String]()

    func run() throws {
        do {
            _ = try CgjProfileCore.analyzeMobileProfiles(format: format, pathsUDIDsOrNames: (paths.count > 0) ? paths:nil, regEx: nil, warnDays: warnExpiration, quiet: quiet, deletionHandler: delete ? allowDeletion:nil)
        } catch {
            fputs("Whoops! An error occurred: \(error)", stderr)
            throw error
        }

    }
}

Cgjprofile.main()   
