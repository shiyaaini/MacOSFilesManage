import Foundation
import AppKit

final class AppUIManager {
    static let shared = AppUIManager()
    
    private let preferences = AppPreferences.shared
    
    struct Notifications {
        static let languageChanged = Notification.Name("app.languageChanged")
        static let themeChanged = Notification.Name("app.themeChanged")
        static let blurChanged = Notification.Name("app.blurChanged")
        static let folderViewModeChanged = Notification.Name("app.folderViewModeChanged")
        static let tagsChanged = Notification.Name("app.tagsChanged")
    }
    
    private init() {
        applyInitialSettings()
    }
    
    func applyInitialSettings() {
        applyTheme()
        applyLanguage()
    }
    
    func applyLanguage() {
        LocalizationManager.shared.updateBundle()
        NotificationCenter.default.post(name: Notifications.languageChanged, object: nil)
    }
    
    func applyTheme() {
        let theme = preferences.theme
        switch theme {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
        NotificationCenter.default.post(name: Notifications.themeChanged, object: nil)
    }
    
    func applyBlurEffect(_ enabled: Bool) {
        preferences.enableBlur = enabled
        NotificationCenter.default.post(name: Notifications.blurChanged, object: enabled)
    }
    
    func updateLanguage(_ language: String) {
        preferences.language = language
        applyLanguage()
    }
    
    func updateTheme(_ theme: String) {
        preferences.theme = theme
        applyTheme()
    }
}
