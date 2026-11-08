import SwiftUI
import ClauseShared

struct NoteRowView: View {
    static let sentColor = Color(red: 0.98, green: 0.75, blue: 0.14)
    static let decidedColor = Color(red: 0.29, green: 0.78, blue: 0.47)
    static let noteColor = Color(red: 0.51, green: 0.55, blue: 0.97)
    static let todoColor = Color(red: 0.98, green: 0.57, blue: 0.24)
    static let warningColor = Color(red: 0.97, green: 0.44, blue: 0.44)

    let note: Note
    var onToggleCompleted: (() -> Void)?
    var onSaveMemo: ((String) -> Void)?

    @State private var copied = false
    @State private var hovering = false
    @State private var editingMemo = false
    @State private var memoDraft = ""

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func stamp(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = date.formatted(.dateTime.hour().minute())
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return time
        case 1: return "Yesterday \(time)"
        default: return "\(date.formatted(.dateTime.day().month(.abbreviated))) \(time)"
        }
    }

    private var isOpenDecision: Bool { note.type == .decision && note.status == .sent }
    private var isClosed: Bool { note.completed || note.status == .decided }

    private var kindLabel: String {
        switch note.type {
        case .note: "Note"
        case .todo: note.completed ? "Done todo" : "Todo"
        case .warning: "Warning"
        case .decision: note.status == .decided ? "Decided" : "Decision sent, waiting"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            marker
                .frame(width: 14, height: 17)
                .help(kindLabel)
                .accessibilityLabel(kindLabel)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(.system(size: 13, weight: isOpenDecision ? .medium : .regular))
                    .foregroundStyle(Color(white: isClosed ? 0.5 : 0.9))
                    .strikethrough(note.completed, color: Color(white: 0.4))
                    .lineSpacing(4)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                meta

                if editingMemo {
                    memoEditor
                } else if let memo = note.memo {
                    memoView(memo)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isOpenDecision ? Self.sentColor.opacity(0.07) : Color(white: hovering ? 0.13 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isOpenDecision ? Self.sentColor.opacity(0.22) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var marker: some View {
        switch note.type {
        case .todo:
            Button(action: { onToggleCompleted?() }) {
                Image(systemName: note.completed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(Self.todoColor.opacity(note.completed ? 0.5 : 1))
            }
            .buttonStyle(.plain)
        case .decision where note.status == .decided:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Self.decidedColor.opacity(0.75))
        case .decision:
            Image(systemName: "circle.dotted")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Self.sentColor)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Self.warningColor)
        case .note:
            Circle()
                .fill(Self.noteColor)
                .frame(width: 6, height: 6)
        }
    }

    private var meta: some View {
        HStack(spacing: 6) {
            if let ref = note.ref {
                Button(action: { copy(ref) }) {
                    HStack(spacing: 3) {
                        Text(ref)
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color(white: copied ? 0.8 : 0.55))
                }
                .buttonStyle(.plain)
                .help("Copy \(ref)")
            }

            Text(Self.stamp(note.timestamp))
                .help(note.timestamp.formatted(date: .complete, time: .standard))

            if let decidedAt = note.decidedAt {
                Text("decided \(Self.stamp(decidedAt))")
                    .foregroundStyle(Self.decidedColor.opacity(0.6))
            }

            Spacer(minLength: 0)

            if note.type == .decision && note.memo == nil && !editingMemo {
                Button(action: startEditingMemo) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(white: 0.55))
                .opacity(hovering ? 1 : 0.35)
                .help("Add a private note")
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color(white: 0.4))
    }

    private func memoView(_ memo: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(memo)
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.72))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button(action: startEditingMemo) { Image(systemName: "pencil") }
                    .help("Edit note")
                Button(action: { onSaveMemo?("") }) { Image(systemName: "trash") }
                    .help("Delete note")
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(Color(white: 0.5))
            .opacity(hovering ? 1 : 0.35)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.16)))
        .overlay(alignment: .leading) {
            Rectangle().fill(Self.sentColor.opacity(0.5)).frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.top, 2)
    }

    private var memoEditor: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextEditor(text: $memoDraft)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(4)
                .frame(minHeight: 44, maxHeight: 90)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.08)))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Self.sentColor.opacity(0.4), lineWidth: 1))
            HStack(spacing: 8) {
                Text("\(memoDraft.count)/\(ClauseConstants.maxMemoLength)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                Spacer()
                Button("Cancel") { editingMemo = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSaveMemo?(memoDraft)
                    editingMemo = false
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .font(.system(size: 11))
            .controlSize(.small)
        }
        .padding(.top, 2)
    }

    private func startEditingMemo() {
        memoDraft = note.memo ?? ""
        editingMemo = true
    }

    private func copy(_ ref: String) {
        Self.copyToPasteboard(ref)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
    }
}
