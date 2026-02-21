import Foundation
import AppKit

final class WindowEffectManager {
    static let shared = WindowEffectManager()
    
    private init() {}
    
    func applyEffects(to window: NSWindow) {
        let enableBlur = AppPreferences.shared.enableBlur
        
        if enableBlur {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.alphaValue = 1.0
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.alphaValue = 1.0
        }
        
        if enableBlur {
            enableBlurEffect(for: window)
        } else {
            disableBlurEffect(for: window)
        }
    }
    
    func enableBlurEffect(for window: NSWindow) {
        // handled in SwiftUI via VisualEffectViewRepresentable
        return
    }
    
    func disableBlurEffect(for window: NSWindow) {
        guard let contentView = window.contentView else { return }
        
        contentView.subviews
            .filter { $0 is NSVisualEffectView }
            .forEach { $0.removeFromSuperview() }
    }
    
    func updateOpacity(_ opacity: Double, for window: NSWindow) {}
}
