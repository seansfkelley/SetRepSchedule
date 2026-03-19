import SwiftUI
import SwiftData

// Lays out a BaseCard with set cards stacked in its dotted zone.
// Set cards deal in one-by-one (controlled by dealtCount).
// Only the topmost remaining set card is draggable.
struct DeckView: View {
    var exercise: Exercise
    // Index of the set currently on top (0-based)
    var currentSetIndex: Int
    // Number of set cards that have been dealt in (for entrance animation)
    var dealtCount: Int
    // Per-set rep count array for this exercise
    var completedReps: Binding<[Int]>
    // Called when a set card is committed; passes set index and the card's global frame
    var onSetComplete: (_ setIndex: Int, _ cardFrame: CGRect) -> Void
    // Reports this deck's global frame upward
    var onFrameChange: (CGRect) -> Void

    // Must match BaseCard's setZoneInset so set cards land on the dotted outline
    private let setZoneInset: CGFloat = 8

    @State private var dragOffset: CGSize = .zero
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastDragTime: Date = .now
    @State private var dragVelocity: CGSize = .zero

    private let commitDistanceThreshold: CGFloat = 80
    private let commitVelocityThreshold: CGFloat = 400

    private func repBinding(for setIndex: Int) -> Binding<Int> {
        Binding(
            get: {
                let counts = completedReps.wrappedValue
                return setIndex < counts.count ? counts[setIndex] : 0
            },
            set: { newValue in
                var counts = completedReps.wrappedValue
                while counts.count <= setIndex { counts.append(0) }
                counts[setIndex] = newValue
                completedReps.wrappedValue = counts
            }
        )
    }

    var body: some View {
        // Use a ZStack so BaseCard fills the frame and set cards stack on top of it,
        // aligned to the bottom where the dotted zone lives.
        ZStack(alignment: .bottom) {
            BaseCard(exercise: exercise)

            let setsRemaining = exercise.sets - currentSetIndex
            ForEach(0..<setsRemaining, id: \.self) { stackIndex in
                let setIndex = currentSetIndex + stackIndex
                let isTop = stackIndex == 0
                let isDealt = stackIndex < dealtCount
                let dealOffset: CGFloat = isDealt ? 0 : -30

                // Wrap in GeometryReader only for the top card to capture its global frame
                if isTop {
                    GeometryReader { geo in
                        SetCard(
                            exercise: exercise,
                            setIndex: setIndex,
                            completedReps: repBinding(for: setIndex),
                            onAdvance: {
                                onSetComplete(setIndex, geo.frame(in: .global))
                            }
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(dragOffset)
                        .gesture(dragGesture(setIndex: setIndex, cardGeo: geo))
                    }
                    .padding(setZoneInset)
                    .offset(y: dealOffset)
                    .opacity(isDealt ? 1 : 0)
                } else {
                    SetCard(
                        exercise: exercise,
                        setIndex: setIndex,
                        completedReps: repBinding(for: setIndex),
                        onAdvance: {}
                    )
                    .padding(setZoneInset)
                    .offset(y: dealOffset)
                    .opacity(isDealt ? 1 : 0)
                }
            }
        }
        .background {
            // Report the full deck's global frame
            GeometryReader { geo in
                Color.clear
                    .preference(key: DeckFrameKey.self, value: geo.frame(in: .global))
            }
        }
        .onPreferenceChange(DeckFrameKey.self) { onFrameChange($0) }
    }

    private func dragGesture(setIndex: Int, cardGeo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragOffset = value.translation

                let now = Date()
                let dt = now.timeIntervalSince(lastDragTime)
                if dt > 0 {
                    dragVelocity = CGSize(
                        width: (value.location.x - lastDragLocation.x) / dt,
                        height: (value.location.y - lastDragLocation.y) / dt
                    )
                }
                lastDragLocation = value.location
                lastDragTime = now
            }
            .onEnded { value in
                let dist = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                let speed = sqrt(pow(dragVelocity.width, 2) + pow(dragVelocity.height, 2))
                let shouldCommit = dist > commitDistanceThreshold || speed > commitVelocityThreshold

                if shouldCommit {
                    let frame = cardGeo.frame(in: .global)
                    let offsetFrame = CGRect(
                        origin: CGPoint(x: frame.minX + value.translation.width,
                                        y: frame.minY + value.translation.height),
                        size: frame.size
                    )
                    dragOffset = .zero
                    onSetComplete(setIndex, offsetFrame)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        dragOffset = .zero
                    }
                }
                dragVelocity = .zero
            }
    }
}

struct DeckFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
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
