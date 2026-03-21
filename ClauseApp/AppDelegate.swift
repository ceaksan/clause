import AppKit
import ClauseShared

final class AppDelegate: NSObject, NSApplicationDelegate {
    var socketServer: SocketServer?
    var noteStore: NoteStore?
    var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Socket server is started from ClauseApp.swift
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteStore?.flushSync()
        socketServer?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
