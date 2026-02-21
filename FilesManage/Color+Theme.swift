import SwiftUI
import AppKit

extension Color {
    static var themeBackground: Color {
        if AppPreferences.shared.enableBlur {
            return Color.clear
        }
        return Color(nsColor: ThemeManager.shared.isDarkMode ? .windowBackgroundColor : .white)
    }
    
    static var themeText: Color {
        Color(nsColor: .labelColor)
    }
    
    static var themeSecondaryText: Color {
        Color(nsColor: .secondaryLabelColor)
    }
    
    static var themeBorder: Color {
        Color(nsColor: .separatorColor)
    }
    
    static var themeAccent: Color {
        Color(nsColor: .controlAccentColor)
    }
}
