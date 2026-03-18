import SwiftUI
import SwiftData

struct CompletionView: View {
    var exercises: [Exercise]
    var completedReps: [UUID: [Int]]
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Workout Complete!")
                .font(.largeTitle.bold())
                .padding(.vertical, 24)

            List {
                ForEach(exercises) { exercise in
                    CompletionRow(
                        exercise: exercise,
                        repCounts: completedReps[exercise.id] ?? []
                    )
                }
            }
            .listStyle(.insetGrouped)

            Button("Return to Planning") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

struct CompletionRow: View {
    private let imageSize: CGFloat = 36

    var exercise: Exercise
    var repCounts: [Int]  // one entry per set, value = completed reps

    private var totalExpected: Int {
        exercise.sets * exercise.reps
    }

    private var totalCompleted: Int {
        repCounts.reduce(0, +)
    }

    private var completionFraction: Double {
        guard totalExpected > 0 else { return 0 }
        return Double(totalCompleted) / Double(totalExpected)
    }

    private var isFullyComplete: Bool {
        totalCompleted >= totalExpected
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isFullyComplete ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isFullyComplete ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name.isEmpty ? "Unnamed Exercise" : exercise.name)
                    .font(.body)
                    .if(exercise.name.isEmpty) { view in
                        view.foregroundStyle(.secondary)
                    }
                Text("^[\(exercise.sets) set](inflect: true) × ^[\(exercise.reps) rep](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let data = exercise.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            Text("\(Int(completionFraction * 100))%")
                .font(.title2.monospacedDigit())
                .foregroundStyle(isFullyComplete ? .green : .red)
        }
    }
}

#Preview("All complete") {
    let container = previewContainer()
    let plan = previewPlan(in: container)
    _ = previewExercise(in: container, plan: plan, order: 1, name: "Squats", sets: 3, reps: 12,
                        imageData: previewImageData(color: .systemBlue))
    _ = previewExercise(in: container, plan: plan, order: 2, name: "Push-ups", sets: 3, reps: 15,
                        imageData: previewImageData(color: .systemGreen))
    _ = previewExercise(in: container, plan: plan, order: 3, name: "Lunges", sets: 3, reps: 10)
    _ = previewExercise(in: container, plan: plan, order: 4, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    let exercises = plan.exercises.sorted { $0.order < $1.order }.filter { $0.isValid }
    // Every set fully completed
    let completedReps = Dictionary(uniqueKeysWithValues: exercises.map { ex in
        (ex.id, Array(repeating: ex.reps, count: ex.sets))
    })
    return NavigationStack {
        CompletionView(exercises: exercises, completedReps: completedReps, onDone: {})
    }
    .modelContainer(container)
}

#Preview("Mixed results") {
    let container = previewContainer()
    let plan = previewPlan(in: container)
    _ = previewExercise(in: container, plan: plan, order: 1, name: "Squats", sets: 3, reps: 12,
                        imageData: previewImageData(color: .systemOrange))
    _ = previewExercise(in: container, plan: plan, order: 2, name: "Push-ups", sets: 3, reps: 15)
    _ = previewExercise(in: container, plan: plan, order: 3, name: "Lunges", sets: 3, reps: 10,
                        imageData: previewImageData(color: .systemPurple))
    _ = previewExercise(in: container, plan: plan, order: 4, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    let exercises = plan.exercises.sorted { $0.order < $1.order }.filter { $0.isValid }
    // Alternate full and partial completion
    let completedReps = Dictionary(uniqueKeysWithValues: exercises.enumerated().map { i, ex in
        let counts = i.isMultiple(of: 2)
            ? Array(repeating: ex.reps, count: ex.sets)            // fully done
            : Array(repeating: ex.reps / 2, count: ex.sets)        // half done
        return (ex.id, counts)
    })
    return NavigationStack {
        CompletionView(exercises: exercises, completedReps: completedReps, onDone: {})
    }
    .modelContainer(container)
}
