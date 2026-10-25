// swift-tools-version: 6.0
// game-kit's Swift side for SwiftPM (docs/swift-core.md). GamepadCore is the game-agnostic pad
// logic in plain Swift (Foundation only), so engines that test on Linux can depend on it:
//   .package(url: "https://github.com/the-deep-friar/game-kit.git", exact: "0.4.1")
// Versions are bare semver tags (`0.4.1`) matching packages/gamepad's version. The same sources
// ship in the @game-kit/gamepad npm tarball as the `GamepadCore` pod, for CocoaPods builds.
import PackageDescription

let package = Package(
  name: "game-kit",
  platforms: [.iOS(.v18), .tvOS(.v18), .macOS(.v15)],
  products: [.library(name: "GamepadCore", targets: ["GamepadCore"])],
  targets: [
    .target(name: "GamepadCore", path: "packages/gamepad/ios/GamepadCore"),
    .testTarget(name: "GamepadCoreTests", dependencies: ["GamepadCore"], path: "packages/gamepad/ios-tests/GamepadCoreTests"),
  ],
  swiftLanguageModes: [.v6]
)
