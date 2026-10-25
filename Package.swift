// swift-tools-version: 6.0
// game-kit's Swift side for SwiftPM (docs/swift-core.md). GamepadCore is the game-agnostic pad
// logic in plain Swift (Foundation only), so engines that test on Linux can depend on it:
//   .package(url: "https://github.com/the-deep-friar/game-kit.git", exact: "0.5.0")
// Versions are bare semver tags (`0.4.1`) matching packages/gamepad's version. The same sources
// ship in the @game-kit/gamepad npm tarball as the `GamepadCore` pod, for CocoaPods builds.
//
// On Apple platforms it also has `Gamepad`: `PadReader` (and the files it needs) for a native app
// with no Expo, e.g. a SwiftUI + SpriteKit game. The same sources as the `Gamepad` pod minus the
// Expo module. GameController doesn't exist on Linux, so the manifest leaves it out there.
import PackageDescription

var products: [Product] = [.library(name: "GamepadCore", targets: ["GamepadCore"])]
var targets: [Target] = [
  .target(name: "GamepadCore", path: "packages/gamepad/ios/GamepadCore"),
  .testTarget(name: "GamepadCoreTests", dependencies: ["GamepadCore"], path: "packages/gamepad/ios-tests/GamepadCoreTests"),
]

#if !os(Linux)
products.append(.library(name: "Gamepad", targets: ["Gamepad"]))
targets.append(.target(
  name: "Gamepad",
  dependencies: ["GamepadCore"],
  path: "packages/gamepad/ios",
  exclude: ["GamepadCore", "GamepadModule.swift", "Gamepad.podspec", "GamepadCore.podspec"],
  sources: ["PadMapping.swift", "PadReader.swift", "PadRegistry.swift"],
  // Built in Swift 5 mode, as the pod is: its GameController handlers predate strict concurrency.
  swiftSettings: [.swiftLanguageMode(.v5)]
))
#endif

let package = Package(
  name: "game-kit",
  platforms: [.iOS(.v18), .tvOS(.v18), .macOS(.v15)],
  products: products,
  targets: targets,
  swiftLanguageModes: [.v6]
)
