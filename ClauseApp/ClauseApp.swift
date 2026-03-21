import SwiftUI
import ClauseShared

@main
struct ClauseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var noteStore = NoteStore()
    @State private var socketServer: SocketServer?

    var body: some Scene {
        Window("Clause", id: "main") {
            ContentView()
                .environment(noteStore)
                .onAppear {
                    setupSocketServer()
                    configureWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 320, height: 480)
    }

    private func setupSocketServer() {
        let server = SocketServer(noteStore: noteStore)
        server.start()
        socketServer = server
        appDelegate.socketServer = server
        appDelegate.noteStore = noteStore
    }

    private func configureWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)
                window.minSize = NSSize(width: 280, height: 300)
            }
        }
    }
}
