import SwiftUI
import SwiftData

struct ExerciseView: View {
    var exercises: [Exercise]
    var planName: String
    @Binding var mode: AppMode

    @State private var completedReps: [UUID: [Int]] = [:]
    @State private var isConfirmingExit: Bool = false

    @State private var exerciseIndex: Int = 0
    @State private var currentSetIndex: Int = 0

    @State private var isCompleted: Bool = false

    @State private var progressBarFrame: CGRect = .zero

    private var currentExercise: Exercise? {
        guard exerciseIndex < exercises.count else { return nil }
        return exercises[exerciseIndex]
    }

    private var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }

    private var completedSetsCount: Int {
        var count = 0
        for (i, ex) in exercises.enumerated() {
            if i < exerciseIndex {
                count += ex.sets
            } else if i == exerciseIndex {
                count += currentSetIndex
            }
        }
        return count
    }

    private func repBinding(for index: Int) -> Binding<[Int]> {
        guard index < exercises.count else { return .constant([]) }
        let id = exercises[index].id
        return Binding(
            get: { self.completedReps[id, default: []] },
            set: { self.completedReps[id] = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isCompleted {
                    CompletionView(
                        exercises: exercises,
                        completedReps: completedReps,
                        onDone: { mode = .planning }
                    )
                }

                if let exercise = currentExercise, !isCompleted {
                    DeckView(
                        exercise: exercise,
                        currentSetIndex: currentSetIndex,
                        completedReps: repBinding(for: exerciseIndex),
                        progressViewTarget: progressBarFrame,
                        onSetComplete: { setIndex in
                            handleSetComplete(setIndex: setIndex)
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .safeAreaInset(edge: .top) {
                GeometryReader { geo in
                    ProgressView(value: Double(completedSetsCount), total: Double(max(1, totalSets)))
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .opacity(isCompleted ? 0 : 1)
                        .preference(key: ProgressBarFrameKey.self, value: geo.frame(in: .global))
                }
                .frame(height: 36)
                .onPreferenceChange(ProgressBarFrameKey.self) { progressBarFrame = $0 }
            }
            .navigationTitle(planName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isCompleted {
                        Button { mode = .planning } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Return").font(.title3)
                            }
                            .padding(.horizontal, 4)
                        }
                    } else if isConfirmingExit {
                        Button("End Exercises") { mode = .planning }
                            .foregroundStyle(.red)
                    } else {
                        Button { isConfirmingExit = true } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
        .onAppear {
            for exercise in exercises {
                completedReps[exercise.id] = Array(repeating: 0, count: exercise.sets)
            }
        }
    }

    // MARK: - Set Completion

    private func handleSetComplete(setIndex: Int) {
        guard let exercise = currentExercise else { return }
        let isLastSet = setIndex == exercise.sets - 1

        if isLastSet {
            advanceExercise()
        } else {
            currentSetIndex = setIndex + 1
        }
    }

    private func advanceExercise() {
        let nextIdx = exerciseIndex + 1
        if nextIdx >= exercises.count {
            isCompleted = true
        } else {
            exerciseIndex = nextIdx
            currentSetIndex = 0
        }
    }
}

private struct ProgressBarFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Previews

#Preview("Exercise mode — first card") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let plan = previewFullPlan(in: container)
    let exercises = plan.exercises.filter { $0.isValid }.sorted { $0.order < $1.order }
    return ExerciseView(exercises: exercises, planName: plan.name, mode: $mode)
        .modelContainer(container)
}

#Preview("Exercise mode — short plan") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let plan = previewShortPlan(in: container)
    let exercises = plan.exercises.filter { $0.isValid }.sorted { $0.order < $1.order }
    return ExerciseView(exercises: exercises, planName: plan.name, mode: $mode)
        .modelContainer(container)
}

#Preview("Exercise mode — timed exercise") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let e1 = previewExercise(in: container, order: 1, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    let e2 = previewExercise(in: container, order: 2, name: "Wall Sit", sets: 3, reps: 1, durationSeconds: 45)
    return ExerciseView(exercises: [e1, e2], planName: "Timed Plan", mode: $mode)
        .modelContainer(container)
}
