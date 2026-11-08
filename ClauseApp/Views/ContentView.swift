import SwiftUI
import ClauseShared

struct ContentView: View {
    @Environment(NoteStore.self) private var noteStore
    @State private var inputText = ""
    @State private var selectedType: Note.NoteType = .note
    @State private var isFloating = true
    @State private var pendingClear: NoteStore.WorkspaceGroup?

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            Divider().background(Color(white: 0.17))

            if noteStore.notes.isEmpty {
                emptyView
            } else {
                board
            }

            Divider().background(Color(white: 0.17))

            InputBar(text: $inputText, selectedType: $selectedType) {
                submitNote()
            }
        }
        .background(Color(white: 0.075))
        .frame(minWidth: 280, minHeight: 300)
        .confirmationDialog(
            "Clear \(pendingClear?.label ?? pendingClear?.id ?? "workspace")?",
            isPresented: Binding(get: { pendingClear != nil }, set: { if !$0 { pendingClear = nil } }),
            presenting: pendingClear
        ) { workspace in
            Button("Clear \(workspace.panes.reduce(0) { $0 + $1.notes.count }) notes", role: .destructive) {
                _ = noteStore.clearWorkspace(workspace.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Notes and private memos in this workspace are deleted. This cannot be undone.")
        }
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Text("Clause")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.75))

            Spacer()

            if noteStore.openDecisionCount > 0 {
                openPill(noteStore.openDecisionCount)
            }

            Button(action: { toggleFloating() }) {
                Image(systemName: isFloating ? "pin.fill" : "pin.slash")
                    .font(.system(size: 10))
                    .foregroundStyle(isFloating ? Color(white: 0.83) : Color(white: 0.33))
            }
            .buttonStyle(.plain)
            .help(isFloating ? "Unpin from top" : "Pin to top")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.05))
    }

    private var board: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !noteStore.userNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        workspaceHeader(title: "You", subtitle: nil, open: 0, onClear: nil)
                        ForEach(noteStore.userNotes) { row($0) }
                    }
                }

                ForEach(noteStore.workspaceGroups) { workspace in
                    VStack(alignment: .leading, spacing: 10) {
                        workspaceHeader(
                            title: workspace.label ?? workspace.id,
                            subtitle: Self.workspaceSubtitle(workspace),
                            open: noteStore.workspaceGroups.count > 1 ? Self.openCount(workspace.panes.flatMap(\.notes)) : 0,
                            onClear: { pendingClear = workspace }
                        )
                        ForEach(workspace.panes) { pane in
                            paneGroup(pane)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }

    private func workspaceHeader(title: String, subtitle: String?, open: Int, onClear: (() -> Void)?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(white: 0.95))
                .lineLimit(1)
                .truncationMode(.middle)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(white: 0.4))
            }
            Spacer()
            if open > 0 { openPill(open) }
            if let onClear {
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.38))
                }
                .buttonStyle(.plain)
                .help("Clear this workspace")
            }
        }
        .padding(.horizontal, 4)
    }

    private func paneGroup(_ pane: NoteStore.PaneGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "terminal")
                    .font(.system(size: 9))
                Text(pane.label ?? pane.id)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.7))
                if pane.label != nil {
                    Text(pane.id)
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            .foregroundStyle(Color(white: 0.4))
            .padding(.leading, 2)
            .padding(.bottom, 2)

            ForEach(pane.notes) { row($0) }
        }
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(white: 0.2))
                .frame(width: 1)
                .padding(.vertical, 2)
        }
        .padding(.leading, 4)
    }

    private func openPill(_ count: Int) -> some View {
        Text("\(count) open")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(NoteRowView.sentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(NoteRowView.sentColor.opacity(0.14)))
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text("No notes yet")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.33))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ note: Note) -> some View {
        NoteRowView(
            note: note,
            onToggleCompleted: { _ = noteStore.editNote(id: note.id, completed: !note.completed) },
            onSaveMemo: { noteStore.setMemo(id: note.id, $0) }
        )
        .contextMenu {
            if let ref = note.ref {
                Button("Copy ID \(ref)") { NoteRowView.copyToPasteboard(ref) }
            }
            if note.type == .decision {
                let next: DecisionStatus = note.status == .decided ? .sent : .decided
                Button(next == .decided ? "Mark decided" : "Mark sent") {
                    _ = noteStore.editNote(id: note.id, status: next)
                }
                if note.memo != nil {
                    Button("Delete private note") { noteStore.setMemo(id: note.id, "") }
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                _ = noteStore.deleteNote(id: note.id)
            }
        }
    }

    static func workspaceSubtitle(_ workspace: NoteStore.WorkspaceGroup) -> String? {
        guard let label = workspace.label, !workspace.id.hasPrefix("local") else { return nil }
        return workspace.id == label ? nil : workspace.id
    }

    static func openCount(_ notes: [Note]) -> Int {
        notes.filter { $0.type == .decision && $0.status == .sent }.count
    }

    private func submitNote() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        noteStore.addNote(text: trimmed, source: .user, type: selectedType)
        inputText = ""
    }

    private func toggleFloating() {
        isFloating.toggle()
        if let window = NSApp.windows.first {
            window.level = isFloating ? .floating : .normal
        }
    }
}
