import SwiftUI
import AppKit

final class DragStarterView: NSView, NSDraggingSource {
    var getURLs: (() -> [URL]) = { [] }
    private var monitor: Any?
    private var didStartDrag = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
        postsFrameChangedNotifications = false
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] evt in
                guard let self = self else { return evt }
                if evt.type == .leftMouseDragged {
                    self.maybeStartDragging(with: evt)
                } else if evt.type == .leftMouseUp {
                    self.didStartDrag = false
                }
                return evt
            }
        } else if window == nil, let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
    
    deinit {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    private func maybeStartDragging(with event: NSEvent) {
        if didStartDrag { return }
        guard let win = self.window, event.window == win else { return }
        let startPoint = convert(event.locationInWindow, from: nil)
        
        // Ensure the drag starts within this view's bounds
        // Also ignore drags starting near the edges (to avoid conflict with resize handles)
        // And ignore if the cursor indicates resizing
        if !self.bounds.contains(startPoint) {
            return
        }
        
        // Check for resize cursor
        if NSCursor.current == NSCursor.resizeLeftRight || NSCursor.current == NSCursor.resizeUpDown {
            return
        }
        
        // Edge protection (16px from left or right)
        if startPoint.x < 16 || startPoint.x > self.bounds.width - 16 {
            return
        }
        
        let urls = getURLs().filter { $0.isFileURL }
        guard !urls.isEmpty else { return }
        didStartDrag = true
        
        let items = urls.map { url -> NSDraggingItem in
            let it = NSDraggingItem(pasteboardWriter: url as NSURL)
            it.setDraggingFrame(NSRect(x: startPoint.x, y: startPoint.y, width: 1, height: 1), contents: nil)
            return it
        }
        DispatchQueue.main.async {
            self.beginDraggingSession(with: items, event: event, source: self)
        }
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy]
    }
}

struct DragSourceBridge: NSViewRepresentable {
    var getURLs: () -> [URL]
    
    func makeNSView(context: Context) -> DragStarterView {
        let v = DragStarterView()
        v.getURLs = getURLs
        return v
    }
    
    func updateNSView(_ nsView: DragStarterView, context: Context) {
        nsView.getURLs = getURLs
    }
}
