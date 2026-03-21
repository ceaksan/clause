import AppKit

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)
        minSize = NSSize(width: 280, height: 300)
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }

    override func close() {
        orderOut(nil)
    }
}
