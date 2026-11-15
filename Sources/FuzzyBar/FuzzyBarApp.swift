import SwiftUI

@main
struct FuzzyBarApp: App {
    @StateObject private var clock = Clock.launched()
    @StateObject private var sun = SunSettings()
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra(clock.fuzzy) {
            PopoverView(now: clock.now, sun: sun, openSettings: { openSettings() })
                .onAppear { clock.setPopoverVisible(true) }
                .onDisappear { clock.setPopoverVisible(false) }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(clock)
                .environmentObject(clock.personalities)
                .environmentObject(sun)
        }
    }
}

struct PopoverView: View {
    let now: Date
    @ObservedObject var sun: SunSettings
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: 22, weight: .medium))
                Text(now, format: .dateTime.weekday(.wide).month(.wide).day().year())
                    .foregroundStyle(.secondary)
                SunView(now: now, settings: sun)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Divider().padding(.horizontal, 12)

            CalendarView(today: now)
                .padding(.horizontal, 12).padding(.vertical, 10)

            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 2) {
                MenuRowButton(title: "Preferences…") {
                    // Re-center a window that was closed and start it unfocused;
                    // leave an open one where it is, focus and all.
                    let reopening = SettingsWindow.current.flatMap { $0.isVisible ? nil : $0 }
                    reopening?.center()
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    if let reopening { SettingsWindow.clearFocus(reopening) }
                }
                MenuRowButton(title: "Quit") { NSApp.terminate(nil) }
            }
            .padding(8)
        }
        .frame(width: 270)
    }
}

private struct MenuRowButton: View {
    let title: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(hover ? Color.primary.opacity(0.1) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
