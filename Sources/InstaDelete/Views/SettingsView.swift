import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }
    var label: String { rawValue.capitalized }

    /// Applied to `NSApp.appearance`; nil follows macOS.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

struct SettingsView: View {
    @AppStorage("appTheme") private var theme = AppTheme.system
    /// nil in debug builds (no updater): the About section then says so instead of showing the button.
    var onCheckForUpdates: (() -> Void)?

    var body: some View {
        Form {
            Picker("Appearance:", selection: $theme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Section("About") {
                LabeledContent("Version", value: AppVersion.label)
                LabeledContent("Last updated", value: AppVersion.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                if let onCheckForUpdates { Button("Check for Updates…", action: onCheckForUpdates) }
                Text(onCheckForUpdates == nil ? "Update checks are off in debug builds."
                                              : "Updates are checked every hour, downloaded quietly and installed when you quit InstaDelete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
