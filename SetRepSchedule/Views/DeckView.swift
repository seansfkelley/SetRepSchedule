import SwiftUI
import SwiftData

struct DeckView: View {
    var exercise: Exercise
    var currentSetIndex: Int
    @Binding var completedReps: [Int]
    var onSetComplete: (_ setIndex: Int, _ cardFrame: CGRect) -> Void
    var onFrameChange: (CGRect) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var topCardFrame: CGRect = .zero
    @State private var dealtCount: Int = 0

    private let commitThreshold: CGFloat = 400

    private func repBinding(for setIndex: Int) -> Binding<Int> {
        Binding(
            get: {
                setIndex < completedReps.count ? completedReps[setIndex] : 0
            },
            set: { newValue in
                while completedReps.count <= setIndex {
                    completedReps.append(0)
                }
                completedReps[setIndex] = newValue
            }
        )
    }

    var body: some View {
        let setsRemaining = exercise.sets - currentSetIndex
        BaseCard(exercise: exercise)
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    ForEach((0..<setsRemaining).reversed(), id: \.self) { stackIndex in
                        let setIndex = currentSetIndex + stackIndex
                        let isTop = stackIndex == 0
                        let isDealt = stackIndex >= setsRemaining - dealtCount

                        SetCard(
                            exercise: exercise,
                            setIndex: setIndex,
                            isActive: isTop && isDealt,
                            completedReps: repBinding(for: setIndex),
                            onAdvance: { onSetComplete(setIndex, topCardFrame) }
                        )
                        .background(isTop ? GeometryReader { geo in
                            Color.clear.onAppear { topCardFrame = geo.frame(in: .global) }
                        } : nil)
                        .opacity(isDealt ? 1 : 0)
                        .offset(y: isDealt ? 0 : -60)
                        .offset(isTop ? dragOffset : .zero)
                        .highPriorityGesture(isTop ? DragGesture()
                            .onChanged { dragOffset = $0.translation }
                            .onEnded { value in
                                let predicted = value.predictedEndTranslation
                                let dist = hypot(predicted.width, predicted.height)
                                if dist > commitThreshold {
                                    let offsetFrame = topCardFrame.offsetBy(
                                        dx: value.translation.width,
                                        dy: value.translation.height
                                    )
                                    dragOffset = .zero
                                    onSetComplete(currentSetIndex, offsetFrame)
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                    }
                                }
                            } : nil
                        )
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

private struct DealAnimationPreview: View {
    let exercise: Exercise
    @State private var completedReps = [0, 0, 0]
    @State private var replayToken = 0

    var body: some View {
        VStack {
            DeckView(
                exercise: exercise,
                currentSetIndex: 0,
                completedReps: $completedReps,
                onSetComplete: { _, _ in },
                onFrameChange: { _ in }
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

#Preview("Deal animation") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    DealAnimationPreview(exercise: exercise)
        .modelContainer(container)
}

#Preview("Mid-deck (set 2 of 3 on top)") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Push-ups", sets: 3, reps: 15)
    DeckView(
        exercise: exercise,
        currentSetIndex: 1,
        completedReps: .constant([15, 0, 0]),
        onSetComplete: { _, _ in },
        onFrameChange: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}

#Preview("Last set") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Lunges", sets: 3, reps: 10)
    DeckView(
        exercise: exercise,
        currentSetIndex: 2,
        completedReps: .constant([10, 10, 0]),
        onSetComplete: { _, _ in },
        onFrameChange: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}

#Preview("With image") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12,
                                   imageData: previewImageData(color: .systemBlue))
    DeckView(
        exercise: exercise,
        currentSetIndex: 0,
        completedReps: .constant([0, 0, 0]),
        onSetComplete: { _, _ in },
        onFrameChange: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
