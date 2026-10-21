import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    /// Resolves against the current appearance, so it follows the System / Light / Dark setting.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            NSColor(Color(hex: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light))
        })
    }
}

/// Design tokens from SPEC.md, each with a light and a dark value.
enum Theme {
    static let accent = Color(light: 0x0062CC, dark: 0x0A84FF)
    static let destructive = Color(hex: 0xC4161C)
    static let markRing = Color(hex: 0xD70015)
    static let reviewMarkRing = Color(light: 0xD70015, dark: 0xFF453A)
    static let destructiveSoftFG = Color(light: 0xC4161C, dark: 0xFFB4B0)
    static let destructiveSoftBG = Color(light: 0xFDECEC, dark: 0x3A1418)
    static let text = Color(light: 0x1D1D1F, dark: 0xF5F5F7)
    static let textSecondary = Color(light: 0x6E6E73, dark: 0xA1A1A6)
    static let windowBG = Color(light: 0xFFFFFF, dark: 0x1E1E1E)
    static let cardBG = Color(light: 0xFAFAFC, dark: 0x232326)
    static let cardBorder = Color(light: 0xE5E5EA, dark: 0x38383C)
    static let tilePlaceholder = Color(light: 0xE5E5EA, dark: 0x2C2C2E)
    static let infoBG = Color(light: 0xEEF4FC, dark: 0x1A2738)
    static let infoText = Color(light: 0x1D3A66, dark: 0x9CC7FF)
    static let accentSoftBG = Color(light: 0xE6EFFA, dark: 0x1F2A3A)
    static let sidebarBG = Color(light: 0xF2F2F4, dark: 0x252528)
    static let sidebarBorder = Color(light: 0xE2E2E6, dark: 0x38383C)
    static let sidebarSelected = Color(light: 0xDCDCE2, dark: 0x3A3A3E)
    static let sidebarNoteBG = Color(light: 0xE9E9EE, dark: 0x2C2C2E)
    static let sidebarNoteFG = Color(light: 0x4A4A4F, dark: 0xC7C7CC)
    static let reviewBG = Color(light: 0xF5F5F7, dark: 0x111113)
    static let reviewPanel = Color(light: 0xFFFFFF, dark: 0x18181B)
    static let reviewFilmstrip = Color(light: 0xEDEDF0, dark: 0x0B0B0D)
    static let reviewChip = Color(light: 0xE5E5EA, dark: 0x26262A)
    static let reviewDivider = Color(light: 0xE2E2E6, dark: 0x26262A)
    static let successFG = Color(light: 0x1E7B34, dark: 0x4ADE80)
    static let successBG = Color(light: 0xE3F5E8, dark: 0x13351E)
}
