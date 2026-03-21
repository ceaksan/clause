import SwiftUI
import ClauseShared

struct InputBar: View {
    @Binding var text: String
    @Binding var selectedType: Note.NoteType
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a note...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
                .cornerRadius(6)
                .onSubmit { onSubmit() }

            HStack(spacing: 4) {
                typeButton("N", type: .note)
                typeButton("T", type: .todo)
                typeButton("W", type: .warning)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func typeButton(_ label: String, type: Note.NoteType) -> some View {
        Button(action: { selectedType = type }) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(selectedType == type ? Color.white : Color(white: 0.53))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selectedType == type ? Color(white: 0.25) : Color(white: 0.17))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
