import SwiftUI

/// Preferences' switch for the date in the menubar, with its style and side.
struct DateSection: View {
    @EnvironmentObject private var clock: Clock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Show the date in the menubar", isOn: $clock.dateDisplay.isShown)
            if clock.dateDisplay.isShown {
                Picker("Style", selection: $clock.dateDisplay.style) {
                    // Today in each style, so the choices show the Mac's own date order.
                    ForEach(DateStyle.allCases) { Text($0.text(for: clock.now)).tag($0) }
                }
                Picker("Position", selection: $clock.dateDisplay.position) {
                    Text("Before the time").tag(DateDisplay.Position.before)
                    Text("After the time").tag(DateDisplay.Position.after)
                }
                Text("A long date beside a long phrase may not fit beside the notch; macOS hides a menubar item that doesn't.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
