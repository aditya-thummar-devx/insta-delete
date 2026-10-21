import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

/// Design tokens from SPEC.md.
enum Theme {
    static let accent = Color(hex: 0x0062CC)
    static let destructive = Color(hex: 0xC4161C)
    static let markRing = Color(hex: 0xD70015)
    static let markRingDark = Color(hex: 0xFF453A)
    static let text = Color(hex: 0x1D1D1F)
    static let textSecondary = Color(hex: 0x6E6E73)
    static let sidebarBG = Color(hex: 0xF2F2F4)
    static let sidebarBorder = Color(hex: 0xE2E2E6)
    static let sidebarSelected = Color(hex: 0xDCDCE2)
    static let reviewBG = Color(hex: 0x111113)
    static let reviewPanel = Color(hex: 0x18181B)
    static let reviewFilmstrip = Color(hex: 0x0B0B0D)
    static let reviewChip = Color(hex: 0x26262A)
    static let successFG = Color(hex: 0x4ADE80)
    static let successBG = Color(hex: 0x13351E)
}
