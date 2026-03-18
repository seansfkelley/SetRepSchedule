import SwiftUI
import SwiftData

struct SetsRepsPopover: View {
    @Bindable var exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...Int.max)
            Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...Int.max)
        }
        .padding()
        .presentationCompactAdaptation(.popover)
    }
}

struct SetsRepsButton: View {
    @Bindable var exercise: Exercise
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            VStack(spacing: 2) {
                Text("\(exercise.sets) × \(exercise.reps)")
                    .font(.subheadline.monospacedDigit())
                Text("Sets × Reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showPopover) {
            SetsRepsPopover(exercise: exercise)
        }
    }
}

#Preview("SetsRepsButton") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, sets: 3, reps: 12)
    return SetsRepsButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

#Preview("SetsRepsPopover") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, sets: 4, reps: 8)
    return SetsRepsPopover(exercise: exercise)
        .modelContainer(container)
}
