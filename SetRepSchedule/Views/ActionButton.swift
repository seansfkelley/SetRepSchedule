import SwiftUI
import Combine

enum TimerState {
    case idle
    case counting
}

struct ActionButton: View {
    var exerciseName: String
    var setIndex: Int
    var totalSets: Int
    var reps: Int
    var durationSeconds: Int64?
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    @State private var timerState: TimerState = .idle
    @State private var endDate: Date?
    @State private var remainingSeconds: Int64 = 0
    @State private var flashRed = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isLastSet: Bool { setIndex == totalSets - 1 }
    private var isLastRep: Bool { completedReps == reps - 1 }
    private var isLastAction: Bool { isLastRep && isLastSet }

    private var completeLabel: String {
        if isLastSet {
            return "Complete Exercise"
        } else {
            return "Complete Set \(setIndex + 1) of \(totalSets)"
        }
    }

    private var repSubtitle: String {
        "Rep \(completedReps + 1) of \(reps)"
    }

    private var buttonColor: Color {
        if flashRed { return .red }
        if timerState == .counting { return Color(.systemBlue).opacity(0.15) }
        if isLastAction && durationSeconds == nil { return .green }
        return .blue
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            VStack(spacing: 8) {
                if let duration = durationSeconds {
                    switch timerState {
                    case .idle:
                        let m = Int(duration / 60)
                        let s = Int(duration % 60)
                        Text("Start (\(m):\(String(format: "%02d", s)))")
                            .font(.title.bold())
                        Text(repSubtitle)
                    case .counting:
                        Text(String(format: "%d:%02d", Int(remainingSeconds / 60), Int(remainingSeconds % 60)))
                            .font(.system(size: 48, weight: .bold).monospacedDigit())
                        Text(repSubtitle)
                    }
                } else {
                    Text(isLastAction ? completeLabel : "Complete Rep")
                        .font(.title.bold())
                    Text(repSubtitle)
                }
            }
            .foregroundStyle(timerState == .counting ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.white))
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(buttonColor)
            .animation(.easeInOut(duration: 0.15), value: flashRed)
            .animation(.easeInOut(duration: 0.2), value: timerState)
        }
        .buttonStyle(.plain)
        .onReceive(timer) { _ in
            guard timerState == .counting, let end = endDate else { return }
            let remaining = Int64(max(0, end.timeIntervalSinceNow))
            remainingSeconds = remaining
            if remaining == 0 {
                timerState = .idle
                endDate = nil
                countRep()
            }
        }
    }

    private func handleTap() {
        if let duration = durationSeconds {
            switch timerState {
            case .idle:
                endDate = Date.now.addingTimeInterval(Double(duration))
                remainingSeconds = duration
                timerState = .counting
            case .counting:
                flashRed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    flashRed = false
                    countRep()
                }
            }
        } else {
            countRep()
        }
    }

    private func countRep() {
        completedReps += 1
        if completedReps >= reps {
            onAdvance()
        }
        timerState = .idle
        endDate = nil
        remainingSeconds = durationSeconds ?? 0
    }
}

#Preview("No timer — mid-set") {
    @Previewable @State var reps = 4
    ActionButton(
        exerciseName: "Squats",
        setIndex: 1,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        completedReps: $reps,
        onAdvance: {}
    )
}

#Preview("No timer — last rep of last set") {
    @Previewable @State var reps = 11
    ActionButton(
        exerciseName: "Push-ups",
        setIndex: 2,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        completedReps: $reps,
        onAdvance: {}
    )
}

#Preview("Timer — idle") {
    @Previewable @State var reps = 0
    ActionButton(
        exerciseName: "Plank Hold",
        setIndex: 0,
        totalSets: 3,
        reps: 1,
        durationSeconds: 60,
        completedReps: $reps,
        onAdvance: {}
    )
}
