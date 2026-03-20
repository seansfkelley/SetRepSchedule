import SwiftUI
import SwiftData

struct CompletionView: View {
    var exercises: [Exercise]
    var completedReps: [UUID: [Int]]
    var onDone: () -> Void

    var body: some View {
        List {
            Section {
                Text("Workout Complete!")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(exercises) { exercise in
                    CompletionRow(
                        exercise: exercise,
                        repCounts: completedReps[exercise.id] ?? []
                    )
                }
            }

            Section {
                Button("Return to Planning") {
                    onDone()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
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
            if exercise.skipped {
                Image(systemName: "forward.end")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            } else {
                Image(systemName: isFullyComplete ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isFullyComplete ? .green : .red)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name.isEmpty ? "Unnamed Exercise" : exercise.name)
                    .font(.body)
                    .foregroundStyle(exercise.skipped || exercise.name.isEmpty ? .secondary : .primary)
                Text("^[\(exercise.sets) set](inflect: true) × ^[\(exercise.reps) rep](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let data = exercise.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(exercise.skipped ? 0.4 : 1)
            }

            ZStack(alignment: .trailing) {
                Text("100%")
                    .font(.title2.monospacedDigit())
                    .hidden()

                Text(exercise.skipped ? "" : "\(Int(completionFraction * 100))%")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(isFullyComplete ? .green : .red)
            }
        }
    }
}

#Preview("All complete") {
    let container = previewContainer()
    let plan = previewPlan(in: container)
    _ = previewExercise(
        in: container,
        plan: plan,
        order: 1,
        name: "Squats",
        sets: 3,
        reps: 12,
        imageData: previewImageData(color: .systemBlue)
    )
    _ = previewExercise(
        in: container,
        plan: plan,
        order: 2,
        name: "Push-ups",
        sets: 3,
        reps: 15,
        imageData: previewImageData(color: .systemGreen)
    )
    _ = previewExercise(
        in: container,
        plan: plan,
        order: 3,
        name: "Lunges",
        sets: 3,
        reps: 10
    )
    _ = previewExercise(
        in: container,
        plan: plan,
        order: 4,
        name: "Plank Hold",
        sets: 3,
        reps: 1,
        durationSeconds: 60
    )
    _ = previewExercise(
        in: container,
        plan: plan,
        order: 5,
        name: "Calf Raises",
        sets: 3,
        reps: 20,
        skipped: true,
        imageData: previewImageData(color: .systemCyan)
    )
    let exercises = plan.exercises.sorted { $0.order < $1.order }.filter { $0.isValid }
    // Every set fully completed (skipped exercises have no entries)
    let completedReps = Dictionary(uniqueKeysWithValues: exercises.compactMap { ex -> (UUID, [Int])? in
        guard !ex.skipped else { return nil }
        return (ex.id, Array(repeating: ex.reps, count: ex.sets))
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
                        skipped: true, imageData: previewImageData(color: .systemPurple))
    _ = previewExercise(in: container, plan: plan, order: 4, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    let exercises = plan.exercises.sorted { $0.order < $1.order }.filter { $0.isValid }
    // Alternate full and partial completion; skipped exercises have no entries
    let completedReps = Dictionary(uniqueKeysWithValues: exercises.enumerated().compactMap { i, ex -> (UUID, [Int])? in
        guard !ex.skipped else { return nil }
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
