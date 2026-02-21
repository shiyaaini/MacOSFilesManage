import AppKit

extension NSView {
    func applyTheme() {
        needsDisplay = true
        subviews.forEach { $0.applyTheme() }
    }
    
    func observeThemeChanges() {
        NotificationCenter.default.addObserver(
            forName: AppUIManager.Notifications.themeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }
}
