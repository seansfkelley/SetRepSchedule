import SwiftUI

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
