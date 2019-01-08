/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import Darwin
import cgjprofileCore

let tool = cgjprofileTool()

do {
    let result = try tool.run()
    exit(result)
} catch {
    fputs("Whoops! An error occurred: \(error)", stderr)
    exit(EXIT_FAILURE)
}
