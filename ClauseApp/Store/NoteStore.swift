import Foundation
import SwiftUI
import ClauseShared

@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [Note] = []
    private(set) var session: Session?
    private var saveTask: Task<Void, Never>?
    private var periodicSaveTask: Task<Void, Never>?

    var isSessionActive: Bool { session != nil }

    // MARK: - CRUD

    @discardableResult
    func addNote(text: String, source: Note.Source, type: Note.NoteType = .note) -> Note {
        let note = Note(text: text, source: source, type: type)
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    @discardableResult
    func editNote(id: UUID, text: String?, type: Note.NoteType?, completed: Bool?) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        if let text { notes[index].text = String(text.prefix(ClauseConstants.maxNoteLength)) }
        if let type { notes[index].type = type }
        if let completed { notes[index].completed = completed }
        scheduleSave()
        return true
    }

    @discardableResult
    func deleteNote(id: UUID) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        notes.remove(at: index)
        scheduleSave()
        return true
    }

    func clearNotes() -> Int {
        let count = notes.count
        notes.removeAll()
        scheduleSave()
        return count
    }

    func listNotes(type: Note.NoteType? = nil, source: Note.Source? = nil) -> [Note] {
        notes.filter { note in
            (type == nil || note.type == type) &&
            (source == nil || note.source == source)
        }
    }

    // MARK: - Session

    func setSession(_ session: Session) {
        if self.session != nil {
            flushSync()
        }
        self.session = session
        loadFromDisk()
        startPeriodicSave()
    }

    func endSession() {
        flushSync()
        periodicSaveTask?.cancel()
        periodicSaveTask = nil
        session = nil
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.flushSync()
        }
    }

    private func startPeriodicSave() {
        periodicSaveTask?.cancel()
        periodicSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                self?.flushSync()
            }
        }
    }

    func flushSync() {
        guard let session else { return }
        let url = ClauseConstants.sessionsDirectory
            .appendingPathComponent("\(session.id).json")
        do {
            try FileManager.default.createDirectory(
                at: ClauseConstants.sessionsDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notes)
            try data.write(to: url, options: .atomic)
        } catch {
            print("NoteStore save error: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let session else { return }
        let url = ClauseConstants.sessionsDirectory
            .appendingPathComponent("\(session.id).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            notes = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = try decoder.decode([Note].self, from: data)
        } catch {
            print("NoteStore load error: \(error)")
            notes = []
        }
    }
}
