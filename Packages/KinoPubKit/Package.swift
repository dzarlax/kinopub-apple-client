// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "KinoPubKit",
  platforms: [.macOS(.v13), .iOS(.v16)],
  products: [
    .library(
      name: "KinoPubKit",
      targets: ["KinoPubKit"])
  ],
  dependencies: [
    .package(name: "KinoPubLogging", path: "../KinoPubLogging"),
    .package(name: "KinoPubBackend", path: "../KinoPubBackend")
  ],
  targets: [
    .target(
      name: "KinoPubKit",
      dependencies: [
        .product(name: "KinoPubLogging", package: "KinoPubLogging"),
        .product(name: "KinoPubBackend", package: "KinoPubBackend")
      ]),
      .testTarget(
        name: "KinoPubKitTests",
        dependencies: ["KinoPubKit"])
  ]
)
