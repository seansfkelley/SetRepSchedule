import SwiftUI
import SwiftData

struct ExerciseRow: View {
    @Bindable var exercise: Exercise
    var focusedExerciseId: FocusState<UUID?>.Binding
    var onDuplicate: () -> Void
    @State private var showInvalidPopover = false
    @State private var jiggle = false

    var body: some View {
        HStack(spacing: 8) {
            if !exercise.isValid {
                Button {
                    showInvalidPopover = true
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInvalidPopover) {
                    Text("A name or picture is required.")
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }

            TextField("Exercise name", text: $exercise.name)
                .focused(focusedExerciseId, equals: exercise.id)
                .onChange(of: exercise.name) { _, newValue in
                    // Trim leading whitespace on every keystroke
                    let trimmed = String(newValue.drop(while: { $0.isWhitespace }))
                    if trimmed != newValue {
                        exercise.name = trimmed
                    }
                }
                .rotationEffect(.degrees(jiggle ? 2 : 0))
                .animation(jiggle ? .easeInOut(duration: 0.08).repeatCount(4, autoreverses: true) : .default, value: jiggle)

            Spacer()

            SetsRepsButton(exercise: exercise)
            DurationButton(exercise: exercise)
            ImageButton(exercise: exercise)
            Button {
                onDuplicate()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    func triggerJiggle() {
        jiggle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            jiggle = false
        }
    }
}

// Preview wrapper — owns the @FocusState that ExerciseRow requires.
private struct ExerciseRowPreviewWrapper: View {
    var exercise: Exercise
    @FocusState private var focused: UUID?
    var body: some View {
        ExerciseRow(exercise: exercise, focusedExerciseId: $focused, onDuplicate: {})
    }
}

#Preview("Valid exercise") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
    }
    .listStyle(.plain)
    .modelContainer(container)
}

#Preview("With timer") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
    }
    .listStyle(.plain)
    .modelContainer(container)
}

#Preview("Invalid — no name") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "")
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
    }
    .listStyle(.plain)
    .modelContainer(container)
}
