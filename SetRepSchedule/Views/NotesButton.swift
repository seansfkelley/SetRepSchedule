import SwiftUI
import SwiftData

struct NotesSheet: View {
    @Bindable var exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $exercise.notes)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding()
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium])
        .presentationBackground(.background)
        .onAppear { isFocused = true }
    }
}

struct NotesButton: View {
    @Bindable var exercise: Exercise
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .buttonStyle(.glass)
        .tint(exercise.notes.isEmpty ? .primary : .blue)
        .sheet(isPresented: $showSheet) {
            NotesSheet(exercise: exercise)
        }
    }
}

#Preview("NotesButton — empty") {
    let container = previewContainer()
    let exercise = previewExercise(in: container)
    return NotesButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

#Preview("NotesButton — with notes") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, notes: "Keep chest up, knees over toes.")
    return NotesButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

#Preview("NotesSheet") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, notes: "Keep chest up, knees over toes.")
    return NotesSheet(exercise: exercise)
        .modelContainer(container)
}
