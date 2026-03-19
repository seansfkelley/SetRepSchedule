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
    @State private var completionFadeIn: CGFloat = 0

    // Entering animation
    @State private var baseCardVisible: Bool = false

    // Base card exit (on last set completion)
    @State private var baseCardExitProgress: CGFloat = 0

    // Exercise transition
    @State private var isTransitioning: Bool = false
    @State private var nextViewFadeIn: CGFloat = 0

    // Flying card overlays
    private struct FlyingCardInfo: Identifiable {
        var id: UUID = UUID()
        var setIndex: Int
        var startFrame: CGRect
    }
    @State private var flyingCards: [FlyingCardInfo] = []

    @State private var progressBarFrame: CGRect = .zero
    @State private var progressBarJiggle: CGFloat = 1

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
                    .opacity(completionFadeIn)
                    .scaleEffect(0.85 + completionFadeIn * 0.15)
                }

                if let exercise = currentExercise, !isCompleted {
                    DeckView(
                        exercise: exercise,
                        currentSetIndex: currentSetIndex,
                        completedReps: repBinding(for: exerciseIndex),
                        progressViewTarget: progressBarFrame,
                        onSetComplete: { setIndex, cardFrame in
                            handleSetComplete(setIndex: setIndex, cardFrame: cardFrame)
                        }
                    )
                    .padding(.horizontal, 16)
                    .opacity(baseCardVisible ? max(0, 1 - baseCardExitProgress) : 0)
                    .scaleEffect(
                        baseCardVisible ? (1 + baseCardExitProgress * 0.15) : 0.92,
                        anchor: .center
                    )
                }

                // Next exercise or completion preview during transitions
                if isTransitioning {
                    nextViewPreview()
                        .opacity(nextViewFadeIn)
                        .scaleEffect(0.85 + nextViewFadeIn * 0.15, anchor: .center)
                }

                // Flying card overlays in screen coordinate space
                GeometryReader { geo in
                    let localOrigin = geo.frame(in: .global).origin
                    ForEach(flyingCards) { info in
                        if let exercise = currentExercise {
                            FlyingCard(
                                exercise: exercise,
                                setIndex: info.setIndex,
                                startFrame: CGRect(
                                    origin: CGPoint(
                                        x: info.startFrame.minX - localOrigin.x,
                                        y: info.startFrame.minY - localOrigin.y
                                    ),
                                    size: info.startFrame.size
                                ),
                                targetFrame: CGRect(
                                    origin: CGPoint(
                                        x: progressBarFrame.minX - localOrigin.x,
                                        y: progressBarFrame.minY - localOrigin.y
                                    ),
                                    size: progressBarFrame.size
                                ),
                                onComplete: {
                                    flyingCards.removeAll { $0.id == info.id }
                                    triggerProgressBarJiggle()
                                }
                            )
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                GeometryReader { geo in
                    ProgressView(value: Double(completedSetsCount), total: Double(max(1, totalSets)))
                        .progressViewStyle(.linear)
                        .scaleEffect(CGSize(width: 1, height: progressBarJiggle), anchor: .center)
                        .animation(.spring(response: 0.2, dampingFraction: 0.3), value: progressBarJiggle)
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
            initializeState()
        }
    }

    @ViewBuilder
    private func nextViewPreview() -> some View {
        let nextIdx = exerciseIndex + 1
        if nextIdx < exercises.count {
            DeckView(
                exercise: exercises[nextIdx],
                currentSetIndex: 0,
                completedReps: repBinding(for: nextIdx),
                progressViewTarget: progressBarFrame,
                onSetComplete: { _, _ in }
            )
            .padding(.horizontal, 16)
        } else {
            CompletionView(
                exercises: exercises,
                completedReps: completedReps,
                onDone: { mode = .planning }
            )
        }
    }

    // MARK: - Setup

    private func initializeState() {
        for exercise in exercises {
            completedReps[exercise.id] = Array(repeating: 0, count: exercise.sets)
        }
        playEnteringAnimation()
    }

    // MARK: - Entering Animation

    private func playEnteringAnimation() {
        baseCardVisible = false

        withAnimation(.easeOut(duration: 0.35)) {
            baseCardVisible = true
        }
    }

    // MARK: - Set Completion

    private func handleSetComplete(setIndex: Int, cardFrame: CGRect) {
        guard let exercise = currentExercise else { return }
        let isLastSet = setIndex == exercise.sets - 1

        flyingCards.append(FlyingCardInfo(setIndex: setIndex, startFrame: cardFrame))

        if isLastSet {
            // Base card begins fading out at 25% of the flight (~0.14s)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.14))
                withAnimation(.easeIn(duration: 0.25)) {
                    baseCardExitProgress = 1
                }
            }
            // At 75% of flight (~0.41s), trigger next exercise or completion
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.41))
                advanceExercise()
            }
        } else {
            // Advance to next set card after a short moment
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.1))
                currentSetIndex = setIndex + 1
            }
        }
    }

    private func advanceExercise() {
        let nextIdx = exerciseIndex + 1
        isTransitioning = true

        withAnimation(.easeOut(duration: 0.4)) {
            nextViewFadeIn = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))

            if nextIdx >= exercises.count {
                isCompleted = true
                isTransitioning = false
                nextViewFadeIn = 0
                withAnimation(.easeOut(duration: 0.3)) {
                    completionFadeIn = 1
                }
            } else {
                exerciseIndex = nextIdx
                currentSetIndex = 0
                baseCardExitProgress = 0
                baseCardVisible = false
                isTransitioning = false
                nextViewFadeIn = 0
                playEnteringAnimation()
            }
        }
    }

    private func triggerProgressBarJiggle() {
        progressBarJiggle = 1.6
        withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
            progressBarJiggle = 1
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
