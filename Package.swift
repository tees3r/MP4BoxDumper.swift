// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MP4BoxDumper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "MP4BoxDumper",
            targets: ["MP4BoxDumper"])
    ],
    dependencies: [],
    targets: [
        .target(
          name: "MP4BoxDumper",
          dependencies: [],
          path: "Sources/MP4BoxDumper"),
        .target(
            name: "MP4BoxDumperExecutable",
            dependencies: ["MP4BoxDumper"],
            path: "Sources/MP4BoxDumperExecutable"),
        .testTarget(
          name: "CoreTests",
          dependencies: ["MP4BoxDumper"],
          path: "Tests/CoreTests")
    ]
)
