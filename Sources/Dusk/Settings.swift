import Foundation
import Combine

/// Persistent user preferences. Every property writes through to UserDefaults.
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    static let minBrightness = 0.05
    static let step = 0.05

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let brightness = "brightness"
        static let warmth = "warmth"
        static let hotkeys = "hotkeysEnabled"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleStart = "scheduleStartMinutes"
        static let scheduleEnd = "scheduleEndMinutes"
        static let launchedBefore = "launchedBefore"
    }

    /// Whether the screen is currently dimmed.
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Key.enabled) }
    }

    /// Perceived screen brightness, 1.0 = untouched, minBrightness = darkest.
    @Published var brightness: Double {
        didSet {
            let clamped = min(1.0, max(Self.minBrightness, brightness))
            if clamped != brightness { brightness = clamped }
            defaults.set(brightness, forKey: Key.brightness)
        }
    }

    /// Amber tint strength, 0 = neutral.
    @Published var warmth: Double {
        didSet {
            let clamped = min(1.0, max(0.0, warmth))
            if clamped != warmth { warmth = clamped }
            defaults.set(warmth, forKey: Key.warmth)
        }
    }

    @Published var hotkeysEnabled: Bool {
        didSet { defaults.set(hotkeysEnabled, forKey: Key.hotkeys) }
    }

    @Published var scheduleEnabled: Bool {
        didSet { defaults.set(scheduleEnabled, forKey: Key.scheduleEnabled) }
    }

    /// Minutes after midnight.
    @Published var scheduleStart: Int {
        didSet { defaults.set(scheduleStart, forKey: Key.scheduleStart) }
    }

    /// Minutes after midnight.
    @Published var scheduleEnd: Int {
        didSet { defaults.set(scheduleEnd, forKey: Key.scheduleEnd) }
    }

    /// True on the very first launch only.
    let isFirstLaunch: Bool

    private init() {
        defaults.register(defaults: [
            Key.enabled: false,
            Key.brightness: 0.6,
            Key.warmth: 0.0,
            Key.hotkeys: true,
            Key.scheduleEnabled: false,
            Key.scheduleStart: 22 * 60,
            Key.scheduleEnd: 7 * 60,
        ])
        enabled = defaults.bool(forKey: Key.enabled)
        brightness = min(1.0, max(Self.minBrightness, defaults.double(forKey: Key.brightness)))
        warmth = min(1.0, max(0.0, defaults.double(forKey: Key.warmth)))
        hotkeysEnabled = defaults.bool(forKey: Key.hotkeys)
        scheduleEnabled = defaults.bool(forKey: Key.scheduleEnabled)
        scheduleStart = defaults.integer(forKey: Key.scheduleStart)
        scheduleEnd = defaults.integer(forKey: Key.scheduleEnd)

        isFirstLaunch = !defaults.bool(forKey: Key.launchedBefore)
        defaults.set(true, forKey: Key.launchedBefore)
    }

    var brightnessPercent: Int { Int((brightness * 100).rounded()) }

    func adjustBrightness(by delta: Double) {
        let next = ((brightness + delta) / Self.step).rounded() * Self.step
        brightness = min(1.0, max(Self.minBrightness, next))
        if !enabled { enabled = true }
    }
}
