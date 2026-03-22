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

            if noteStore.isSessionActive {
                noteList
            } else {
                standbyView
            }

            Divider().background(Color(white: 0.17))

            if noteStore.isSessionActive {
                InputBar(text: $inputText, selectedType: $selectedType) {
                    submitNote()
                }
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .frame(minWidth: 280, minHeight: 300)
    }

    private var titleBar: some View {
        HStack {
            Text(noteStore.session?.directory ?? "Clause")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(white: 0.53))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            HStack(spacing: 6) {
                Text("\(noteStore.notes.count) notes")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.33))
                Circle()
                    .fill(noteStore.isSessionActive ? Color.green : Color(white: 0.33))
                    .frame(width: 6, height: 6)

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

    private var noteList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(noteStore.notes) { note in
                    NoteRowView(note: note) {
                        _ = noteStore.editNote(id: note.id, text: nil, type: nil, completed: !note.completed)
                    }
                }
            }
            .padding(8)
        }
    }

    private var standbyView: some View {
        VStack {
            Spacer()
            Text("Waiting for session...")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.33))
            Spacer()
        }
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
