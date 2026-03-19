import SwiftUI
import SwiftData

// A shared in-memory ModelContainer for use in SwiftUI Previews.
// Call `previewContainer()` in a `#Preview` to get a configured container,
// then use `previewExercise(in:)` / `previewPlan(in:)` to insert sample objects.
@MainActor
func previewContainer() -> ModelContainer {
    let schema = Schema([Plan.self, Exercise.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: [config])
}

@MainActor
func previewPlan(in container: ModelContainer, name: String = "My Plan") -> Plan {
    let plan = Plan(name: name)
    container.mainContext.insert(plan)
    return plan
}

@MainActor
func previewExercise(
    in container: ModelContainer,
    plan: Plan? = nil,
    order: Double = 1.0,
    name: String = "Squats",
    sets: Int = 3,
    reps: Int = 12,
    durationSeconds: Int64? = nil,
    notes: String = "",
    imageData: Data? = nil
) -> Exercise {
    let exercise = Exercise(
        plan: plan,
        order: order,
        name: name,
        sets: sets,
        reps: reps,
        durationSeconds: durationSeconds,
        notes: notes,
        imageData: imageData
    )
    container.mainContext.insert(exercise)
    return exercise
}

/// Renders a solid-color JPEG as placeholder image data for previews.
func previewImageData(color: UIColor, size: CGSize = CGSize(width: 200, height: 200)) -> Data {
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
    return image.jpegData(compressionQuality: 0.8)!
}

/// A short two-exercise plan with images, useful for quickly reaching the completion screen.
@MainActor
func previewShortPlan(in container: ModelContainer) -> Plan {
    let plan = previewPlan(in: container, name: "Short Plan")
    _ = previewExercise(in: container, plan: plan, order: 1, name: "Push-ups", sets: 1, reps: 3,
                        imageData: previewImageData(color: .systemBlue))
    _ = previewExercise(in: container, plan: plan, order: 2, name: "Squats", sets: 1, reps: 3,
                        imageData: previewImageData(color: .systemOrange))
    return plan
}

/// A pre-built plan with several varied exercises, useful for list and full-screen previews.
@MainActor
func previewFullPlan(in container: ModelContainer) -> Plan {
    let plan = previewPlan(in: container)
    _ = previewExercise(in: container, plan: plan, order: 1, name: "Squats", sets: 3, reps: 12)
    _ = previewExercise(in: container, plan: plan, order: 2, name: "Push-ups", sets: 3, reps: 15)
    _ = previewExercise(in: container, plan: plan, order: 3, name: "Lunges", sets: 3, reps: 10, durationSeconds: 45)
    _ = previewExercise(in: container, plan: plan, order: 4, name: "Plank Hold", sets: 3, reps: 1, durationSeconds: 60)
    _ = previewExercise(in: container, plan: plan, order: 5, name: "", sets: 2, reps: 8)  // invalid — no name
    return plan
}
