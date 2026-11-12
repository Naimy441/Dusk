import Foundation
import Combine

/// Controls the built-in keyboard backlight through CoreBrightness's
/// `KeyboardBrightnessClient`. macOS has no public API for this, so the class is looked up at runtime.
/// If it is missing (e.g. a desktop Mac or a future macOS), the feature hides itself.
@MainActor
final class KeyboardBacklight: ObservableObject {
    static let shared = KeyboardBacklight()

    @Published private(set) var isAvailable = false
    @Published private(set) var isOn = false
    /// Current backlight level, 0...1.
    @Published private(set) var brightness: Double = 0

    private typealias GetLevel = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetLevel = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool

    private var client: NSObject?
    private var keyboardID: UInt64 = 0
    private var getLevel: GetLevel?
    private var setLevel: SetLevel?
    private let getSel = NSSelectorFromString("brightnessForKeyboard:")
    private let setSel = NSSelectorFromString("setBrightness:forKeyboard:")

    private let levelKey = "keyboardLevel"
    /// Below this the backlight is effectively dark.
    private let offThreshold: Float = 0.01

    private init() {
        guard
            Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.load() == true,
            let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else { return }
        let client = cls.init()
        let idsSel = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard
            client.responds(to: idsSel), client.responds(to: getSel), client.responds(to: setSel),
            let ids = client.perform(idsSel)?.takeUnretainedValue() as? [NSNumber],
            !ids.isEmpty
        else { return }

        // Prefer the built-in keyboard when several are reported.
        typealias IsBuiltIn = @convention(c) (AnyObject, Selector, UInt64) -> Bool
        let builtInSel = NSSelectorFromString("isKeyboardBuiltIn:")
        var chosen = ids[0].uint64Value
        if client.responds(to: builtInSel) {
            let isBuiltIn = unsafeBitCast(client.method(for: builtInSel), to: IsBuiltIn.self)
            if let id = ids.first(where: { isBuiltIn(client, builtInSel, $0.uint64Value) }) {
                chosen = id.uint64Value
            }
        }

        self.client = client
        keyboardID = chosen
        getLevel = unsafeBitCast(client.method(for: getSel), to: GetLevel.self)
        setLevel = unsafeBitCast(client.method(for: setSel), to: SetLevel.self)
        UserDefaults.standard.register(defaults: [levelKey: 0.5])
        isAvailable = true
        refresh()
    }

    private var level: Float {
        guard let client, let getLevel else { return 0 }
        return getLevel(client, getSel, keyboardID)
    }

    /// Re-read the hardware state (the user may have used the F-keys).
    func refresh() {
        guard isAvailable else { return }
        let current = level
        let on = current > offThreshold
        if on != isOn { isOn = on }
        let value = on ? Double(current) : 0
        if abs(value - brightness) > 0.001 { brightness = value }
    }

    func setOn(_ on: Bool) {
        guard isAvailable, let client, let setLevel else { return }
        if on {
            let saved = Float(UserDefaults.standard.double(forKey: levelKey))
            let target = max(0.1, min(1, saved))
            _ = setLevel(client, setSel, target, keyboardID)
            brightness = Double(target)
        } else {
            let current = level
            if current > 0.05 { UserDefaults.standard.set(Double(current), forKey: levelKey) }
            _ = setLevel(client, setSel, 0, keyboardID)
            brightness = 0
        }
        isOn = on
    }

    /// Set an explicit level, 0...1. Dragging to 0 turns the light off.
    func setBrightness(_ value: Double) {
        guard isAvailable, let client, let setLevel else { return }
        let v = max(0, min(1, value))
        _ = setLevel(client, setSel, Float(v), keyboardID)
        brightness = v
        isOn = Float(v) > offThreshold
        if v > 0.05 { UserDefaults.standard.set(v, forKey: levelKey) }
    }

    func toggle() {
        refresh()
        setOn(!isOn)
    }
}
