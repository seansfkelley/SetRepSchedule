import SwiftUI
import SwiftData

@Observable
private class FlyingCardState {
    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var opacity: Double = 1

    var isFlying: Bool = false

    var cardFrame: CGRect = .zero
    var targetFrame: CGRect = .zero

    var targetOffset: CGSize {
        guard cardFrame != .zero, targetFrame != .zero else { return .zero }
        return CGSize(
            width: targetFrame.midX - cardFrame.midX,
            height: targetFrame.midY - cardFrame.midY,
        )
    }

    let commitThreshold: CGFloat = 400

    func onDragChanged(_ translation: CGSize) {
        offset = translation
    }

    func onDragEnded(_ value: DragGesture.Value, onComplete: @escaping () -> Void) {
        let predicted = value.predictedEndTranslation
        let dist = hypot(predicted.width, predicted.height)
        if dist > commitThreshold {
            fly(to: targetOffset, velocity: value.velocity, onComplete: onComplete)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                offset = .zero
            }
        }
    }

    func fly(to dest: CGSize, velocity: CGSize = .zero, onComplete: @escaping () -> Void) {
        guard !isFlying else { return }

        // Normalize velocity to distance for interpolatingSpring's initialVelocity (per-unit).
        let dx = dest.width - offset.width
        let dy = dest.height - offset.height
        let initialVelocity: Double
        if abs(dy) >= abs(dx) {
            initialVelocity = dy != 0 ? Double(velocity.height / dy) : 0
        } else {
            initialVelocity = dx != 0 ? Double(velocity.width / dx) : 0
        }

        isFlying = true

        withAnimation(.interpolatingSpring(duration: 0.3, bounce: 0.2, initialVelocity: initialVelocity)) {
            offset = dest
            scale = 0.1
            opacity = 0
        } completion: { @MainActor in
            onComplete()
        }
    }
}

struct DeckView: View {
    var exercise: Exercise
    @Binding var completedReps: [Int]
    var progressViewTarget: CGRect
    var onSetComplete: () -> Void

    @State private var dismissedSets: Set<Int> = []
    @State private var dealtCount: Int = 0

    private func repBinding(for setIndex: Int) -> Binding<Int> {
        Binding(
            get: { setIndex < completedReps.count ? completedReps[setIndex] : 0 },
            set: { newValue in
                while completedReps.count <= setIndex { completedReps.append(0) }
                completedReps[setIndex] = newValue
            }
        )
    }

    var body: some View {
        // undismissedIndices[0] is the top card, [1] is behind it, etc.
        let undismissedIndices = (0..<exercise.sets).filter { !dismissedSets.contains($0) }

        return BaseCard(exercise: exercise)
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    ForEach((0..<exercise.sets).reversed(), id: \.self) { setIndex in
                        let stackIndex = undismissedIndices.firstIndex(of: setIndex) ?? -1
                        let isTop = stackIndex == 0
                        let isDealt = setIndex < dealtCount
                        let isDismissed = dismissedSets.contains(setIndex)

                        DeckCard(
                            exercise: exercise,
                            setIndex: setIndex,
                            isTop: isTop,
                            isDealt: isDealt,
                            progressViewTarget: progressViewTarget,
                            completedReps: repBinding(for: setIndex),
                            onSetComplete: {
                                dismissedSets.insert(setIndex)
                                onSetComplete()
                            }
                        )
                        .opacity(isDismissed ? 0 : 1)
                        .allowsHitTesting(!isDismissed)
                    }
                }
                .padding(BaseCard.setCardInset)
            }
            .task(id: exercise.id) {
                dealtCount = 0
                for i in 0..<exercise.sets {
                    try? await Task.sleep(for: .seconds(Double(i) * 0.05))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        dealtCount = i + 1
                    }
                }
            }
    }
}

private struct DeckCard: View {
    var exercise: Exercise
    var setIndex: Int
    var isTop: Bool
    var isDealt: Bool
    var progressViewTarget: CGRect
    @Binding var completedReps: Int
    var onSetComplete: () -> Void

    @State private var state = FlyingCardState()

    var body: some View {
        SetCard(
            exercise: exercise,
            setIndex: setIndex,
            isActive: isTop && isDealt,
            completedReps: $completedReps,
            onAdvance: {
                state.fly(to: state.targetOffset, onComplete: onSetComplete)
            }
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            guard !state.isFlying else { return }
            state.cardFrame = frame.offsetBy(dx: -state.offset.width, dy: -state.offset.height)
        }
        .scaleEffect(state.scale)
        .offset(state.offset)
        .opacity(isDealt ? state.opacity : 0)
        .offset(y: isDealt ? 0 : -60)
        .highPriorityGesture(
            DragGesture()
                .onChanged { if isTop && !state.isFlying { state.onDragChanged($0.translation) } }
                .onEnded { if isTop && !state.isFlying { state.onDragEnded($0, onComplete: onSetComplete) } },
            isEnabled: isTop && !state.isFlying
        )
        .onChange(of: progressViewTarget, initial: true) {
            state.targetFrame = progressViewTarget
        }
    }
}

private struct DealAnimationPreview: View {
    let exercise: Exercise
    @State private var completedReps = [0, 0, 0]
    @State private var replayToken = 0
    @State private var progressViewTarget: CGRect = .zero

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: 0.4)
                .progressViewStyle(.linear)
                .padding()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { progressViewTarget = $0 }
            DeckView(
                exercise: exercise,
                completedReps: $completedReps,
                progressViewTarget: progressViewTarget,
                onSetComplete: {}
            )
            .id(replayToken)
            Button("Replay") {
                completedReps = [0, 0, 0]
                replayToken += 1
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct StaticDeckPreview: View {
    let exercise: Exercise
    @State private var completedSets: Int = 0
    @State private var completedReps: [Int]
    @State private var progressViewTarget: CGRect = .zero

    init(exercise: Exercise, completedReps: [Int]) {
        self.exercise = exercise
        _completedReps = State(initialValue: completedReps)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(completedSets), total: Double(max(1, exercise.sets)))
                .progressViewStyle(.linear)
                .padding()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { progressViewTarget = $0 }
            DeckView(
                exercise: exercise,
                completedReps: $completedReps,
                progressViewTarget: progressViewTarget,
                onSetComplete: { completedSets += 1 }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Deal animation") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    DealAnimationPreview(exercise: exercise)
        .modelContainer(container)
}

#Preview("Mid-deck (set 2 of 3 on top)") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Push-ups", sets: 3, reps: 5)
    StaticDeckPreview(exercise: exercise, completedReps: [5, 2, 0])
        .modelContainer(container)
}

#Preview("Last set") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Lunges", sets: 3, reps: 10)
    StaticDeckPreview(exercise: exercise, completedReps: [10, 10, 0])
        .modelContainer(container)
}

#Preview("With image") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12,
                                   imageData: previewImageData(color: .systemBlue))
    StaticDeckPreview(exercise: exercise, completedReps: [0, 0, 0])
        .modelContainer(container)
}
