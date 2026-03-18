import SwiftUI
import SwiftData

struct SetsRepsPopover: View {
    @Bindable var exercise: Exercise

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Sets")
                    .font(.body)
                    .fontWeight(.semibold)
                Picker("Sets", selection: $exercise.sets) {
                    ForEach(1...20, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
            }

            VStack(spacing: 0) {
                Text("×")
                    .font(.body)
                    .fontWeight(.semibold)
                Picker("×", selection: .constant(0)) {
                    Text("0").tag(0)
                }
                .pickerStyle(.wheel)
                .frame(width: 10)
                .hidden()
            }

            VStack(spacing: 0) {
                Text("Reps")
                    .font(.body)
                    .fontWeight(.semibold)
                Picker("Reps", selection: $exercise.reps) {
                    ForEach(1...50, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
            }
        }
        .padding()
        .presentationCompactAdaptation(.popover)
    }
}

struct SetsRepsButton: View {
    @Bindable var exercise: Exercise
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Text("\(exercise.sets) × \(exercise.reps)")
                .font(.subheadline.monospacedDigit())
        }
        .buttonStyle(.glass)
        .popover(isPresented: $showPopover) {
            SetsRepsPopover(exercise: exercise)
        }
    }
}

#Preview("SetsRepsButton") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, sets: 3, reps: 12)
    return SetsRepsButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

#Preview("SetsRepsPopover") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, sets: 4, reps: 8)
    return SetsRepsPopover(exercise: exercise)
        .modelContainer(container)
}
