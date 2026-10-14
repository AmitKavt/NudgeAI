import SwiftUI

/// Explicit hex token set synced from the Figma file (design.md) — this is
/// a finished warm/editorial design, not the iOS system palette, so these
/// are used everywhere instead of `.systemBackground`/`.secondary`/etc.
enum Theme {
    static let bg = Color(hex: 0xFAF7F2)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceAlt = Color(hex: 0xF2EEE7)
    static let line = Color(hex: 0xE7E2D9)
    static let ink = Color(hex: 0x1C1917)
    static let muted = Color(hex: 0x78716C)
    static let night = Color(hex: 0x1C1917)
    static let onNight = Color(hex: 0xF5F1EA)
    static let onNightMuted = Color(hex: 0xA8A29E)
    static let accent = Color(hex: 0xE8590C)
    static let accentSoft = Color(hex: 0xFFEDE0)
    static let accentNight = Color(hex: 0xFF7A33)
    static let onAccent = Color(hex: 0xFFFFFF)
    static let warn = Color(hex: 0xB7791F)
    static let warnSoft = Color(hex: 0xFDF1D6)
    static let success = Color(hex: 0x2F7D4F)
    static let successSoft = Color(hex: 0xE3F3E8)

    enum Radius {
        static let card: CGFloat = 28
        static let list: CGFloat = 20
        static let button: CGFloat = 16
        static let pill: CGFloat = 100
    }

    enum Spacing {
        static let screenMargin: CGFloat = 20
        static let cardPadding: CGFloat = 22
        static let section: CGFloat = 24
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Font {
    /// Instrument Serif — display/headline text (screen titles, big stat
    /// numbers, the nightly-review quote). Bundled via Info.plist UIAppFonts.
    static func nudgeDisplay(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size)
    }
}
