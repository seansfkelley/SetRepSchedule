import SwiftUI
import SwiftData

struct ExerciseView: View {
    var allExercises: [Exercise]
    var planName: String
    @Binding var mode: AppMode

    private var exercises: [Exercise] {
        allExercises.filter { !$0.skipped }
    }

    @State private var completedReps: [UUID: [Int]] = [:]
    @State private var isConfirmingExit: Bool = false
    @AppStorage("isAudioMuted") private var isAudioMuted: Bool = false
    @AppStorage("isHapticsMuted") private var isHapticsMuted: Bool = false

    @State private var exerciseIndex: Int = 0
    @State private var completedSetsInCurrentExercise: Int = 0

    private func appendReps(_ reps: Int, for exercise: Exercise) {
        completedReps[exercise.id, default: []].append(reps)
    }

    @State private var isCompleted: Bool = false

    @State private var progressBarFrame: CGRect = .zero
    @State private var setCompletionTrigger: Int = 0

    // Keyed by slot index (exercise index, or exercises.count for completion).
    // Only slots present in this dict are rendered; at most two are present at once.
    @State private var cardStates: [Int: CardState] = [0: .entering]

    public static let exitDuration: Double = 0.3
    public static let entryDuration: Double = 0.3

    private var currentExercise: Exercise? {
        guard exerciseIndex < exercises.count else { return nil }
        return exercises[exerciseIndex]
    }

    private var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }

    private var completedSetsCount: Int {
        var count = 0
        for (i, ex) in exercises.enumerated() {
            if i < exerciseIndex {
                count += ex.sets
            } else if i == exerciseIndex {
                count += completedSetsInCurrentExercise
            }
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ForEach(Array(cardStates.keys.sorted()), id: \.self) { idx in
                    let state = cardStates[idx] ?? .entering
                    Group {
                        if idx < exercises.count {
                            DeckView(
                                exercise: exercises[idx],
                                setIndex: idx == exerciseIndex ? completedSetsInCurrentExercise : 0,
                                progressViewTarget: progressBarFrame,
                                onSetWillComplete: {
                                    setCompletionTrigger += 1
                                },
                                onSetComplete: { reps in
                                    appendReps(reps, for: exercises[idx])
                                    handleSetComplete()
                                }
                            )
                            .padding(.horizontal, 16)
                        } else {
                            CompletionView(
                                exercises: allExercises,
                                completedReps: completedReps,
                                onDone: { mode = .planning }
                            )
                            .onAppear {
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.3)) // totally empirical
                                    FeedbackEngine.playFeedback(
                                        for: .workoutComplete,
                                        isAudioMuted: isAudioMuted,
                                        isHapticsMuted: isHapticsMuted,
                                    )
                                }
                            }
                        }
                    }
                    .scaleEffect(state.scale)
                    .opacity(state.opacity)
                    .allowsHitTesting(state == .visible)
                    .animation(.easeOut(duration: Self.entryDuration), value: state)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: Self.entryDuration)) {
                    cardStates[0] = .visible
                }
            }
            .safeAreaInset(edge: .top) {
                GeometryReader { geo in
                    ProgressView(value: Double(completedSetsCount), total: Double(max(1, totalSets)))
                        .progressViewStyle(.linear)
                        .tint(.green)
                        .animation(.linear(duration: 0.4), value: completedSetsCount)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .opacity(isCompleted ? 0 : 1)
                        .keyframeAnimator(
                            initialValue: ProgressSquishValues(),
                            trigger: setCompletionTrigger
                        ) { content, value in
                            content.scaleEffect(
                                x: value.scaleX,
                                y: value.scaleY * 1.5,
                                anchor: .center,
                            )
                        } keyframes: { _ in
                            KeyframeTrack(\.scaleX) {
                                CubicKeyframe(0.9, duration: 0.15)
                                CubicKeyframe(1.1, duration: 0.15)
                                CubicKeyframe(1.0, duration: 0.10)
                            }
                            KeyframeTrack(\.scaleY) {
                                CubicKeyframe(1.2, duration: 0.15)
                                CubicKeyframe(0.7, duration: 0.15)
                                CubicKeyframe(1.0, duration: 0.10)
                            }
                        }
                        .preference(key: ProgressBarFrameKey.self, value: geo.frame(in: .global))
                }
                .frame(height: 36)
                .onPreferenceChange(ProgressBarFrameKey.self) { progressBarFrame = $0 }
            }
            .navigationTitle(planName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isCompleted {
                        Button { mode = .planning } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Return").font(.title3)
                            }
                            .padding(.horizontal, 4)
                        }
                    } else if isConfirmingExit {
                        Button("End Exercises") { mode = .planning }
                            .foregroundStyle(.red)
                    } else {
                        Button { isConfirmingExit = true } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isHapticsMuted.toggle()
                    } label: {
                        Image(systemName: isHapticsMuted ? "waveform.slash" : "waveform")
                            .foregroundStyle(isHapticsMuted ? .red : .primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAudioMuted.toggle()
                    } label: {
                        Image(systemName: isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(isAudioMuted ? .red : .primary)
                    }
                }

            }
        }

    }

    // MARK: - Set Completion

    private func handleSetComplete() {
        guard let exercise = currentExercise else { return }
        completedSetsInCurrentExercise += 1
        guard completedSetsInCurrentExercise >= exercise.sets else { return }

        let currentIdx = exerciseIndex
        let nextIdx = currentIdx + 1

        withAnimation(.easeIn(duration: Self.exitDuration)) {
            cardStates[currentIdx] = .exiting
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.exitDuration))
            cardStates.removeValue(forKey: currentIdx)
            if nextIdx >= exercises.count {
                isCompleted = true
                let completionIdx = exercises.count
                cardStates[completionIdx] = .entering
                withAnimation(.easeOut(duration: Self.entryDuration)) {
                    cardStates[completionIdx] = .visible
                }
            } else {
                exerciseIndex = nextIdx
                completedSetsInCurrentExercise = 0
                cardStates[nextIdx] = .entering
                withAnimation(.easeOut(duration: Self.entryDuration)) {
                    cardStates[nextIdx] = .visible
                }
            }
        }
    }
}

private struct ProgressSquishValues {
    var scaleX: Double = 1.0
    var scaleY: Double = 1.0
}

private struct ProgressBarFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private enum CardState: Equatable {
    case entering, visible, exiting

    var scale: CGFloat {
        switch self {
        case .entering: 0.8
        case .visible:  1.0
        case .exiting:  1.3
        }
    }

    var opacity: Double {
        switch self {
        case .entering: 0
        case .visible:  1
        case .exiting:  0
        }
    }
}

// MARK: - Previews

#Preview("Exercise mode — first card") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let plan = previewFullPlan(in: container)
    let exercises = plan.exercises.filter { $0.isValid }.sorted { $0.order < $1.order }
    return ExerciseView(allExercises: exercises, planName: plan.name, mode: $mode)
        .modelContainer(container)
}

#Preview("Exercise mode — short plan") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let plan = previewShortPlan(in: container)
    let exercises = plan.exercises.filter { $0.isValid }.sorted { $0.order < $1.order }
    return ExerciseView(allExercises: exercises, planName: plan.name, mode: $mode)
        .modelContainer(container)
}

#Preview("Exercise mode — timed exercise") {
    @Previewable @State var mode: AppMode = .exercise
    let container = previewContainer()
    let e1 = previewExercise(in: container, order: 1, name: "Plank Hold", sets: 1, reps: 1, durationSeconds: 3)
    let e2 = previewExercise(in: container, order: 2, name: "Wall Sit", sets: 1, reps: 1, durationSeconds: 3)
    return ExerciseView(allExercises: [e1, e2], planName: "Timed Plan", mode: $mode)
        .modelContainer(container)
}
