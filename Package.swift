// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import PackageDescription

let package = Package(
    name: "cgjprofile",
    products: [
        .executable(name: "cgjprofile", targets: ["cgjprofile"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.0"),
        .package(url: "https://github.com/below/cgjProfileLib", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "cgjprofile",
            dependencies: ["cgjprofileLib", "ArgumentParser"]),
    ]
)
