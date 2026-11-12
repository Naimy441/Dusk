import AppKit
import SwiftUI

/// A small transient pill shown when brightness changes from a shortcut
/// or the menu bar scroll wheel.
@MainActor
final class HUD {
    static let shared = HUD()

    private let model = HUDModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    private let size = NSSize(width: 248, height: 52)

    func show(enabled: Bool, brightness: Double) {
        model.message = nil
        model.enabled = enabled
        model.brightness = brightness
        present()
    }

    /// A text-only variant, e.g. "Keyboard light off".
    func showMessage(icon: String, text: String) {
        model.message = (icon, text)
        present()
    }

    private func present() {

        let panel = self.panel ?? makePanel()
        self.panel = panel

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height - 14))
        }

        hideWork?.cancel()
        if !panel.isVisible || panel.alphaValue < 1 {
            panel.alphaValue = panel.isVisible ? panel.alphaValue : 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = 1
            }
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                panel.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated {
                    if panel.alphaValue == 0 { panel.orderOut(nil) }
                }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = aboveOverlayLevel
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = size.height / 2
        effect.layer?.masksToBounds = true

        let host = NSHostingView(rootView: HUDView(model: model))
        host.frame = effect.bounds
        host.autoresizingMask = [.width, .height]
        effect.addSubview(host)
        panel.contentView = effect
        return panel
    }
}

final class HUDModel: ObservableObject {
    @Published var enabled = false
    @Published var brightness = 1.0
    @Published var message: (icon: String, text: String)?
}

private struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        if let message = model.message {
            HStack(spacing: 10) {
                Image(systemName: message.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 22)
                Text(message.text)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            levelView
        }
    }

    private var levelView: some View {
        HStack(spacing: 12) {
            Image(systemName: model.enabled ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(model.enabled ? Color.indigo.opacity(0.9) : Color.orange)
                .frame(width: 22)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.14))
                    Capsule()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: max(6, geo.size.width * (model.enabled ? model.brightness : 1.0)))
                }
            }
            .frame(height: 6)

            Text(model.enabled ? "\(Int((model.brightness * 100).rounded()))%" : "Off")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.12), value: model.brightness)
    }
}
