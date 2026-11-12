import AppKit
import QuartzCore

/// Window level used for the dimming layer: above the menu bar, Dock,
/// pop-up menus and full-screen apps.
let overlayLevel = NSWindow.Level.screenSaver
/// Level for Dusk's own UI so it always stays readable above the shade.
let aboveOverlayLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

/// Owns one click-through overlay window per connected display.
@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var enabled = false
    private var brightness = 1.0
    private var warmth = 0.0
    private var observers: [NSObjectProtocol] = []

    init() {
        rebuild()
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        })
        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(wnc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // Displays can come back with new geometry a moment after wake.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    MainActor.assumeIsolated { self?.rebuild() }
                }
            })
        }
    }

    /// Recreate overlays to match the current display arrangement.
    func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
        for w in windows {
            w.setShade(brightness: brightness, warmth: warmth, visible: enabled, animated: false)
            if enabled { w.orderFrontRegardless() }
        }
    }

    func apply(enabled newEnabled: Bool, brightness newBrightness: Double, warmth newWarmth: Double) {
        let toggled = newEnabled != enabled
        enabled = newEnabled
        brightness = newBrightness
        warmth = newWarmth

        for w in windows {
            if newEnabled { w.orderFrontRegardless() }
            w.setShade(brightness: newBrightness, warmth: newWarmth, visible: newEnabled, animated: toggled) { [weak self, weak w] in
                // Fully remove windows from the compositor when off.
                guard let self, let w, !self.enabled else { return }
                w.orderOut(nil)
            }
        }
    }
}

final class OverlayWindow: NSWindow {
    private let tintLayer = CALayer()
    private let dimLayer = CALayer()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = overlayLevel
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.autoresizingMask = [.width, .height]
        let root = view.layer!
        for layer in [tintLayer, dimLayer] {
            layer.frame = root.bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.opacity = 0
            root.addSublayer(layer)
        }
        // Warm amber wash, then neutral black on top.
        tintLayer.backgroundColor = CGColor(red: 1.0, green: 0.52, blue: 0.12, alpha: 1)
        dimLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setShade(brightness: Double, warmth: Double, visible: Bool,
                  animated: Bool, completion: (() -> Void)? = nil) {
        let dim = visible ? Float(1.0 - brightness) : 0
        let tint = visible ? Float(warmth * 0.22) : 0

        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.35)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        CATransaction.setCompletionBlock(completion)
        dimLayer.opacity = dim
        tintLayer.opacity = tint
        CATransaction.commit()
    }
}
