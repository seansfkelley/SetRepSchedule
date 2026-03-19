import SwiftUI
import SwiftData

// A small card showing the current set number and the action button.
// This is stacked on top of the base card in the deck metaphor.
struct SetCard: View {
    var exercise: Exercise
    var setIndex: Int
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Set \(setIndex + 1) of \(exercise.sets)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ActionButton(
                exerciseName: exercise.name,
                setIndex: setIndex,
                totalSets: exercise.sets,
                reps: exercise.reps,
                durationSeconds: exercise.durationSeconds,
                completedReps: $completedReps,
                onAdvance: onAdvance
            )
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0))
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Mid-set") {
    @Previewable @State var reps = 3
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    SetCard(exercise: exercise, setIndex: 1, completedReps: $reps, onAdvance: {})
        .padding()
        .frame(maxHeight: 200)
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Timed rep") {
    @Previewable @State var reps = 0
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    SetCard(exercise: exercise, setIndex: 0, completedReps: $reps, onAdvance: {})
        .padding()
        .frame(maxHeight: 200)
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
