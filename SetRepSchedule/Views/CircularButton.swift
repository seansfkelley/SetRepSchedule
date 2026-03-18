import SwiftUI

struct CircularButton: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(8)
    }
}

extension View {
    func circularGlassButton() -> some View {
        self
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
    }
}

#Preview("Various icons") {
    HStack(spacing: 16) {
        CircularButton(systemImage: "list.bullet")
        CircularButton(systemImage: "play.fill")
            .tint(.green)
        CircularButton(systemImage: "chevron.left")
        CircularButton(systemImage: "play.slash.fill")
    }
    .padding()
}
