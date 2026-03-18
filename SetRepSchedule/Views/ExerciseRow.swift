import SwiftUI
import SwiftData
import PhotosUI

struct ExerciseRow: View {
    @Bindable var exercise: Exercise
    var focusedExerciseId: FocusState<UUID?>.Binding
    var onDuplicate: () -> Void
    @State private var showInvalidPopover = false
    @State private var jiggle = false

    var body: some View {
        HStack(spacing: 0) {
            // Col 1: warning icon (only when invalid)
            if !exercise.isValid {
                Button {
                    showInvalidPopover = true
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .frame(width: 32)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInvalidPopover) {
                    Text("A name or picture is required.")
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }

            // Col 2: name + set/rep/duration controls
            VStack(alignment: .leading, spacing: 0) {
                TextField("Exercise name", text: $exercise.name)
                    .focused(focusedExerciseId, equals: exercise.id)
                    .onChange(of: exercise.name) { _, newValue in
                        let trimmed = String(newValue.drop(while: { $0.isWhitespace }))
                        if trimmed != newValue {
                            exercise.name = trimmed
                        }
                    }
                    .rotationEffect(.degrees(jiggle ? 2 : 0))
                    .animation(
                        jiggle ? .easeInOut(duration: 0.08).repeatCount(4, autoreverses: true) : .default,
                        value: jiggle
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                Divider()

                // Sets/reps and duration buttons, edge-to-edge in their row
                HStack(spacing: 0) {
                    SetsRepsButton(exercise: exercise)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    DurationButton(exercise: exercise)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 36)
                .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity)

            // Col 3: duplicate
            Divider()
            Button {
                onDuplicate()
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 44)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Col 4: camera
            Divider()
            ImageColumn(exercise: exercise)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    func triggerJiggle() {
        jiggle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            jiggle = false
        }
    }
}

// Extracted so the confirmation dialog / sheets attach cleanly to a contained view
private struct ImageColumn: View {
    @Bindable var exercise: Exercise
    @State private var showConfirmationDialog = false
    @State private var showPhotosPicker = false
    @State private var showCameraPicker = false
    @State private var showImageSheet = false
    @State private var photosPickerItem: PhotosPickerItem?

    var body: some View {
        Button {
            if exercise.imageData != nil {
                showImageSheet = true
            } else if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showConfirmationDialog = true
            } else {
                showPhotosPicker = true
            }
        } label: {
            if let data = exercise.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .frame(width: 44)
                    .frame(maxHeight: .infinity)
            } else {
                Image(systemName: "camera.fill")
                    .frame(width: 44)
                    .frame(maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .confirmationDialog("Add Photo", isPresented: $showConfirmationDialog) {
            Button("Take Photo") { showCameraPicker = true }
            Button("Choose from Library") { showPhotosPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    exercise.imageData = data
                }
                photosPickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraImagePicker { data in
                if let data { exercise.imageData = data }
                showCameraPicker = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showImageSheet) {
            ImageViewSheet(exercise: exercise)
        }
    }
}

// Preview wrapper — owns the @FocusState that ExerciseRow requires.
private struct ExerciseRowPreviewWrapper: View {
    var exercise: Exercise
    @FocusState private var focused: UUID?
    var body: some View {
        ExerciseRow(exercise: exercise, focusedExerciseId: $focused, onDuplicate: {})
    }
}

#Preview("Valid exercise") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Squats", sets: 3, reps: 12)
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
            .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
    .modelContainer(container)
}

#Preview("With timer") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
            .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
    .modelContainer(container)
}

#Preview("Invalid — no name") {
    let container = previewContainer()
    let exercise = previewExercise(in: container, name: "")
    return List {
        ExerciseRowPreviewWrapper(exercise: exercise)
            .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
    .modelContainer(container)
}

#Preview("Full plan list") {
    let container = previewContainer()
    let plan = previewFullPlan(in: container)
    let exercises = plan.exercises.sorted { $0.order < $1.order }
    return List {
        ForEach(exercises) { ex in
            ExerciseRowPreviewWrapper(exercise: ex)
                .listRowInsets(EdgeInsets())
        }
    }
    .listStyle(.plain)
    .modelContainer(container)
}
