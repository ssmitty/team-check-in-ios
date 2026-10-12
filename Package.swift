// swift-tools-version: 6.0
// Package.swift
// Purpose: Run portable tests for the prototype's models and service state.
import PackageDescription

let package = Package(
    name: "TeamCheckInCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "TeamCheckInCore", targets: ["TeamCheckInCore"])],
    targets: [
        .target(name: "TeamCheckInCore", path: "TeamCheckIn/Core"),
        .testTarget(
            name: "TeamCheckInCoreTests", dependencies: ["TeamCheckInCore"],
            path: "TeamCheckInTests"),
    ]
)
