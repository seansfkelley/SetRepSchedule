import SwiftUI

struct SetCard: View {
    var exerciseName: String
    var setIndex: Int
    var totalSets: Int
    var reps: Int
    var durationSeconds: Int64?
    var imageData: Data?
    @Binding var completedReps: Int
    var onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(exerciseName.isEmpty ? "Exercise" : exerciseName)
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)
                Text("Set \(setIndex + 1) of \(totalSets)")
                    .foregroundStyle(.secondary)
            }
            .padding()

            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 0) {
                ProgressBar(value: Double(completedReps) / Double(max(1, reps)))
                    .frame(height: 4)

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
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(radius: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("No timer — mid-set") {
    @Previewable @State var reps = 3
    SetCard(
        exerciseName: "Squats",
        setIndex: 1,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        imageData: nil,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("With timer — idle") {
    @Previewable @State var reps = 0
    SetCard(
        exerciseName: "Plank Hold",
        setIndex: 0,
        totalSets: 3,
        reps: 1,
        durationSeconds: 60,
        imageData: nil,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Last set — last rep") {
    @Previewable @State var reps = 11
    SetCard(
        exerciseName: "Lunges",
        setIndex: 2,
        totalSets: 3,
        reps: 12,
        durationSeconds: nil,
        imageData: nil,
        completedReps: $reps,
        onAdvance: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
