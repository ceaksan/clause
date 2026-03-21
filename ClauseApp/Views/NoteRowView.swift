import SwiftUI
import ClauseShared

struct NoteRowView: View {
    let note: Note
    var onToggleCompleted: (() -> Void)?

    private var accentColor: Color {
        switch note.type {
        case .note: Color(red: 0.39, green: 0.4, blue: 0.95)
        case .todo: Color(red: 0.98, green: 0.57, blue: 0.24)
        case .warning: Color(red: 0.97, green: 0.44, blue: 0.44)
        }
    }

    private var badgeText: String {
        switch note.type {
        case .note: "NOTE"
        case .todo: "TODO"
        case .warning: "WARNING"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)
                .opacity(note.completed ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if note.type == .todo {
                        Button(action: { onToggleCompleted?() }) {
                            Image(systemName: note.completed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 12))
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(badgeText)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(white: 0.17))
                            .cornerRadius(3)
                    }

                    Text(note.source == .claude ? "C" : "U")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.33))

                    Spacer()

                    Text(note.timestamp, format: .dateTime.hour().minute())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.27))
                }

                Text(note.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.83))
                    .strikethrough(note.completed)
                    .lineLimit(5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(white: 0.12))
        .cornerRadius(6)
        .opacity(note.completed ? 0.5 : 1)
    }
}
