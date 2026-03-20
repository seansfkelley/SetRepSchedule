import SwiftUI
import SwiftData
import PhotosUI

struct ExerciseRow: View {
    @Bindable var exercise: Exercise
    var focusedExerciseId: FocusState<UUID?>.Binding
    var onDuplicate: () -> Void
    @State private var showInvalidPopover = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if !exercise.isValid {
                        Button {
                            showInvalidPopover = true
                        } label: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showInvalidPopover) {
                            Text("A name or picture is required.")
                                .padding()
                                .presentationCompactAdaptation(.popover)
                        }
                    }

                    TextField("Exercise name...", text: $exercise.name)
                        .font(.title3)
                        .focused(focusedExerciseId, equals: exercise.id)
                        .onChange(of: exercise.name) { _, newValue in
                            let trimmed = String(newValue.drop(while: { $0.isWhitespace }))
                            if trimmed != newValue {
                                exercise.name = trimmed
                            }
                        }
                }
                .padding(.leading, 4)

                HStack(spacing: 8) {
                    SetsRepsButton(exercise: exercise)
                    DurationButton(exercise: exercise)
                    NotesButton(exercise: exercise)
                    Button {
                        onDuplicate()
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .buttonStyle(.glass)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ImageButton(exercise: exercise)
        }
    }
}

// Preview wrapper — owns the @FocusState that ExerciseRow requires.
private struct ExerciseRowPreviewWrapper: View {
    var exercise: Exercise
    @FocusState private var focused: UUID?
    var onDuplicate: () -> Void = {}
    var body: some View {
        ExerciseRow(exercise: exercise, focusedExerciseId: $focused, onDuplicate: onDuplicate)
    }
}

#Preview("Valid exercise") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
    }
    .modelContainer(container)
}

#Preview("With timer") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
    }
    .modelContainer(container)
}

#Preview("Invalid — no name") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "")
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
    }
    .modelContainer(container)
}

#Preview("Full plan list") {
    let container = previewContainer()
    let plan = previewFullPlan(in: container)
    let exercises = plan.exercises.sorted { $0.order < $1.order }
    return List {
        ForEach(exercises) { ex in
            ExerciseRowPreviewWrapper(exercise: ex)
        }
    }
    .modelContainer(container)
}
