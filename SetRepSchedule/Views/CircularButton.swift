import SwiftUI

struct CircularButton: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 36, height: 36)
            .background(Circle().fill(.regularMaterial))
    }
}
