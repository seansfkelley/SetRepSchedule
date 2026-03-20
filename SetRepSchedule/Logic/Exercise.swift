import Foundation
import SwiftData

@Model
class Exercise {
    var id: UUID = UUID()
    var plan: Plan?
    // Contiguous Int is basically the worst option for performance because it requires eagerly
    // renumbering on almost any mutation, but it's simple to implement and should reveal bugs
    // quickly. We won't really have more than a dozen rows being updated at a time.
    var order: Int
    var name: String
    var sets: Int
    var reps: Int
    var durationSeconds: Int64?
    var notes: String = ""
    var skipped: Bool = false
    @Attribute(.externalStorage)
    var imageData: Data?

    init(plan: Plan? = nil, order: Int, name: String = "", sets: Int = 3, reps: Int = 10, durationSeconds: Int64? = nil, notes: String = "", skipped: Bool = false, imageData: Data? = nil) {
        self.plan = plan
        self.order = order
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.skipped = skipped
        self.imageData = imageData
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty || imageData != nil
    }
}
