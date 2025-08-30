// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ConvexClerk",
  platforms: [
    .iOS(.v17),
    .macOS(.v14)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "ConvexClerk",
      targets: ["ConvexClerk"])
  ],
  dependencies: [
    .package(url: "https://github.com/get-convex/convex-swift", from: "0.5.5"),
    .package(url: "https://github.com/clerk/clerk-ios", from: "0.66.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "ConvexClerk",
      dependencies: [
        .product(name: "ConvexMobile", package: "convex-swift"),
        .product(name: "Clerk", package: "clerk-ios"),
      ]),
    .testTarget(
      name: "ConvexClerkTests",
      dependencies: ["ConvexClerk"]
    ),
  ]
)