import Foundation
import Combine

/// Turns dimming on/off at the scheduled times. Only acts on transitions,
/// so turning dimming off manually during the window is respected.
@MainActor
final class Scheduler {
    private let settings: Settings
    private var timer: Timer?
    private var lastInWindow: Bool?
    private var cancellables = Set<AnyCancellable>()

    init(settings: Settings) {
        self.settings = settings

        Publishers.CombineLatest3(settings.$scheduleEnabled, settings.$scheduleStart, settings.$scheduleEnd)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastInWindow = nil
                self?.evaluate()
            }
            .store(in: &cancellables)

        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
        evaluate()
    }

    static func isInWindow(now: Date = Date(), start: Int, end: Int) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if start == end { return false }
        if start < end { return minute >= start && minute < end }
        return minute >= start || minute < end   // spans midnight
    }

    func evaluate() {
        guard settings.scheduleEnabled else {
            lastInWindow = nil
            return
        }
        let inWindow = Self.isInWindow(start: settings.scheduleStart, end: settings.scheduleEnd)
        defer { lastInWindow = inWindow }

        switch (lastInWindow, inWindow) {
        case (nil, true), (false?, true):
            settings.enabled = true
        case (true?, false):
            settings.enabled = false
        default:
            break
        }
    }
}
