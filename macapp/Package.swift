// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LotteryChecker",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "LotteryKit"),
        .executableTarget(name: "LotteryChecker", dependencies: ["LotteryKit"]),
        .testTarget(name: "LotteryKitTests", dependencies: ["LotteryKit"]),
    ]
)
