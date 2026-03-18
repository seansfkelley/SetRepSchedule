import SwiftUI
import PhotosUI
import SwiftData

struct ImageButton: View {
    private let imageSize: CGFloat = 44

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
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .foregroundStyle(.secondary)
                    .frame(width: imageSize, height: imageSize)
                    .overlay {
                        Image(systemName: "camera")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .buttonStyle(.plain)
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

struct CameraImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImagePicked: (Data?) -> Void

        init(onImagePicked: @escaping (Data?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            onImagePicked(image?.jpegData(compressionQuality: 0.8))
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}

struct ImageViewSheet: View {
    @Bindable var exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotosPicker = false
    @State private var showCameraPicker = false
    @State private var photosPickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack {
                if let data = exercise.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                Spacer()
                VStack(spacing: 12) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take New Photo") {
                            showCameraPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    Button("Choose from Library") {
                        showPhotosPicker = true
                    }
                    .buttonStyle(.bordered)
                    Button("Remove", role: .destructive) {
                        exercise.imageData = nil
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    exercise.imageData = data
                }
                photosPickerItem = nil
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraImagePicker { data in
                if let data {
                    exercise.imageData = data
                }
                showCameraPicker = false
                dismiss()
            }
            .ignoresSafeArea()
        }
    }
}
#Preview("ImageButton — no image") {
    let container = previewContainer()
    let exercise = previewExercise(in: container)
    return ImageButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

#Preview("ImageButton — with image") {
    let container = previewContainer()
    // Draw a simple colored square as stand-in image data
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
    let imageData = renderer.jpegData(withCompressionQuality: 0.8) { ctx in
        UIColor.systemBlue.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    let exercise = previewExercise(in: container)
    exercise.imageData = imageData
    return ImageButton(exercise: exercise)
        .padding()
        .modelContainer(container)
}

