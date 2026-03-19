import SwiftUI
import SwiftData

struct DeckView: View {
    var exercise: Exercise
    var setIndex: Int
    var progressViewTarget: CGRect
    var onSetComplete: (_ completedReps: Int) -> Void

    @State private var completedReps: Int = 0
    @State private var highestDealtIndex: Int = 0

    var body: some View {
        BaseCard(exercise: exercise)
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    ForEach((0..<exercise.sets).reversed(), id: \.self) { cardIndex in
                        let isTop = cardIndex == setIndex
                        let isDealt = cardIndex >= highestDealtIndex
                        DeckCard(
                            exercise: exercise,
                            setIndex: cardIndex,
                            isTop: isTop,
                            progressViewTarget: progressViewTarget,
                            completedReps: isTop ? $completedReps : .constant(0),
                            onSetComplete: {
                                onSetComplete(completedReps)
                                completedReps = 0
                            },
                        )
                        .opacity(isDealt ? 1 : 0)
                        .offset(y: isDealt ? 0 : -60)
                        .if(cardIndex < setIndex) { view in
                            view.hidden()
                        }
                    }
                }
                .padding(BaseCard.setCardInset)
            }
            .task(id: exercise.id) {
                highestDealtIndex = exercise.sets - 1
                for i in 0..<exercise.sets {
                    try? await Task.sleep(for: .seconds(Double(i) * 0.1))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        highestDealtIndex -= 1
                    }
                }
            }
    }
}

private struct DeckCard: View {
    var exercise: Exercise
    var setIndex: Int
    var isTop: Bool
    var progressViewTarget: CGRect
    @Binding var completedReps: Int
    var onSetComplete: () -> Void

    @State private var state = FlyingCardState()

    var body: some View {
        SetCard(
            exercise: exercise,
            setIndex: setIndex,
            isActive: isTop,
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
        .opacity(state.opacity)
        .highPriorityGesture(
            DragGesture()
                .onChanged {
                    if isTop && !state.isFlying {
                        state.onDragChanged($0.translation)
                    }
                }
                .onEnded {
                    if isTop && !state.isFlying {
                        state.onDragEnded($0, onComplete: onSetComplete)
                    }
                },
            isEnabled: isTop && !state.isFlying
        )
        .onChange(of: progressViewTarget, initial: true) {
            state.targetFrame = progressViewTarget
        }
    }
}

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

        withAnimation(
            .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: initialVelocity),
            completionCriteria: .logicallyComplete
        ) {
            offset = dest
            scale = 0.1
            opacity = 0
        } completion: { @MainActor in
            onComplete()
        }
    }
}

private struct DeckPreview: View {
    let exercise: Exercise
    let initialSetIndex: Int
    @State private var setIndex: Int
    @State private var replayToken = 0
    @State private var progressViewTarget: CGRect = .zero

    init(exercise: Exercise, setIndex: Int = 0) {
        self.exercise = exercise
        self.initialSetIndex = setIndex
        _setIndex = State(initialValue: setIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(setIndex), total: Double(max(1, exercise.sets)))
                .progressViewStyle(.linear)
                .padding()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { progressViewTarget = $0 }
            DeckView(
                exercise: exercise,
                setIndex: setIndex,
                progressViewTarget: progressViewTarget,
                onSetComplete: { _ in setIndex += 1 }
            )
            .id(replayToken)
            .padding()
            Button("Replay") {
                setIndex = initialSetIndex
                replayToken += 1
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Basic") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Push-ups", sets: 3, reps: 5)
    DeckPreview(exercise: exercise, setIndex: 0)
        .modelContainer(container)
}

#Preview("Last set") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Lunges", sets: 3, reps: 10)
    DeckPreview(exercise: exercise, setIndex: 2)
        .modelContainer(container)
}

#Preview("With image") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12,
                                   imageData: previewImageData(color: .systemBlue))
    DeckPreview(exercise: exercise)
        .modelContainer(container)
}
