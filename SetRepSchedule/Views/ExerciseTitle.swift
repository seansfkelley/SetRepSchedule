import SwiftUI

// Adapted from
// https://stackoverflow.com/questions/78871854/how-can-i-utilise-minimum-scale-factor-before-defaulting-to-multiple-lines
struct ExerciseTitle: View {
    let name: String
    let fontSize: CGFloat = 32

    private let scaleFactor: CGFloat = 0.8

    @State private var oneLineHeight: CGFloat? = nil

    var body: some View {
        if !name.isEmpty {
            ZStack {
                // Measures the height of a single scaled line
                Text(name)
                    .font(.system(size: fontSize, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(scaleFactor)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) {
                        oneLineHeight = $0
                    }

                ViewThatFits(in: .horizontal) {
                    Text(name)
                        .font(.system(size: fontSize, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(scaleFactor)
                        .frame(height: oneLineHeight)

                    Text(name)
                        .font(.system(size: fontSize, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(scaleFactor)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, BaseCard.titleTopPadding)
            .padding(.horizontal, BaseCard.setCardInset)
            .padding(.bottom, BaseCard.titleBottomPadding)
        }
    }
}

#Preview("Exercise titles") {
    VStack(spacing: 24) {
        ExerciseTitle(name: "")
        ExerciseTitle(name: "Squats")
        ExerciseTitle(name: "Single-Leg Romanian Lift")
        ExerciseTitle(name: "Single-Leg Romanian Deadlift With Kettlebell")
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(.systemGroupedBackground))
}
