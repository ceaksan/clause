import Foundation
import SwiftUI
import ClauseShared

@MainActor
@Observable
final class NoteStore {
    struct PaneGroup: Identifiable {
        let id: String
        let label: String?
        let notes: [Note]
    }

    struct WorkspaceGroup: Identifiable {
        let id: String
        let label: String?
        let panes: [PaneGroup]
    }

    private(set) var notes: [Note] = []
    /// Last board save failure, shown in the window; nil after a successful save.
    private(set) var saveError: String?
    private var nextSeq = 1
    private let snapshotURL: URL?
    private var saveTask: Task<Void, Never>?
    private var periodicSaveTask: Task<Void, Never>?

    init(snapshotURL: URL? = ClauseConstants.boardFile) {
        self.snapshotURL = snapshotURL
        loadFromDisk()
        if snapshotURL != nil { startPeriodicSave() }
    }

    // MARK: - CRUD

    @discardableResult
    func addNote(
        text: String,
        source: Note.Source,
        type: Note.NoteType = .note,
        status: DecisionStatus? = nil,
        context: AgentContext? = nil
    ) -> Note {
        var note = Note(text: text, source: source, type: type, status: status, context: context)
        note.seq = nextSeq
        nextSeq += 1
        notes.insert(note, at: 0)
        pruneDecided()
        saveTask?.cancel()
        flushSync()
        return note
    }

    func noteId(forRef ref: String) -> UUID? {
        guard let seq = Note.seq(fromRef: ref) else { return nil }
        return notes.first { $0.seq == seq }?.id
    }

    func listNotes(caller: AgentContext?, type: Note.NoteType? = nil) -> [Note] {
        notes.filter { note in
            (caller.map { note.belongs(to: $0) } ?? true) && (type == nil || note.type == type)
        }
    }

    @discardableResult
    func editNote(
        id: UUID,
        text: String? = nil,
        type: Note.NoteType? = nil,
        completed: Bool? = nil,
        status: DecisionStatus? = nil,
        caller: AgentContext? = nil
    ) -> Bool {
        guard let index = index(of: id, caller: caller) else { return false }
        if let text { notes[index].text = String(text.prefix(ClauseConstants.maxNoteLength)) }
        if let type { notes[index].type = type }
        if let completed { notes[index].completed = completed }
        if let status { notes[index].status = status }
        notes[index].normalize()
        didWrite()
        return true
    }

    @discardableResult
    func deleteNote(id: UUID, caller: AgentContext? = nil) -> Bool {
        guard let index = index(of: id, caller: caller) else { return false }
        notes.remove(at: index)
        scheduleSave()
        return true
    }

    func clearNotes(caller: AgentContext) -> Int {
        removeAll { $0.belongs(to: caller) }
    }

    func clearWorkspace(_ workspaceId: String) -> Int {
        removeAll { $0.workspaceId == workspaceId }
    }

    func setMemo(id: UUID, _ memo: String) {
        guard let index = index(of: id, caller: nil) else { return }
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        notes[index].memo = trimmed.isEmpty ? nil : String(trimmed.prefix(ClauseConstants.maxMemoLength))
        scheduleSave()
    }

    // MARK: - Views

    var userNotes: [Note] {
        notes.filter { $0.workspaceId == nil }
    }

    var openDecisionCount: Int {
        notes.filter { $0.type == .decision && $0.status == .sent }.count
    }

    var workspaceGroups: [WorkspaceGroup] {
        let agentNotes = notes.filter { $0.workspaceId != nil }
        let byWorkspace = Dictionary(grouping: agentNotes) { $0.workspaceId! }
        return byWorkspace
            .map { workspaceId, workspaceNotes in
                let byPane = Dictionary(grouping: workspaceNotes) { $0.paneId ?? "" }
                let panes = byPane
                    .map { paneId, paneNotes in
                        PaneGroup(
                            id: paneId,
                            label: Self.newestLabel(paneNotes, \.agentLabel),
                            notes: Self.ordered(paneNotes)
                        )
                    }
                    .sorted { Self.newer(byPane[$0.id]!, than: byPane[$1.id]!) }
                return (
                    group: WorkspaceGroup(
                        id: workspaceId,
                        label: Self.newestLabel(workspaceNotes, \.workspaceLabel),
                        panes: panes
                    ),
                    notes: workspaceNotes
                )
            }
            .sorted { Self.newer($0.notes, than: $1.notes) }
            .map(\.group)
    }

    // MARK: - Private

    private func index(of id: UUID, caller: AgentContext?) -> Int? {
        notes.firstIndex { note in
            note.id == id && (caller.map { note.belongs(to: $0) } ?? true)
        }
    }

    private func removeAll(where shouldRemove: (Note) -> Bool) -> Int {
        let before = notes.count
        notes.removeAll(where: shouldRemove)
        scheduleSave()
        return before - notes.count
    }

    private func didWrite() {
        pruneDecided()
        scheduleSave()
    }

    private func pruneDecided() {
        let decided = notes.filter { $0.type == .decision && $0.status == .decided && $0.paneId != nil }
        let byPane = Dictionary(grouping: decided) { "\($0.workspaceId ?? "")\u{0}\($0.paneId ?? "")" }
        var drop = Set<UUID>()
        for paneDecided in byPane.values where paneDecided.count > ClauseConstants.decidedRetentionPerPane {
            paneDecided
                .sorted { ($0.decidedAt ?? .distantPast) > ($1.decidedAt ?? .distantPast) }
                .dropFirst(ClauseConstants.decidedRetentionPerPane)
                .forEach { drop.insert($0.id) }
        }
        if !drop.isEmpty { notes.removeAll { drop.contains($0.id) } }
    }

    private static func ordered(_ paneNotes: [Note]) -> [Note] {
        let newest: (Note, Note) -> Bool = {
            $0.timestamp != $1.timestamp ? $0.timestamp > $1.timestamp : ($0.seq ?? 0) > ($1.seq ?? 0)
        }
        let sent = paneNotes.filter { $0.type == .decision && $0.status == .sent }.sorted(by: newest)
        let other = paneNotes.filter { $0.type != .decision }.sorted(by: newest)
        let decided = paneNotes
            .filter { $0.type == .decision && $0.status == .decided }
            .sorted { ($0.decidedAt ?? .distantPast) > ($1.decidedAt ?? .distantPast) }
        return sent + other + decided
    }

    private static func lastActivity(_ group: [Note]) -> Date {
        group.map { max($0.timestamp, $0.decidedAt ?? .distantPast) }.max() ?? .distantPast
    }

    private static func newer(_ lhs: [Note], than rhs: [Note]) -> Bool {
        let (left, right) = (lastActivity(lhs), lastActivity(rhs))
        if left != right { return left > right }
        return (lhs.compactMap(\.seq).max() ?? 0) > (rhs.compactMap(\.seq).max() ?? 0)
    }

    private static func newestLabel(_ group: [Note], _ key: KeyPath<Note, String?>) -> String? {
        group.sorted { $0.timestamp > $1.timestamp }.lazy.compactMap { $0[keyPath: key] }.first
    }

    // MARK: - Persistence

    private func scheduleSave() {
        guard snapshotURL != nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.flushSync()
        }
    }

    private func startPeriodicSave() {
        periodicSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                self.flushSync()
            }
        }
    }

    func flushSync() {
        guard let snapshotURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(BoardSnapshot(nextSeq: nextSeq, notes: notes)).write(to: snapshotURL, options: .atomic)
            saveError = nil
        } catch {
            print("NoteStore save error: \(error)")
            saveError = "Board not saved: \(error.localizedDescription)"
        }
    }

    private struct BoardSnapshot: Codable {
        let nextSeq: Int
        let notes: [Note]
    }

    private func loadFromDisk() {
        guard let snapshotURL, FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        do {
            let data = try Data(contentsOf: snapshotURL)
            if let snapshot = try? JSONDecoder().decode(BoardSnapshot.self, from: data) {
                notes = snapshot.notes
                nextSeq = snapshot.nextSeq
            } else {
                notes = try JSONDecoder().decode([Note].self, from: data)
            }
            nextSeq = max(nextSeq, (notes.compactMap(\.seq).max() ?? 0) + 1)
            for index in notes.indices.sorted(by: { notes[$0].timestamp < notes[$1].timestamp }) where notes[index].seq == nil {
                notes[index].seq = nextSeq
                nextSeq += 1
            }
            for index in notes.indices where notes[index].workspaceId == "local" {
                notes[index].workspaceId = "local:\(notes[index].workspaceLabel ?? "unknown")"
            }
            for index in notes.indices { notes[index].normalize() }
            pruneDecided()
        } catch {
            print("NoteStore load error: \(error)")
            let aside = snapshotURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: snapshotURL, to: aside)
        }
    }
}
