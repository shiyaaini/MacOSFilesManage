import AppKit
import SwiftUI

final class VisualEffectHelper {
    static func createBlurView(frame: NSRect, material: NSVisualEffectView.Material = .hudWindow) -> NSVisualEffectView {
        let visualEffect = NSVisualEffectView(frame: frame)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = material
        return visualEffect
    }
    
    static func applyBlur(to view: NSView, material: NSVisualEffectView.Material = .hudWindow) {
        let blurView = createBlurView(frame: view.bounds, material: material)
        view.addSubview(blurView, positioned: .below, relativeTo: nil)
    }
    
    static func removeBlur(from view: NSView) {
        view.subviews
            .filter { $0 is NSVisualEffectView }
            .forEach { $0.removeFromSuperview() }
    }
}

struct VisualEffectViewRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.autoresizingMask = [.width, .height]
        v.state = .active
        v.material = material
        v.blendingMode = blending
        return v
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
        nsView.material = material
        nsView.blendingMode = blending
    }
}
