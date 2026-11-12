import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let settings = Settings.shared
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var overlay: OverlayController!
    private var scheduler: Scheduler!
    private var scrollMonitor: Any?
    private var scrollAccumulator: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController()
        setUpStatusItem()
        setUpPopover()
        bindSettings()
        scheduler = Scheduler(settings: settings)
        installScrollMonitor()

        if settings.isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Dusk — click to adjust, ⌥-click to toggle, scroll to dim"
        updateIcon()
    }

    private func updateIcon() {
        let name = settings.enabled ? "moon.fill" : "moon"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Dusk")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return togglePopover() }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else if event.modifierFlags.contains(.option) {
            settings.enabled.toggle()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: settings.enabled ? "Turn Off Dimming" : "Turn On Dimming",
                                action: #selector(toggleDimming), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        for pct in [80, 60, 40, 20] {
            let item = NSMenuItem(title: "\(pct)% Brightness", action: #selector(setPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = pct
            item.state = (settings.enabled && settings.brightnessPercent == pct) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Dusk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleDimming() { settings.enabled.toggle() }

    @objc private func setPreset(_ sender: NSMenuItem) {
        settings.brightness = Double(sender.tag) / 100
        settings.enabled = true
    }

    // MARK: - Popover

    private func setUpPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let host = NSHostingController(rootView: PopoverView(settings: settings))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
    }

    private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Keep controls readable even when the screen is very dark.
        popover.contentViewController?.view.window?.level = aboveOverlayLevel
        if let window = popover.contentViewController?.view.window {
            window.makeKey()
            // Don't let the first text field (schedule time) grab focus.
            DispatchQueue.main.async { window.makeFirstResponder(nil) }
        }
    }

    // MARK: - Settings → overlay

    private func bindSettings() {
        Publishers.CombineLatest3(settings.$enabled, settings.$brightness, settings.$warmth)
            .sink { [weak self] enabled, brightness, warmth in
                guard let self else { return }
                self.overlay.apply(enabled: enabled, brightness: brightness, warmth: warmth)
                self.updateIcon()
            }
            .store(in: &cancellables)

        settings.$hotkeysEnabled
            .removeDuplicates()
            .sink { [weak self] on in self?.configureHotKeys(on) }
            .store(in: &cancellables)
    }

    private func configureHotKeys(_ on: Bool) {
        let center = HotKeyCenter.shared
        center.unregisterAll()
        guard on else { return }
        let mods = Shortcuts.modifiers
        center.register(keyCode: kVK_UpArrow, modifiers: mods) { [weak self] in
            self?.nudge(+Settings.step)
        }
        center.register(keyCode: kVK_DownArrow, modifiers: mods) { [weak self] in
            self?.nudge(-Settings.step)
        }
        center.register(keyCode: kVK_ANSI_D, modifiers: mods) { [weak self] in
            guard let self else { return }
            self.settings.enabled.toggle()
            self.showHUDIfNeeded()
        }
    }

    private func nudge(_ delta: Double) {
        settings.adjustBrightness(by: delta)
        showHUDIfNeeded()
    }

    private func showHUDIfNeeded() {
        // The popover already shows the level; skip the HUD while it's open.
        guard !popover.isShown else { return }
        HUD.shared.show(enabled: settings.enabled, brightness: settings.brightness)
    }

    // MARK: - Scroll on menu bar icon

    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let buttonWindow = self.statusItem.button?.window,
                  event.window === buttonWindow else { return event }
            self.handleScroll(event)
            return nil
        }
    }

    private func handleScroll(_ event: NSEvent) {
        var dy = event.scrollingDeltaY
        if event.isDirectionInvertedFromDevice { dy = -dy }
        // Normalise trackpad (precise) vs. wheel (line) deltas.
        scrollAccumulator += event.hasPreciseScrollingDeltas ? dy / 12 : dy
        let steps = Int(scrollAccumulator)
        guard steps != 0 else { return }
        scrollAccumulator -= CGFloat(steps)
        nudge(Double(steps) * Settings.step)
    }
}
