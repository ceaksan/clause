import SwiftUI
import ClauseShared

@main
struct ClauseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// Under xcodebuild test this app hosts the tests; it must not touch the user's socket or board.
    static let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    @State private var noteStore = NoteStore(snapshotURL: ClauseApp.isTestHost ? nil : ClauseConstants.boardFile)
    @State private var socketServer: SocketServer?

    init() {
        // A CLI that quits mid-response must not kill the app; writes return EPIPE instead.
        signal(SIGPIPE, SIG_IGN)
    }

    var body: some Scene {
        Window("Clause", id: "main") {
            ContentView()
                .environment(noteStore)
                .environment(socketServer)
                .onAppear {
                    setupSocketServer()
                    configureWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 320, height: 480)
    }

    private func setupSocketServer() {
        guard !Self.isTestHost else { return }
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
