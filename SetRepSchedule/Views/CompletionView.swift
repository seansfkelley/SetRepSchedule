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
                .padding(.top, 40)
                .padding(.bottom, 24)

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
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    onDone()
                }
            }
        }
    }
}

struct CompletionRow: View {
    var exercise: Exercise
    var repCounts: [Int]  // one entry per set, value = completed reps

    private var totalExpected: Int { exercise.sets * exercise.reps }

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
                Text(exercise.name.isEmpty ? "Exercise" : exercise.name)
                    .font(.body)
                Text("\(exercise.sets) sets × \(exercise.reps) reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(completionFraction * 100))%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isFullyComplete ? .green : .red)
        }
    }
}

#Preview("All complete") {
    let container = previewContainer()
    let plan = previewFullPlan(in: container)
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
    let plan = previewFullPlan(in: container)
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
