import Foundation

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "theme.light".localized
        case .dark: return "theme.dark".localized
        case .system: return "theme.system".localized
        }
    }
}
