import SwiftUI
import SwiftData

// Represents one card's position in the exercise sequence.
private struct CardPosition: Identifiable, Equatable {
    let exerciseId: UUID
    let exerciseIndex: Int
    let setIndex: Int

    var id: String { "\(exerciseId)-\(setIndex)" }
}

struct ExerciseView: View {
    var exercises: [Exercise]
    var planName: String
    @Binding var mode: AppMode

    @State private var completedReps: [UUID: [Int]] = [:]
    @State private var isConfirmingExit: Bool = false
    @State private var showCompletion = false

    @State private var scrollPosition: ScrollPosition = ScrollPosition()

    // Flat list of all cards in order.
    private var cards: [CardPosition] {
        var result: [CardPosition] = []
        for (ei, exercise) in exercises.enumerated() {
            for si in 0..<exercise.sets {
                result.append(CardPosition(exerciseId: exercise.id, exerciseIndex: ei, setIndex: si))
            }
        }
        return result
    }

    private var currentCard: CardPosition? {
        guard let id = scrollPosition.viewID(type: String.self) else {
            return cards.first
        }
        return cards.first(where: { $0.id == id }) ?? cards.first
    }

    private var isCompleted: Bool {
        showCompletion
    }

    private var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }

    private var completedSets: Int {
        guard let current = currentCard else { return 0 }
        let setsInPriorExercises = exercises.prefix(current.exerciseIndex).reduce(0) { $0 + $1.sets }
        return setsInPriorExercises + current.setIndex
    }

    // Build a binding for the rep count of a given card position.
    private func repBinding(for card: CardPosition) -> Binding<Int> {
        let exercise = exercises[card.exerciseIndex]
        let id = exercise.id
        let si = card.setIndex
        return Binding(
            get: {
                let counts = self.completedReps[id, default: []]
                return si < counts.count ? counts[si] : 0
            },
            set: { newValue in
                var counts = self.completedReps[id, default: []]
                while counts.count <= si {
                    counts.append(0)
                }
                counts[si] = newValue
                self.completedReps[id] = counts
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if showCompletion {
                    CompletionView(
                        exercises: exercises,
                        completedReps: completedReps,
                        onDone: { mode = .planning }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                if !showCompletion {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(cards) { card in
                                let exercise = exercises[card.exerciseIndex]
                                SetCard(
                                    exerciseName: exercise.name,
                                    setIndex: card.setIndex,
                                    totalSets: exercise.sets,
                                    reps: exercise.reps,
                                    durationSeconds: exercise.durationSeconds,
                                    notes: exercise.notes,
                                    imageData: exercise.imageData,
                                    completedReps: repBinding(for: card),
                                    onAdvance: { advanceCard() }
                                )
                                .padding(.horizontal, 16)
                                .containerRelativeFrame([.horizontal, .vertical])
                                .id(card.id)
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition($scrollPosition)
                    .scrollIndicators(.hidden)
                }
            }
            .safeAreaInset(edge: .top) {
                if !showCompletion {
                    ProgressView(value: Double(completedSets), total: Double(max(1, totalSets)))
                        .progressViewStyle(.linear)
                        .animation(.easeInOut(duration: 0.2), value: completedSets)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle(planName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isCompleted {
                        Button {
                            mode = .planning
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Return")
                                    .font(.title3)
                            }
                            .padding(.horizontal, 4)
                        }
                    } else if isConfirmingExit {
                        Button("End Exercises") {
                            mode = .planning
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button {
                            isConfirmingExit = true
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
        .onAppear {
            initializeCompletedReps()
            if let first = cards.first {
                scrollPosition = ScrollPosition(id: first.id)
            }
        }
    }

    private func initializeCompletedReps() {
        for exercise in exercises {
            completedReps[exercise.id] = Array(repeating: 0, count: exercise.sets)
        }
    }

    private func advanceCard() {
        guard let current = currentCard,
              let currentIdx = cards.firstIndex(of: current) else { return }

        let nextIdx = currentIdx + 1
        if nextIdx < cards.count {
            withAnimation(.easeInOut(duration: 0.4)) {
                scrollPosition = ScrollPosition(id: cards[nextIdx].id)
            }
        } else {
            // Past the last card — show completion
            withAnimation(.easeInOut(duration: 0.3)) {
                showCompletion = true
            }
        }
    }
}

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
