import Foundation
import SwiftData

@Model
class Exercise {
    var id: UUID = UUID()
    var plan: Plan?
    var order: Double
    var name: String
    var sets: Int
    var reps: Int
    var durationSeconds: Int64?
    var notes: String = ""
    @Attribute(.externalStorage)
    var imageData: Data?

    init(plan: Plan? = nil, order: Double, name: String = "", sets: Int = 3, reps: Int = 10, durationSeconds: Int64? = nil, notes: String = "", imageData: Data? = nil) {
        self.plan = plan
        self.order = order
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.imageData = imageData
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty || imageData != nil
    }
}
