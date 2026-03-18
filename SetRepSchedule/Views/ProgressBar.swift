import SwiftUI

struct ProgressBar: View {
    var value: Double  // 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * max(0, min(1, value)))
            }
        }
    }
}
