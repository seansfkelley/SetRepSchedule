import SwiftUI

enum TimerState {
    case waitingToStart, counting, waitingToConfirmCompletion
}

struct ActionButton: View {
    private static let repHaptic: SensoryFeedback = .impact
    private static let abortHaptic: SensoryFeedback = .warning
    private static let completeHaptic: SensoryFeedback = .success

    var exerciseName: String
    var setIndex: Int
    var totalSets: Int
    var reps: Int
    var durationSeconds: Int64?
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    @State private var timerState: TimerState = .waitingToStart
    @State private var remainingSeconds: Int64 = 0
    @State private var flashRed = false
    @State private var hapticTrigger: Int = 0
    @State private var hapticFeedback: SensoryFeedback = .impact
    @State private var timerTask: Task<Void, Never>?

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
        if flashRed {
            .red
        } else if timerState == .counting {
            Color(.systemBlue).opacity(0.15)
        } else if timerState == .waitingToConfirmCompletion || (isLastAction && durationSeconds == nil) {
            .green
        } else {
            .blue
        }
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            VStack(spacing: 8) {
                if let duration = durationSeconds {
                    switch timerState {
                    case .waitingToStart:
                        let m = Int(duration / 60)
                        let s = Int(duration % 60)
                        Text("Start (\(m):\(String(format: "%02d", s)))")
                            .font(.title.bold())
                        Text(repSubtitle)
                    case .counting:
                        Text(String(format: "%d:%02d", Int(remainingSeconds / 60), Int(remainingSeconds % 60)))
                            .font(.system(size: 48, weight: .bold).monospacedDigit())
                        Text(repSubtitle)
                    case .waitingToConfirmCompletion:
                        Text(completeLabel)
                            .font(.title.bold())
                    }
                } else {
                    Text(isLastAction ? completeLabel : "Complete Rep")
                        .font(.title.bold())
                    Text(repSubtitle)
                }
            }
            .foregroundStyle(timerState == .counting ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.white))
            .contentTransition(.identity)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(buttonColor)
            .animation(.easeInOut(duration: 0.15), value: flashRed)
            .animation(.easeInOut(duration: 0.2), value: timerState)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(trigger: hapticTrigger) { _, _ in hapticFeedback }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func triggerHaptic(_ feedback: SensoryFeedback) {
        hapticFeedback = feedback
        hapticTrigger += 1
    }

    private func startCountdown(duration: Int64) {
        remainingSeconds = duration
        timerState = .counting
        triggerHaptic(Self.repHaptic)
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                remainingSeconds -= 1
                if remainingSeconds == 0 {
                    if isLastRep {
                        timerState = .waitingToConfirmCompletion
                    } else {
                        timerState = .waitingToStart
                        triggerHaptic(Self.repHaptic)
                    }
                    completedReps += 1
                    break
                }
            }
        }
    }

    private func abortCountdown() {
        timerTask?.cancel()
        timerTask = nil
        triggerHaptic(Self.abortHaptic)
        flashRed = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            flashRed = false
            if isLastRep {
                timerState = .waitingToConfirmCompletion
            } else {
                timerState = .waitingToStart
            }
            completedReps += 1
        }
    }

    private func handleTap() {
        if let duration = durationSeconds {
            switch timerState {
            case .waitingToStart:
                startCountdown(duration: duration)
            case .counting:
                abortCountdown()
            case .waitingToConfirmCompletion:
                triggerHaptic(Self.completeHaptic)
                onAdvance()
            }
        } else {
            completedReps += 1
            if completedReps >= reps {
                triggerHaptic(Self.completeHaptic)
                onAdvance()
            } else {
                triggerHaptic(Self.repHaptic)
            }
        }
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
        durationSeconds: 5,
        completedReps: $reps,
        onAdvance: {}
    )
}
