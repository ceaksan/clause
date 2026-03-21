import Testing
import Foundation
@testable import ClauseShared
@testable import Clause

@Suite("NoteStore")
struct NoteStoreTests {
    @Test("Add note increases count")
    @MainActor func addNote() {
        let store = NoteStore()
        store.addNote(text: "Hello", source: .claude, type: .note)
        #expect(store.notes.count == 1)
        #expect(store.notes.first?.text == "Hello")
        #expect(store.notes.first?.source == .claude)
    }

    @Test("Edit note updates text")
    @MainActor func editNote() {
        let store = NoteStore()
        store.addNote(text: "Original", source: .user, type: .note)
        let id = store.notes.first!.id
        let result = store.editNote(id: id, text: "Updated", type: nil, completed: nil)
        #expect(result == true)
        #expect(store.notes.first?.text == "Updated")
    }

    @Test("Delete note removes it")
    @MainActor func deleteNote() {
        let store = NoteStore()
        store.addNote(text: "To delete", source: .claude, type: .note)
        let id = store.notes.first!.id
        let result = store.deleteNote(id: id)
        #expect(result == true)
        #expect(store.notes.isEmpty)
    }

    @Test("Clear removes all notes")
    @MainActor func clearNotes() {
        let store = NoteStore()
        store.addNote(text: "One", source: .claude, type: .note)
        store.addNote(text: "Two", source: .user, type: .todo)
        let count = store.clearNotes()
        #expect(count == 2)
        #expect(store.notes.isEmpty)
    }

    @Test("List notes with filter")
    @MainActor func listFiltered() {
        let store = NoteStore()
        store.addNote(text: "Note 1", source: .claude, type: .note)
        store.addNote(text: "Todo 1", source: .user, type: .todo)
        store.addNote(text: "Note 2", source: .claude, type: .note)
        let notes = store.listNotes(type: .note, source: nil)
        #expect(notes.count == 2)
        let todos = store.listNotes(type: .todo, source: .user)
        #expect(todos.count == 1)
    }

    @Test("Toggle completed on todo")
    @MainActor func toggleCompleted() {
        let store = NoteStore()
        store.addNote(text: "Task", source: .claude, type: .todo)
        let id = store.notes.first!.id
        _ = store.editNote(id: id, text: nil, type: nil, completed: true)
        #expect(store.notes.first?.completed == true)
    }

    @Test("Edit nonexistent note returns false")
    @MainActor func editMissing() {
        let store = NoteStore()
        let result = store.editNote(id: UUID(), text: "nope", type: nil, completed: nil)
        #expect(result == false)
    }

    @Test("Note text truncated at 4096 chars")
    @MainActor func textTruncation() {
        let store = NoteStore()
        let longText = String(repeating: "a", count: 5000)
        store.addNote(text: longText, source: .user, type: .note)
        #expect(store.notes.first?.text.count == 4096)
    }
}
