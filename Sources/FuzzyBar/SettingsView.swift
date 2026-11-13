import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var login = LoginSettings()
    @EnvironmentObject private var personalities: PersonalityStore
    @EnvironmentObject private var sun: SunSettings
    @State private var personalityMessage: PersonalityMessage?

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 18) {
            // Two columns: stacked in one, the sections make a window taller
            // than a small laptop's screen.
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 18) {
                    about
                    Divider()
                    PersonalitySection(message: $personalityMessage)
                    Divider()
                    loginSection
                }
                .frame(width: Self.columnWidth)

                Divider()

                VStack(spacing: 18) {
                    SpecialTimesSection()
                    Divider()
                    DateSection()
                    Divider()
                    sunSection
                }
                .frame(width: Self.columnWidth)
            }

            Divider()

            Text("© 2026 Gregory M Koch. Made with love and no Rosetta.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        // The dividers would otherwise let the window open wider than the columns.
        .fixedSize()
        .padding(24)
        .background(SettingsWindow.Reader())
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            personalityMessage = personalities.importPersonality(from: url)
            return true
        }
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
        }
    }
}

extension SettingsView {
    private static let columnWidth: CGFloat = 272

    private var about: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            Text("FuzzyBar")
                .font(.title2).fontWeight(.semibold)
            Text("Version \(version)")
                .font(.caption).foregroundStyle(.secondary)
            Text("Tells the time in words, the way you'd say it out loud. Click the menubar for the exact time and a calendar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
    }

    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Start at login", isOn: Binding(
                get: { login.isRequested }, set: { login.setEnabled($0) }
            ))
            if login.status == .requiresApproval {
                Text("Approval is needed in System Settings before FuzzyBar can start at login.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = login.error {
                Text(error).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var zoneCity: String? {
        SunSettings.zoneLocation(.current) == nil ? nil : SunSettings.cityName(.current)
    }

    @ViewBuilder private var sunSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Show sunrise and sunset", isOn: $sun.isShown)
            if sun.isShown {
                Picker("Location", selection: $sun.usesCustomLocation) {
                    Text(zoneCity.map { "Time zone (\($0))" } ?? "Time zone").tag(false)
                    Text("Coordinates").tag(true)
                }
                if sun.usesCustomLocation {
                    HStack {
                        TextField("Latitude", value: $sun.latitude, format: .number)
                        TextField("Longitude", value: $sun.longitude, format: .number)
                    }
                    Text(sun.customLocation == nil
                         ? "Enter a latitude and longitude; north and east are positive, so Boston is 42.36, -71.06."
                         : "North and east are positive.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(zoneCity == nil
                         ? "\(TimeZone.current.identifier) has no reference city, so choose Coordinates."
                         : "Worked out for the time zone's city rather than where you are, so treat it as fuzzy.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Settings scene gives no handle on its window, and a menubar-only app has no
/// main window for AppKit to place a new one against, so it lands wherever the
/// popover was. This keeps a weak reference so the popover can center it.
enum SettingsWindow {
    static weak var current: NSWindow?

    /// AppKit gives the first editable control keyboard focus when the window
    /// opens, which lit up the special-times hour as if it were selected.
    /// Start with nothing focused; Tab still moves into the controls. Async,
    /// because SwiftUI assigns that focus after the window is ordered in.
    static func clearFocus(_ window: NSWindow) {
        DispatchQueue.main.async { window.makeFirstResponder(nil) }
    }

    struct Reader: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView { View() }
        func updateNSView(_ nsView: NSView, context: Context) {}

        private final class View: NSView {
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                guard let window, window !== SettingsWindow.current else { return }
                SettingsWindow.current = window
                window.center()
                SettingsWindow.clearFocus(window)
            }
        }
    }
}
