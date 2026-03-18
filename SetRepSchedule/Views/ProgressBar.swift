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

#Preview("Progress states") {
    VStack(spacing: 20) {
        VStack(alignment: .leading) {
            Text("Empty (0%)").font(.caption)
            ProgressBar(value: 0).frame(height: 6)
        }
        VStack(alignment: .leading) {
            Text("One third (33%)").font(.caption)
            ProgressBar(value: 0.33).frame(height: 6)
        }
        VStack(alignment: .leading) {
            Text("Two thirds (67%)").font(.caption)
            ProgressBar(value: 0.67).frame(height: 6)
        }
        VStack(alignment: .leading) {
            Text("Complete (100%)").font(.caption)
            ProgressBar(value: 1.0).frame(height: 6)
        }
    }
    .padding()
}
