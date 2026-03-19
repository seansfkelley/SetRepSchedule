import SwiftUI
import SwiftData

struct DeckView: View {
    var exercise: Exercise
    var currentSetIndex: Int
    var dealtCount: Int
    @Binding var completedReps: [Int]
    var onSetComplete: (_ setIndex: Int, _ cardFrame: CGRect) -> Void
    var onFrameChange: (CGRect) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var dragVelocity: CGSize = .zero
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastDragTime: Date = .now
    @State private var topCardFrame: CGRect = .zero

    private let commitDistanceThreshold: CGFloat = 80
    private let commitVelocityThreshold: CGFloat = 400

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
        let setIndex = currentSetIndex
        BaseCard(exercise: exercise)
            .overlay(alignment: .bottom) {
                SetCard(
                    exercise: exercise,
                    setIndex: setIndex,
                    completedReps: repBinding(for: setIndex),
                    onAdvance: { onSetComplete(setIndex, .zero) }
                )
                .padding(BaseCard.setCardInset)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = $0.translation }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                dragOffset = .zero
                            }
                        }
                )
            }
    }
}

#Preview("All cards dealt") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    DeckView(
        exercise: exercise,
        currentSetIndex: 0,
        dealtCount: 3,
        completedReps: .constant([0, 0, 0]),
        onSetComplete: { _, _ in },
        onFrameChange: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}

#Preview("Mid-deck (set 2 of 3 on top)") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Push-ups", sets: 3, reps: 15)
    DeckView(
        exercise: exercise,
        currentSetIndex: 1,
        dealtCount: 2,
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
        dealtCount: 1,
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
        dealtCount: 3,
        completedReps: .constant([0, 0, 0]),
        onSetComplete: { _, _ in },
        onFrameChange: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
