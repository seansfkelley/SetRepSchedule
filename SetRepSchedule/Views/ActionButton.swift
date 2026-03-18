import SwiftUI
import Combine

enum TimerState {
    case idle
    case counting
    case expired
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

    private var actionLabel: String {
        if isLastRep {
            if isLastSet {
                return "Complete Exercise"
            } else {
                return "Complete Set \(setIndex + 1) of \(totalSets)"
            }
        } else {
            return "Complete Rep \(completedReps + 1) of \(reps)"
        }
    }

    private var buttonColor: Color {
        if flashRed { return .red }
        guard durationSeconds != nil else { return .green }
        switch timerState {
        case .idle: return Color(.systemBackground)
        case .counting: return Color(.systemBackground)
        case .expired: return .green
        }
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack {
                if durationSeconds != nil {
                    switch timerState {
                    case .idle:
                        let m = Int((durationSeconds ?? 0) / 60)
                        let s = Int((durationSeconds ?? 0) % 60)
                        Text("Start Timer (\(m):\(String(format: "%02d", s)))")
                            .font(.headline)
                    case .counting:
                        Image(systemName: "clock.fill")
                        Text(String(format: "%d:%02d", Int(remainingSeconds / 60), Int(remainingSeconds % 60)))
                            .font(.headline.monospacedDigit())
                    case .expired:
                        Text(actionLabel)
                            .font(.headline)
                    }
                } else {
                    Text(actionLabel)
                        .font(.headline)
                }
            }
            .foregroundStyle(durationSeconds != nil && timerState != .expired ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
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
                timerState = .expired
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
                // Flash red briefly, then count the rep
                flashRed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    flashRed = false
                    countRep()
                }
            case .expired:
                countRep()
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
        // Reset timer state for next rep
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
