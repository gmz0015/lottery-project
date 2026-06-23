// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LotteryKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LotteryKit", targets: ["LotteryKit"]),
    ],
    targets: [
        .target(name: "LotteryKit"),
        .testTarget(name: "LotteryKitTests", dependencies: ["LotteryKit"]),
    ]
)
