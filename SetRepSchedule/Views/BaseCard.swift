import SwiftUI
import SwiftData

// The base card of an exercise deck. Shows the exercise name, image, and notes
// in the upper portion, with a dotted placeholder zone at the bottom sized to
// exactly fit a SetCard (measured by rendering an invisible one).
struct BaseCard: View {
    public static let setCardInset: CGFloat = 12

    var exercise: Exercise

    private let fadeLength: CGFloat = 20

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
        VStack(spacing: 0) {
            // Title: always visible at top, outside the scroll area
            if !exercise.name.isEmpty {
                Text(exercise.name)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, fadeLength * 3 / 2)
                    .padding(.horizontal, Self.setCardInset)
                    .padding(.bottom, fadeLength / 2)
            }

            // Body area: centers if content fits, scrolls if it doesn't
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
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            if !exercise.notes.isEmpty {
                                Text(exercise.notes)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, Self.setCardInset)
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
                .animation(.easeInOut(duration: 0.4), value: phraseIndex)
            }

            // Dotted zone: hidden SetCard (with matching inset) drives the height.
            // The overlay fills exactly that padded area, so the border hugs the card edge.
            SetCard(
                exercise: exercise,
                setIndex: 0,
                completedReps: .constant(0),
                onAdvance: {}
            )
            .hidden()
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(.tertiary)
                    .padding(Self.setCardInset)

                Text("^[\(exercise.sets) set](inflect: true) complete!")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
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
        notes: "Keep your chest up and knees tracking over your toes. Go to parallel or below.\nKeep your chest up and knees tracking over your toes. Go to parallel or below.\nKeep your chest up and knees tracking over your toes. Go to parallel or below.\nKeep your chest up and knees tracking over your toes. Go to parallel or below.",
        imageData: previewImageData(color: .systemOrange)
    )
    BaseCard(exercise: exercise)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
