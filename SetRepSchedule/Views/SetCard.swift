import SwiftUI
import SwiftData

struct SetCard: View {
    var exercise: Exercise
    var setIndex: Int
    var isActive: Bool = true
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(completedReps), total: Double(max(1, exercise.reps)))
                    .progressViewStyle(.linear)
                    .scaleEffect(y: 2, anchor: .top)
                    .animation(.easeInOut(duration: 0.2), value: completedReps)

                Text("Set \(setIndex + 1) of \(exercise.sets)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ActionButton(
                    isLastSet: setIndex == exercise.sets - 1,
                    isActive: isActive,
                    reps: exercise.reps,
                    durationSeconds: exercise.durationSeconds,
                    completedReps: $completedReps,
                    onAdvance: onAdvance
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        )
    }
}

#Preview("Inactive") {
    @Previewable @State var reps = 0
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    SetCard(exercise: exercise, setIndex: 0, isActive: false, completedReps: $reps, onAdvance: {})
        .padding()
        .frame(maxHeight: 200)
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
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
    let exercise = previewExercise(in: container, name: "Plank Hold", sets: 3, reps: 2, durationSeconds: 3)
    SetCard(exercise: exercise, setIndex: 0, completedReps: $reps, onAdvance: {})
        .padding()
        .frame(maxHeight: 200)
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

