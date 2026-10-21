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

    var body: some View {
        Form {
            Picker("Appearance:", selection: $theme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .frame(width: 360)
    }
}
