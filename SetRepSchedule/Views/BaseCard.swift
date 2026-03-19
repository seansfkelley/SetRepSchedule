import SwiftUI
import SwiftData

// The base card of an exercise deck. Shows the exercise name, image, and notes
// in the upper portion, with a dotted placeholder zone in the lower third where
// set cards are stacked.
struct BaseCard: View {
    var exercise: Exercise

    // The bottom fraction of the card reserved for set cards.
    static let setZoneFraction: CGFloat = 0.33

    private let encouragements: [String] = [
        "Keep it up!", "You've got this!", "Stay steady.", "Nice and easy.",
        "Looking good!", "One rep at a time.", "You're doing great.", "Keep going!",
        "Almost there!", "Eyes on the goal.", "Great work!", "Breathe and focus.",
        "Every rep counts.", "You're making progress.", "Nice work!", "Slow and steady.",
        "Trust the process.", "Take it step by step.", "Stronger every day.", "You've got this!",
    ]

    @State private var shuffled: [String] = []
    @State private var phraseIndex: Int = 0
    @State private var phraseTimer: Timer?

    private var currentPhrase: String {
        shuffled.isEmpty ? "" : shuffled[phraseIndex]
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Upper portion: exercise content
                VStack(spacing: 12) {
                    if !exercise.name.isEmpty {
                        Text(exercise.name)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                    }

                    if exercise.imageData == nil && exercise.notes.isEmpty {
                        Spacer()
                        Text(currentPhrase)
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .id(phraseIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                if let data = exercise.imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .padding(.horizontal, 16)
                                }
                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .frame(height: geo.size.height * (1 - BaseCard.setZoneFraction))
                .padding(.top, 16)
                .padding(.horizontal, 16)

                // Lower third: dotted placeholder zone for set cards
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundStyle(.tertiary)
                        .padding(8)
                }
                .frame(height: geo.size.height * BaseCard.setZoneFraction)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            shuffled = encouragements.shuffled()
            guard exercise.imageData == nil && exercise.notes.isEmpty else { return }
            phraseTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
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

#Preview("Minimal") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    BaseCard(exercise: exercise)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("With image") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Push-ups", sets: 3, reps: 15,
                                   imageData: previewImageData(color: .systemBlue))
    BaseCard(exercise: exercise)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("With notes") {
    let container = previewContainer()
    let exercise = previewExercise(
        in: container,
        name: "Lunges",
        sets: 3,
        reps: 10,
        notes: "Keep your front knee over your ankle. Step far enough forward that your back knee nearly touches the ground."
    )
    BaseCard(exercise: exercise)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("With image and notes") {
    let container = previewContainer()
    let exercise = previewExercise(
        in: container,
        name: "Squats",
        sets: 3,
        reps: 12,
        notes: "Keep your chest up and knees tracking over your toes. Go to parallel or below.",
        imageData: previewImageData(color: .systemOrange)
    )
    BaseCard(exercise: exercise)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
