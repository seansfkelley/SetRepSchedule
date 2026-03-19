import SwiftUI
import SwiftData

private let encouragements: [String] = [
    "Keep it up!",
    "You've got this!",
    "Stay steady.",
    "Nice and easy.",
    "Looking good!",
    "One rep at a time.",
    "You're doing great.",
    "Keep going!",
    "Almost there!",
    "Eyes on the goal.",
    "Great work!",
    "Breathe and focus.",
    "Every rep counts.",
    "You're making progress.",
    "Nice work!",
    "Slow and steady.",
    "Trust the process.",
    "Take it step by step.",
    "Stronger every day.",
    "You've got this!",
]

struct SetCard: View {
    private let fadeLength: CGFloat = 24

    var exercise: Exercise
    var setIndex: Int
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    @State private var shuffled: [String] = encouragements.shuffled()
    @State private var phraseIndex: Int = 0
    @State private var phraseTimer: Timer?

    private var currentPhrase: String { shuffled[phraseIndex] }

    private let phraseInterval: TimeInterval = 4

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                if !exercise.name.isEmpty {
                    Text(exercise.name)
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                Text("Set \(setIndex + 1) of \(exercise.sets)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 12) {
                        if exercise.imageData == nil && exercise.notes.isEmpty {
                            Text(currentPhrase)
                                .font(.title)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .id(phraseIndex)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                        } else {
                            if let data = exercise.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(minWidth: 120, minHeight: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal, 32)
                            }
                            if !exercise.notes.isEmpty {
                                Text(exercise.notes)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: phraseIndex)
                    .padding(.vertical, fadeLength)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: fadeLength)
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: fadeLength)
                    }
                }
            }

            VStack(spacing: 8) {
                ProgressView(value: Double(completedReps), total: Double(max(1, exercise.reps)))
                    .progressViewStyle(.linear)
                    .animation(.easeInOut(duration: 0.2), value: completedReps)
                    .scaleEffect(y: 2, anchor: .center)
                    .frame(height: 20)
                    .padding(.horizontal)

                ActionButton(
                    exerciseName: exercise.name,
                    setIndex: setIndex,
                    totalSets: exercise.sets,
                    reps: exercise.reps,
                    durationSeconds: exercise.durationSeconds,
                    completedReps: $completedReps,
                    onAdvance: onAdvance
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            guard exercise.imageData == nil && exercise.notes.isEmpty else { return }
            phraseTimer = Timer.scheduledTimer(withTimeInterval: phraseInterval, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    phraseIndex = (phraseIndex + 1) % shuffled.count
                }
            }
        }
        .onDisappear {
            phraseTimer?.invalidate()
            phraseTimer = nil
        }
    }
}

#Preview("Minimal, mid-set") {
    @Previewable @State var reps = 3
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    SetCard(exercise: exercise, setIndex: 1, completedReps: $reps, onAdvance: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Timed rep") {
    @Previewable @State var reps = 0
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    SetCard(exercise: exercise, setIndex: 0, completedReps: $reps, onAdvance: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Last set, last rep") {
    @Previewable @State var reps = 11
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Lunges", sets: 3, reps: 12)
    SetCard(exercise: exercise, setIndex: 2, completedReps: $reps, onAdvance: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Image only") {
    @Previewable @State var reps = 0
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12,
                                   imageData: previewImageData(color: .systemBlue))
    SetCard(exercise: exercise, setIndex: 0, completedReps: $reps, onAdvance: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Notes only") {
    @Previewable @State var reps = 0
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12,
                                   notes: "Keep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.")
    SetCard(exercise: exercise, setIndex: 0, completedReps: $reps, onAdvance: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("With notes and image") {
    @Previewable @State var reps = 0
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12,
                                   notes: "Keep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.\nKeep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.\nKeep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.",
                                   imageData: previewImageData(color: .systemBlue))
    SetCard(exercise: exercise, setIndex: 0, completedReps: $reps, onAdvance: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
