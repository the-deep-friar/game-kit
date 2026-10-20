import Foundation
import Testing

@testable import GamepadCore

@Suite("controls")
struct ControlTests {
  @Test("names and order are @game-kit/gamepad's CONTROLS")
  func order() {
    #expect(PadControl.allCases.map(\.rawValue) == [
      "south", "east", "west", "north", "leftShoulder", "rightShoulder", "leftTrigger", "rightTrigger",
      "leftStickButton", "rightStickButton", "dpadUp", "dpadDown", "dpadLeft", "dpadRight", "menu", "options",
    ])
    #expect(PadShape.allCases.map(\.rawValue) == ["full", "singleJoyCon"])
    #expect(PadLayout.allCases.map(\.rawValue) == ["nintendo", "xbox", "playstation", "other"])
  }
}

@Suite("pad kinds from GameController's names")
struct KindTests {
  @Test("layout")
  func layout() {
    #expect(PadKind.layout(productCategory: "Switch Pro Controller", vendorName: "Pro Controller") == .nintendo)
    #expect(PadKind.layout(productCategory: "Joy-Con (L/R)", vendorName: nil) == .nintendo)
    #expect(PadKind.layout(productCategory: "Nintendo Switch Controller", vendorName: nil) == .nintendo)
    #expect(PadKind.layout(productCategory: "Xbox One", vendorName: "Xbox Wireless Controller") == .xbox)
    #expect(PadKind.layout(productCategory: "DualSense", vendorName: nil) == .playstation)
    #expect(PadKind.layout(productCategory: "DualShock 4", vendorName: nil) == .playstation)
    #expect(PadKind.layout(productCategory: "Gamepad", vendorName: "2.4G Wireless Receiver") == .other)
  }

  @Test("a lone Joy-Con is its own shape; a pair is full")
  func shape() {
    #expect(PadKind.shape(productCategory: "Joy-Con (L)", vendorName: nil) == .singleJoyCon)
    #expect(PadKind.shape(productCategory: "Joy-Con (R)", vendorName: "Joy-Con (R)") == .singleJoyCon)
    #expect(PadKind.shape(productCategory: "Joy-Con (L/R)", vendorName: nil) == .full)
    #expect(PadKind.shape(productCategory: "Switch Pro Controller", vendorName: nil) == .full)
    #expect(PadKind.shape(productCategory: "Gamepad", vendorName: nil) == .full)
  }

  @Test("the Nintendo face fix trusts the pad's own buttonA picture")
  func faces() {
    #expect(PadKind.faces(productCategory: "Switch Pro Controller", vendorName: nil, buttonASymbol: "a.circle") == .nintendoLabels)
    #expect(PadKind.faces(productCategory: "Switch Pro Controller", vendorName: nil, buttonASymbol: "a.circle.fill") == .nintendoLabels)
    #expect(PadKind.faces(productCategory: "Switch Pro Controller", vendorName: nil, buttonASymbol: "b.circle") == .positional)
    #expect(PadKind.faces(productCategory: "Joy-Con (R)", vendorName: nil, buttonASymbol: nil) == .positional)
    #expect(PadKind.faces(productCategory: "Xbox", vendorName: nil, buttonASymbol: "a.circle") == .positional)
    #expect(PadKind.faces(productCategory: "DualSense", vendorName: nil, buttonASymbol: "xmark.circle") == .positional)
  }

  @Test("face controls map to Apple's buttons by position, swapped back for Nintendo letters")
  func appleButtons() {
    let positional = [PadControl.south, .east, .west, .north].map { PadKind.appleButton(for: $0, faces: .positional) }
    #expect(positional == [.a, .b, .x, .y])
    let nintendo = [PadControl.south, .east, .west, .north].map { PadKind.appleButton(for: $0, faces: .nintendoLabels) }
    #expect(nintendo == [.b, .a, .y, .x])
    for control in PadControl.allCases.dropFirst(4) {
      #expect(PadKind.appleButton(for: control, faces: .positional) == nil)
      #expect(PadKind.appleButton(for: control, faces: .nintendoLabels) == nil)
    }
  }
}

@Suite("sticks, as input-actions' stickDirections")
struct StickTests {
  func dirs(_ x: Double, _ y: Double, _ deadZone: Double = Sticks.defaultDeadZone) -> [StickDirection] {
    Sticks.directions(StickValue(x: x, y: y), deadZone: deadZone)
  }

  @Test("none inside the dead zone, its edge included")
  func deadZone() {
    #expect(Sticks.defaultDeadZone == 0.3)
    #expect(dirs(0, 0) == [])
    #expect(dirs(0.3, 0) == [])
    #expect(dirs(0, -0.3) == [])
    #expect(dirs(0.3000001, 0) == [.right])
    #expect(dirs(0.2, 0.2) == [])
    #expect(dirs(0.5, 0, 0.6) == [])
  }

  @Test("eight ways, diagonals hold both")
  func eightWays() {
    #expect(dirs(1, 0) == [.right])
    #expect(dirs(1, 1) == [.up, .right])
    #expect(dirs(0, 1) == [.up])
    #expect(dirs(-1, 1) == [.up, .left])
    #expect(dirs(-1, 0) == [.left])
    #expect(dirs(-1, -1) == [.down, .left])
    #expect(dirs(0, -1) == [.down])
    #expect(dirs(1, -1) == [.down, .right])
    #expect(dirs(1, 0.2) == [.right])
  }

  @Test("an eighth's edge rounds as Math.round does: halves go up")
  func edges() {
    #expect(jsRound(0.5) == 1)
    #expect(jsRound(-0.5) == 0)
    #expect(jsRound(-1.5) == -1)
    #expect(jsRound(2.4) == 2)
    #expect(dirs(-1, -0.0000001) == [.left])
    #expect(dirs(-1, 0) == [.left])
  }

  @Test("jsHypot is V8's Math.hypot")
  func hypot() {
    #expect(jsHypot(0.3, 0) == 0.3)
    #expect(jsHypot(0, -0.3) == 0.3)
    #expect(jsHypot(0, 0) == 0)
    #expect(jsHypot(3, 4) == 5)
    #expect(jsHypot(.infinity, .nan) == .infinity)
    #expect(jsHypot(.nan, 1).isNaN)
  }
}

@Suite("action maps, as input-actions' padActions")
struct ActionTests {
  enum Action: String, Hashable, Sendable { case jump, dig, left, right, aimUp }

  let bindings: [Action: [PadBinding]] = [
    .jump: [.button(.south)],
    .dig: [.button(.rightTrigger), .button(.rightShoulder)],
    .left: [.stick(.leftStick, .left), .button(.dpadLeft)],
    .right: [.stick(.leftStick, .right), .button(.dpadRight)],
    .aimUp: [.stick(.leftStick, .up), .stick(.rightStick, .up)],
  ]

  @Test("held by any button down or stick pushed")
  func held() {
    let frame = PadActions.frame(PadState(down: [.south, .dpadLeft], rightStick: StickValue(x: 0.7, y: 0.7)), bindings)
    #expect(frame.held == [.jump, .left, .aimUp])
    #expect(frame.pressed == [])
  }

  @Test("pressed by a button's latch, even if already up; sticks never press")
  func pressed() {
    let frame = PadActions.frame(PadState(pressed: [.rightShoulder], leftStick: StickValue(x: 1, y: 0)), bindings)
    #expect(frame.held == [.right])
    #expect(frame.pressed == [.dig])
  }

  @Test("the dead zone is the caller's to set")
  func deadZone() {
    let pad = PadState(leftStick: StickValue(x: -0.5, y: 0))
    #expect(PadActions.frame(pad, bindings).held == [.left])
    #expect(PadActions.frame(pad, bindings, deadZone: 0.6).held == [])
  }

  @Test("unbound controls do nothing")
  func unbound() {
    let frame = PadActions.frame(PadState(down: [.menu, .options], pressed: [.menu]), bindings)
    #expect(frame == PadActionFrame())
  }
}
