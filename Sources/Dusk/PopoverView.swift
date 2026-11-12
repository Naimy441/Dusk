import SwiftUI
import AppKit

struct PopoverView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var keyboard = KeyboardBacklight.shared
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginMessage: String?

    private let presets: [(String, Double)] = [("Low", 0.8), ("Medium", 0.6), ("Dark", 0.4), ("Night", 0.2)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16)

            brightnessControl
                .padding(.bottom, 14)

            warmthControl
                .padding(.bottom, 14)

            presetRow
                .padding(.bottom, 16)

            if keyboard.isAvailable {
                Divider().padding(.bottom, 12)
                keyboardControl
                    .padding(.bottom, 14)
            }

            Divider().padding(.bottom, 12)

            scheduleSection
                .padding(.bottom, 12)

            Divider().padding(.bottom, 12)

            optionsSection
                .padding(.bottom, 12)

            Divider().padding(.bottom, 10)

            footer
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            launchAtLogin = LoginItem.isEnabled
            keyboard.refresh()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.24, green: 0.23, blue: 0.55),
                                                  Color(red: 0.07, green: 0.08, blue: 0.20)],
                                         startPoint: .top, endPoint: .bottom))
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.5))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Dusk").font(.system(size: 14, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Toggle("Dimming", isOn: animatedEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help("Turn dimming on or off (\(Shortcuts.symbol)D)")
        }
    }

    private var statusText: String {
        guard settings.enabled else { return "Off" }
        var s = "Dimmed to \(settings.brightnessPercent)%"
        if settings.warmth > 0.01 { s += " · Warm" }
        return s
    }

    private var animatedEnabled: Binding<Bool> {
        Binding(get: { settings.enabled }, set: { settings.enabled = $0 })
    }

    // MARK: Sliders

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { settings.brightness },
            set: { value in
                settings.brightness = value
                if !settings.enabled { settings.enabled = true }
            })
    }

    private var warmthBinding: Binding<Double> {
        Binding(
            get: { settings.warmth },
            set: { value in
                settings.warmth = value
                if !settings.enabled && value > 0 { settings.enabled = true }
            })
    }

    private var brightnessControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Brightness", value: "\(settings.brightnessPercent)%")
            HStack(spacing: 8) {
                Image(systemName: "sun.min").foregroundStyle(.secondary).frame(width: 16)
                Slider(value: brightnessBinding, in: Settings.minBrightness...1.0)
                    .controlSize(.small)
                Image(systemName: "sun.max").foregroundStyle(.secondary).frame(width: 16)
            }
            .opacity(settings.enabled ? 1 : 0.55)
        }
    }

    private var warmthControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Warmth", value: settings.warmth < 0.01 ? "Neutral" : "\(Int((settings.warmth * 100).rounded()))%")
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary).frame(width: 16)
                Slider(value: warmthBinding, in: 0...1)
                    .controlSize(.small)
                    .tint(.orange)
                Image(systemName: "flame").foregroundStyle(.orange.opacity(0.85)).frame(width: 16)
            }
            .opacity(settings.enabled ? 1 : 0.55)
        }
    }

    private var keyboardControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Keyboard backlight",
                         value: keyboard.isOn ? "\(Int((keyboard.brightness * 100).rounded()))%" : "Off")
            HStack(spacing: 8) {
                // Tap the icon to switch the light off / back on in one click.
                Button { keyboard.toggle() } label: {
                    Image(systemName: keyboard.isOn ? "light.max" : "light.min")
                        .foregroundStyle(keyboard.isOn ? Color.primary : Color.secondary)
                        .frame(width: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Turn the keyboard light \(keyboard.isOn ? "off" : "on") (\(Shortcuts.symbol)K)")
                Slider(value: Binding(get: { keyboard.brightness },
                                      set: { keyboard.setBrightness($0) }),
                       in: 0...1)
                    .controlSize(.small)
                Image(systemName: "light.max").foregroundStyle(.secondary).frame(width: 16)
            }
        }
    }

    private func sectionLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Presets

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.0) { name, value in
                let selected = settings.enabled && abs(settings.brightness - value) < 0.001
                Button {
                    settings.brightness = value
                    settings.enabled = true
                } label: {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected ? Color.accentColor : Color.primary.opacity(0.07))
                        )
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(icon: "clock", title: "Schedule", isOn: $settings.scheduleEnabled)
            if settings.scheduleEnabled {
                HStack(spacing: 6) {
                    Text("From").foregroundStyle(.secondary)
                    timePicker(minutes: $settings.scheduleStart)
                    Text("to").foregroundStyle(.secondary)
                    timePicker(minutes: $settings.scheduleEnd)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12))
                .padding(.leading, 26)
            }
        }
    }

    private func timePicker(minutes: Binding<Int>) -> some View {
        let date = Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                      minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
        return DatePicker("", selection: date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.field)
            .controlSize(.small)
            .fixedSize()
    }

    // MARK: Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                row(icon: "keyboard", title: "Keyboard shortcuts", isOn: $settings.hotkeysEnabled)
                if settings.hotkeysEnabled {
                    Text("\(Shortcuts.symbol)↑ ↓ adjust  ·  D toggle\(keyboard.isAvailable ? "  ·  K keyboard" : "")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 26)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                row(icon: "power", title: "Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { value in
                        loginMessage = LoginItem.set(value)
                        launchAtLogin = LoginItem.isEnabled
                    }))
                if let loginMessage {
                    Text(loginMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .padding(.leading, 26)
                }
            }
        }
    }

    private func row(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title).font(.system(size: 12))
            Spacer()
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("Dusk \(appVersion)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .controlSize(.small)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
