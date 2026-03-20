import SwiftUI

enum TimerState {
    case waitingToStart, counting
}

struct ActionButton: View {
    var isLastSet: Bool
    var isActive: Bool = true
    var reps: Int
    var durationSeconds: Int64?
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    @AppStorage("isAudioMuted") private var isAudioMuted: Bool = false
    @AppStorage("isHapticsMuted") private var isHapticsMuted: Bool = false

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
        Text("Rep \(completedReps + 1) of \(reps)")
            .font(.title3)
    }

    private var buttonColor: Color {
        if !isActive {
            Color(.systemGray5)
        } else if flashRed {
            .red
        } else if timerState == .counting {
            isLastRepOfSet
            ? Color(.green).opacity(0.15)
            : Color(.systemBlue).opacity(0.15)
        } else if isLastRepOfSet {
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
                            .font(.largeTitle.bold())
                        repSubtitle
                    case .counting:
                        Text(String(format: "%d:%02d", Int(remainingSeconds / 60), Int(remainingSeconds % 60)))
                            .font(.largeTitle.bold().monospacedDigit())
                        repSubtitle
                    }
                } else {
                    Text(isLastRepOfSet ? lastRepLabel : "Complete Rep")
                        .font(.largeTitle.bold())
                    repSubtitle
                }
            }
            .foregroundStyle(timerState == .counting ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.white))
            .contentTransition(.identity)
            .frame(maxWidth: .infinity, minHeight: 250)
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
        guard timerState == .waitingToStart else { return }

        remainingSeconds = duration
        timerState = .counting
        FeedbackEngine.playFeedback(for: .startTimer, isAudioMuted: isAudioMuted, isHapticsMuted: isHapticsMuted)
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                remainingSeconds -= 1
                if remainingSeconds == 0 {
                    timerState = .waitingToStart
                    FeedbackEngine.playFeedback(for: .completeTimer(isLastRepOfSet), isAudioMuted: isAudioMuted, isHapticsMuted: isHapticsMuted)
                    if isLastRepOfSet {
                        onAdvance()
                    } else {
                        completedReps += 1
                    }
                    break
                }
            }
        }
    }

    private func abortCountdown() {
        timerTask?.cancel()
        timerTask = nil
        FeedbackEngine.playFeedback(for: .abortTimer, isAudioMuted: isAudioMuted, isHapticsMuted: isHapticsMuted)
        flashRed = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            flashRed = false
            timerState = .waitingToStart
            completedReps += 1
            if isLastRepOfSet {
                onAdvance()
            }
        }
    }

    private func handleTap() {
        if let duration = durationSeconds {
            switch timerState {
            case .waitingToStart:
                startCountdown(duration: duration)
            case .counting:
                abortCountdown()
            }
        } else {
            completedReps += 1
            if completedReps >= reps {
                FeedbackEngine.playFeedback(for: .rep(true), isAudioMuted: isAudioMuted, isHapticsMuted: isHapticsMuted)
                onAdvance()
            } else {
                FeedbackEngine.playFeedback(for: .rep(false), isAudioMuted: isAudioMuted, isHapticsMuted: isHapticsMuted)
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
