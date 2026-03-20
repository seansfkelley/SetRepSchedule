import SwiftUI

enum TimerState {
    case waitingToStart, counting, waitingToConfirmCompletion
}

struct ActionButton: View {
    var isLastSet: Bool
    var isActive: Bool = true
    var reps: Int
    var durationSeconds: Int64?
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    @AppStorage("isMuted") private var isMuted: Bool = false

    @State private var timerState: TimerState = .waitingToStart
    @State private var remainingSeconds: Int64 = 0
    @State private var flashRed = false
    @State private var timerTask: Task<Void, Never>?

    private var isLastRepOfSet: Bool {
        completedReps == reps - 1
    }

    private var lastRepLabel: String {
        isLastSet ? "Complete Exercise" : "Complete Set"
    }

    private var repSubtitle: Text {
        if isLastRepOfSet {
            Text("^[\(reps) Rep](inflect: true)")
        } else {
            Text("Rep \(completedReps + 1) of \(reps)")
        }
    }

    private var buttonColor: Color {
        if !isActive {
            Color(.systemGray5)
        } else if flashRed {
            .red
        } else if timerState == .counting {
            Color(.systemBlue).opacity(0.15)
        } else if timerState == .waitingToConfirmCompletion || (isLastRepOfSet && durationSeconds == nil) {
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
                        repSubtitle
                    case .counting:
                        Text(String(format: "%d:%02d", Int(remainingSeconds / 60), Int(remainingSeconds % 60)))
                            .font(.system(size: 48, weight: .bold).monospacedDigit())
                        repSubtitle
                    case .waitingToConfirmCompletion:
                        Text(lastRepLabel)
                            .font(.title.bold())
                    }
                } else {
                    Text(isLastRepOfSet ? lastRepLabel : "Complete Rep")
                        .font(.title.bold())
                    repSubtitle
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
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func startCountdown(duration: Int64) {
        remainingSeconds = duration
        timerState = .counting
        FeedbackEngine.playFeedback(for: .startTimer, isMuted: isMuted)
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                remainingSeconds -= 1
                if remainingSeconds == 0 {
                    if isLastRepOfSet {
                        timerState = .waitingToConfirmCompletion
                    } else {
                        timerState = .waitingToStart
                    }
                    FeedbackEngine.playFeedback(for: .completeTimer(isLastRepOfSet), isMuted: isMuted)
                    completedReps += 1
                    break
                }
            }
        }
    }

    private func abortCountdown() {
        timerTask?.cancel()
        timerTask = nil
        FeedbackEngine.playFeedback(for: .abortTimer, isMuted: isMuted)
        flashRed = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            flashRed = false
            if isLastRepOfSet {
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
                FeedbackEngine.playFeedback(for: .rep(true), isMuted: isMuted)
                onAdvance()
            }
        } else {
            completedReps += 1
            if completedReps >= reps {
                FeedbackEngine.playFeedback(for: .rep(true), isMuted: isMuted)
                onAdvance()
            } else {
                FeedbackEngine.playFeedback(for: .rep(false), isMuted: isMuted)
            }
        }
    }
}

#Preview("No timer — mid-set mid-exercise") {
    @Previewable @State var reps = 4
    ActionButton(
        isLastSet: false,
        reps: 12,
        durationSeconds: nil,
        completedReps: $reps,
        onAdvance: {}
    )
}

#Preview("No timer — last rep of last set") {
    @Previewable @State var reps = 11
    ActionButton(
        isLastSet: true,
        reps: 12,
        durationSeconds: nil,
        completedReps: $reps,
        onAdvance: {}
    )
}

#Preview("Timer — idle") {
    @Previewable @State var reps = 0
    ActionButton(
        isLastSet: false,
        reps: 1,
        durationSeconds: 3,
        completedReps: $reps,
        onAdvance: {}
    )
}
