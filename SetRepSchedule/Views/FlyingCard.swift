import SwiftUI
import SwiftData

// A set card that animates in a quadratic Bezier arc from a start position
// (where the card was released) toward a target position (the progress bar).
// The card shrinks and fades as it approaches the target.
struct FlyingCard: View {
    var exercise: Exercise
    var setIndex: Int
    var startFrame: CGRect
    var targetFrame: CGRect
    var onComplete: () -> Void

    @State private var progress: CGFloat = 0

    // Quadratic Bezier control point: biases the arc upward and toward the bar
    private var controlPoint: CGPoint {
        let mid = CGPoint(
            x: (startFrame.midX + targetFrame.midX) / 2,
            y: (startFrame.midY + targetFrame.midY) / 2
        )
        let dx = targetFrame.midX - startFrame.midX
        let dy = targetFrame.midY - startFrame.midY
        let length = sqrt(dx * dx + dy * dy)
        let perpX = -dy / max(1, length)
        let perpY = dx / max(1, length)
        let arcHeight = max(120, length * 0.6)
        return CGPoint(
            x: mid.x + perpX * arcHeight,
            y: mid.y + perpY * arcHeight - arcHeight * 0.5
        )
    }

    private func bezierPosition(at t: CGFloat) -> CGPoint {
        let cp = controlPoint
        let u = 1 - t
        return CGPoint(
            x: u * u * startFrame.midX + 2 * u * t * cp.x + t * t * targetFrame.midX,
            y: u * u * startFrame.midY + 2 * u * t * cp.y + t * t * targetFrame.midY
        )
    }

    private func cardSize(at t: CGFloat) -> CGSize {
        CGSize(
            width: startFrame.width * (1 - t) + targetFrame.width * t,
            height: startFrame.height * (1 - t) + targetFrame.height * t
        )
    }

    var body: some View {
        let pos = bezierPosition(at: progress)
        let size = cardSize(at: progress)
        let fadeOut = progress > 0.85 ? (1 - (progress - 0.85) / 0.15) : 1.0

        SetCard(
            exercise: exercise,
            setIndex: setIndex,
            completedReps: .constant(0),
            onAdvance: {}
        )
        .frame(width: size.width, height: size.height)
        .position(pos)
        .opacity(fadeOut)
        .onAppear {
            withAnimation(.easeIn(duration: 0.55)) {
                progress = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.55))
                onComplete()
            }
        }
    }
}

#Preview("Arc upward") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    // Simulate a card in the lower-center of the screen flying toward a progress bar at the top
    GeometryReader { geo in
        FlyingCard(
            exercise: exercise,
            setIndex: 0,
            startFrame: CGRect(
                x: geo.size.width * 0.1,
                y: geo.size.height * 0.6,
                width: geo.size.width * 0.8,
                height: geo.size.height * 0.25
            ),
            targetFrame: CGRect(
                x: geo.size.width * 0.1,
                y: 10,
                width: geo.size.width * 0.8,
                height: 4
            ),
            onComplete: {}
        )
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}

#Preview("Arc from left") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Push-ups", sets: 3, reps: 15)
    GeometryReader { geo in
        FlyingCard(
            exercise: exercise,
            setIndex: 1,
            startFrame: CGRect(
                x: -geo.size.width * 0.4,
                y: geo.size.height * 0.6,
                width: geo.size.width * 0.8,
                height: geo.size.height * 0.25
            ),
            targetFrame: CGRect(
                x: geo.size.width * 0.1,
                y: 10,
                width: geo.size.width * 0.8,
                height: 4
            ),
            onComplete: {}
        )
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
