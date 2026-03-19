import SwiftUI

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

    var exerciseName: String
    var setIndex: Int
    var totalSets: Int
    var reps: Int
    var durationSeconds: Int64?
    var notes: String
    var imageData: Data?
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    @State private var shuffled: [String] = encouragements.shuffled()
    @State private var phraseIndex: Int = 0

    private var currentPhrase: String { shuffled[phraseIndex] }

    private let phraseInterval: TimeInterval = 4

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                if !exerciseName.isEmpty {
                    Text(exerciseName)
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                Text("Set \(setIndex + 1) of \(totalSets)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 12) {
                        if imageData == nil && notes.isEmpty {
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
                            if let data = imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(minWidth: 120, minHeight: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal, 32)
                            }
                            if !notes.isEmpty {
                                Text(notes)
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
                ProgressView(value: Double(completedReps), total: Double(max(1, reps)))
                    .progressViewStyle(.linear)
                    .animation(.easeInOut(duration: 0.2), value: completedReps)
                    .scaleEffect(y: 2, anchor: .center)
                    .frame(height: 20)
                    .padding(.horizontal)

                ActionButton(
                    exerciseName: exerciseName,
                    setIndex: setIndex,
                    totalSets: totalSets,
                    reps: reps,
                    durationSeconds: durationSeconds,
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
            guard imageData == nil && notes.isEmpty else { return }
            Timer.scheduledTimer(withTimeInterval: phraseInterval, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    phraseIndex = (phraseIndex + 1) % shuffled.count
                }
            }
        }
    }
}

#Preview("Minimal, mid-set") {
    @Previewable @State var reps = 3
    SetCard(
        exerciseName: "Squats",
        setIndex: 1,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        notes: "",
        imageData: nil,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Timed rep") {
    @Previewable @State var reps = 0
    SetCard(
        exerciseName: "Plank Hold",
        setIndex: 0,
        totalSets: 3,
        reps: 1,
        durationSeconds: 60,
        notes: "",
        imageData: nil,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Last set, last rep") {
    @Previewable @State var reps = 11
    SetCard(
        exerciseName: "Lunges",
        setIndex: 2,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        notes: "",
        imageData: nil,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Image only") {
    @Previewable @State var reps = 0
    let imageData = previewImageData(color: .systemBlue)
    SetCard(
        exerciseName: "Squats",
        setIndex: 0,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        notes: "",
        imageData: imageData,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
#Preview("Notes only") {
    @Previewable @State var reps = 0
    SetCard(
        exerciseName: "Squats",
        setIndex: 0,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        notes: "Keep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.",
        imageData: nil,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("With notes and image") {
    @Previewable @State var reps = 0
    let imageData = previewImageData(color: .systemBlue)
    SetCard(
        exerciseName: "Squats",
        setIndex: 0,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        notes: "Keep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.\nKeep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.\nKeep your chest up and knees tracking over your toes. Go to parallel or below. Breathe in on the way down, out on the way up.",
        imageData: imageData,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
