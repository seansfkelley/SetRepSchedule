import SwiftUI
import SwiftData

struct DurationPopover: View {
    @Bindable var exercise: Exercise
    @Binding var isPresented: Bool
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Duration")
                .font(.headline)
            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)

                Text(":")
                    .font(.title2)
                    .padding(.horizontal, 4)

                Picker("Seconds", selection: $seconds) {
                    ForEach(0..<60) { i in
                        Text(String(format: "%02d", i)).tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
            }
            Button("Clear", role: .destructive) {
                exercise.durationSeconds = nil
                isPresented = false
            }
        }
        .padding()
        .presentationCompactAdaptation(.popover)
        .onAppear {
            let total = exercise.durationSeconds ?? 0
            minutes = Int(total / 60)
            seconds = Int(total % 60)
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                let total = Int64(minutes * 60 + seconds)
                exercise.durationSeconds = total == 0 ? nil : total
            }
        }
    }
}

struct DurationButton: View {
    @Bindable var exercise: Exercise
    @State private var showPopover = false

    private var durationLabel: String? {
        guard let d = exercise.durationSeconds, d > 0 else { return nil }
        let m = Int(d / 60)
        let s = Int(d % 60)
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        Button {
            showPopover = true
        } label: {
            if let label = durationLabel {
                Text(label)
                    .font(.subheadline.monospacedDigit())
            } else {
                Image(systemName: "clock")
            }
        }
        .buttonStyle(.glass)
        .popover(isPresented: $showPopover) {
            DurationPopover(exercise: exercise, isPresented: $showPopover)
        }
    }
}

#Preview("DurationButton — unset") {
    let container = previewContainer()
    let exercise = previewExercise(in: container)
    return DurationButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

#Preview("DurationButton — 1:30") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, durationSeconds: 90)
    return DurationButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

#Preview("DurationPopover — pre-filled") {
    @Previewable @State var isPresented = true
    let container = previewContainer()
    let exercise = previewExercise(in: container, durationSeconds: 75)
    return DurationPopover(exercise: exercise, isPresented: $isPresented)
        .modelContainer(container)
}
