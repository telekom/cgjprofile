/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import Darwin
import SPMUtility
import cgjprofileLib

do {
    let arguments = Array(CommandLine.arguments.dropFirst()) // Don't include the command name
    
    let parser = ArgumentParser(usage: "[--format=\"format string\"] [--warn-expiration days] [--quiet] [path]", overview: "Lists all mobileprovision files, or a single one")
    
    let formatOption: OptionArgument<String> = parser.add(option: "--format", shortName: "-f", kind: String.self, usage: "Optional format String\n      %e  ExpirationDate\n      %c  CreationDate\n      %u  UUID\n      %a  AppIDName\n      %t  TeamName\n      %n  Name")
    let warningsOption: OptionArgument<Int> = parser.add(option: "--warnExpiration", shortName: "-w", kind: Int.self, usage: "Set days to warn about expiration")
    let quietOption: OptionArgument<Bool> = parser.add(option: "--quiet", shortName: "-q", kind: Bool.self, usage: "Don't print any output")
    let expressionOption: OptionArgument<String> = parser.add(option: "--regex", shortName: "-g", kind: String.self, usage: "Optional regular Expression. Only items matching this will be shown")
    let pathsOption = parser.add(positional: "path", kind: [String].self, optional:true, usage:"Optional paths to, or UDIDs of, mobileprovision files")
    let parsedArguments = try parser.parse(arguments)
    
    let workingPaths = parsedArguments.get(pathsOption)
    let format = parsedArguments.get(formatOption)
    let warnDays = parsedArguments.get(warningsOption)
    let quiet = parsedArguments.get(quietOption)
    let regex = parsedArguments.get(expressionOption)
    
    let result = try CgjProfileCore.analyzeMobileProfiles(format: format, pathsUDIDsOrNames: workingPaths, regEx: regex, warnDays: warnDays, quiet: quiet)

    exit(result)
} catch {
    fputs("Whoops! An error occurred: \(error)", stderr)
    exit(EXIT_FAILURE)
}
