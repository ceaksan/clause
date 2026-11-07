import SwiftUI
import ClauseShared

struct ContentView: View {
    @Environment(NoteStore.self) private var noteStore
    @State private var inputText = ""
    @State private var selectedType: Note.NoteType = .note
    @State private var isFloating = true

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
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .frame(minWidth: 280, minHeight: 300)
    }

    private var titleBar: some View {
        HStack {
            Text("Clause")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.53))

            Spacer()

            HStack(spacing: 6) {
                if noteStore.openDecisionCount > 0 {
                    Text("\(noteStore.openDecisionCount) open")
                        .font(.system(size: 10))
                        .foregroundStyle(NoteRowView.sentColor)
                }

                Button(action: { toggleFloating() }) {
                    Image(systemName: isFloating ? "pin.fill" : "pin.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(isFloating ? Color(white: 0.83) : Color(white: 0.33))
                }
                .buttonStyle(.plain)
                .help(isFloating ? "Unpin from top" : "Pin to top")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.07))
    }

    private var board: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if !noteStore.userNotes.isEmpty {
                    sectionHeader("You")
                    ForEach(noteStore.userNotes) { row($0) }
                }

                ForEach(noteStore.workspaceGroups) { workspace in
                    HStack {
                        sectionHeader(Self.title(workspace.label, workspace.id))
                        Spacer()
                        Button(action: { _ = noteStore.clearWorkspace(workspace.id) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(white: 0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Clear this workspace")
                    }

                    ForEach(workspace.panes) { pane in
                        Text(Self.title(pane.label, pane.id))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(.leading, 4)
                            .padding(.top, 2)
                        ForEach(pane.notes) { row($0) }
                    }
                }
            }
            .padding(8)
        }
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

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.6))
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.top, 6)
    }

    private func row(_ note: Note) -> some View {
        NoteRowView(note: note) {
            _ = noteStore.editNote(id: note.id, completed: !note.completed)
        }
        .contextMenu {
            if note.type == .decision {
                let next: DecisionStatus = note.status == .decided ? .sent : .decided
                Button(next == .decided ? "Mark decided" : "Mark sent") {
                    _ = noteStore.editNote(id: note.id, status: next)
                }
            }
            Button("Delete", role: .destructive) {
                _ = noteStore.deleteNote(id: note.id)
            }
        }
    }

    static func title(_ label: String?, _ id: String) -> String {
        guard let label, !label.isEmpty else { return id }
        return "\(label) · \(id)"
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
