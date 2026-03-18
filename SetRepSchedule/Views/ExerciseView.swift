import SwiftUI
import SwiftData

struct ExerciseView: View {
    var exercises: [Exercise]
    @Binding var mode: AppMode

    @State private var exerciseIndex: Int = 0
    @State private var setIndex: Int = 0
    @State private var completedReps: [UUID: [Int]] = [:]
    @State private var isConfirmingExit: Bool = false
    @State private var cardOffset: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var isAnimatingOut = false
    @State private var showCompletion = false
    @State private var screenWidth: CGFloat = 400

    // How far the last card has travelled as a fraction 0→1, used to drive the completion animation.
    private var dismissProgress: Double {
        guard showCompletion, screenWidth > 0 else { return 0 }
        if isCompleted { return 1 }
        return Double(min(1, -cardOffset / screenWidth))
    }

    private var completionScale: CGFloat { 0.85 + 0.15 * dismissProgress }
    private var completionOpacity: Double { dismissProgress }

    private var currentExercise: Exercise? {
        guard exerciseIndex < exercises.count else { return nil }
        return exercises[exerciseIndex]
    }

    private var isCompleted: Bool {
        exerciseIndex >= exercises.count
    }

    // Build a binding for the current rep count, backed by completedReps
    private var currentRepBinding: Binding<Int> {
        guard let exercise = currentExercise else {
            return .constant(0)
        }
        let id = exercise.id
        return Binding(
            get: {
                let counts = self.completedReps[id, default: []]
                let idx = self.setIndex
                return idx < counts.count ? counts[idx] : 0
            },
            set: { newValue in
                var counts = self.completedReps[id, default: []]
                // Ensure the array has enough slots up to setIndex
                while counts.count <= self.setIndex {
                    counts.append(0)
                }
                counts[self.setIndex] = newValue
                self.completedReps[id] = counts
            }
        )
    }

    private var nextPosition: (exerciseIndex: Int, setIndex: Int)? {
        guard let exercise = currentExercise else { return nil }
        let nextSet = setIndex + 1
        if nextSet < exercise.sets {
            return (exerciseIndex, nextSet)
        } else {
            let nextExercise = exerciseIndex + 1
            if nextExercise < exercises.count {
                return (nextExercise, 0)
            }
        }
        return nil
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
                    .scaleEffect(completionScale)
                    .opacity(completionOpacity)
                }

                if !isCompleted, let exercise = currentExercise {
                    GeometryReader { geo in
                        // Next card: slides in from the right proportionally to the swipe
                        if cardOffset < 0, let next = nextPosition {
                            let nextExercise = exercises[next.exerciseIndex]
                            SetCard(
                                exerciseName: nextExercise.name,
                                setIndex: next.setIndex,
                                totalSets: nextExercise.sets,
                                reps: nextExercise.reps,
                                durationSeconds: nextExercise.durationSeconds,
                                imageData: nextExercise.imageData,
                                completedReps: .constant(0),
                                onAdvance: {}
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .offset(x: geo.size.width + cardOffset)
                            .allowsHitTesting(false)
                        }

                        // Current card
                        SetCard(
                            exerciseName: exercise.name,
                            setIndex: setIndex,
                            totalSets: exercise.sets,
                            reps: exercise.reps,
                            durationSeconds: exercise.durationSeconds,
                            imageData: exercise.imageData,
                            completedReps: currentRepBinding,
                            onAdvance: advanceCard
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .offset(x: cardOffset)
                        .rotationEffect(.degrees(cardRotation))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let translation = value.translation.width
                                    if translation < 0 {
                                        // Leftward drag: follows directly, gentle rotation
                                        cardOffset = translation
                                        cardRotation = translation / 35.0
                                        if nextPosition == nil {
                                            showCompletion = true
                                        }
                                    } else {
                                        // Rightward drag: resist with no rotation
                                        cardOffset = translation * 0.1
                                        cardRotation = 0
                                        if !isAnimatingOut {
                                            showCompletion = false
                                        }
                                    }
                                }
                                .onEnded { value in
                                    let translation = value.translation.width
                                    let velocity = value.predictedEndTranslation.width

                                    if translation < -100 || velocity < -300 {
                                        // Commit the swipe
                                        recordCurrentRepCount()
                                        flyCardOffAndAdvance(screenWidth: geo.size.width)
                                    } else {
                                        // Spring back
                                        withAnimation(.spring()) {
                                            cardOffset = 0
                                            cardRotation = 0
                                        }
                                        showCompletion = false
                                    }
                                }
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isCompleted {
                        Button {
                            mode = .planning
                        } label: {
                            Label("Return", systemImage: "chevron.left")
                                .labelStyle(.titleAndIcon)
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
        }
    }

    private func initializeCompletedReps() {
        for exercise in exercises {
            completedReps[exercise.id] = Array(repeating: 0, count: exercise.sets)
        }
    }

    private func recordCurrentRepCount() {
        // Ensure the current set has an entry (even if 0 reps were completed)
        guard let exercise = currentExercise else { return }
        let id = exercise.id
        var counts = completedReps[id, default: []]
        while counts.count <= setIndex {
            counts.append(0)
        }
        completedReps[id] = counts
    }

    private func advanceCard() {
        guard let exercise = currentExercise else { return }
        recordCurrentRepCount()
        flyCardOffAndAdvance(screenWidth: 400)
        _ = exercise  // suppress unused warning
    }

    private func flyCardOffAndAdvance(screenWidth: CGFloat) {
        guard !isAnimatingOut else { return }
        isAnimatingOut = true

        if nextPosition == nil {
            showCompletion = true
        }

        withAnimation(.easeIn(duration: 0.3)) {
            cardOffset = -screenWidth - 100
            cardRotation = -8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            advancePosition()
            cardOffset = 0
            cardRotation = 0
            isAnimatingOut = false
        }
    }

    private func advancePosition() {
        guard let exercise = currentExercise else { return }
        let nextSet = setIndex + 1
        if nextSet < exercise.sets {
            setIndex = nextSet
        } else {
            exerciseIndex += 1
            setIndex = 0
        }
    }
}

#Preview("Exercise mode — first card") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let plan = previewFullPlan(in: container)
    let exercises = plan.exercises.filter { $0.isValid }.sorted { $0.order < $1.order }
    return ExerciseView(exercises: exercises, mode: $mode)
        .modelContainer(container)
}

#Preview("Exercise mode — short plan") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let plan = previewShortPlan(in: container)
    let exercises = plan.exercises.filter { $0.isValid }.sorted { $0.order < $1.order }
    return ExerciseView(exercises: exercises, mode: $mode)
        .modelContainer(container)
}

#Preview("Exercise mode — timed exercise") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let e1 = previewExercise(in: container, order: 1, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    let e2 = previewExercise(in: container, order: 2, name: "Wall Sit", sets: 3, reps: 1, durationSeconds: 45)
    return ExerciseView(exercises: [e1, e2], mode: $mode)
        .modelContainer(container)
}
