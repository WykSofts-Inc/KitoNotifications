// swift-tools-version: 5.9
//
//  Package.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoNotifications",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoNotifications", targets: ["KitoNotifications"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "KitoNotifications", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(name: "KitoNotificationsTests", dependencies: ["KitoNotifications"]),
    ]
)
