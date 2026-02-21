import AppKit

extension NSWindow {
    func applyWindowEffects() {
        WindowEffectManager.shared.applyEffects(to: self)
    }
    
    func observeEffectChanges() {
        NotificationCenter.default.addObserver(
            forName: AppUIManager.Notifications.blurChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let enabled = notification.object as? Bool else { return }
            WindowEffectManager.shared.applyEffects(to: self)
        }
    }
}
