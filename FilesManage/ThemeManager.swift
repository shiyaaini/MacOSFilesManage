import Foundation
import AppKit

final class ThemeManager {
    static let shared = ThemeManager()
    
    private init() {}
    
    func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
    
    var currentTheme: AppTheme {
        let themeString = AppPreferences.shared.theme
        return AppTheme(rawValue: themeString) ?? .system
    }
    
    var isDarkMode: Bool {
        let appearance = NSApp.effectiveAppearance
        let aquaAppearance = appearance.bestMatch(from: [.aqua, .darkAqua])
        return aquaAppearance == .darkAqua
    }
}
