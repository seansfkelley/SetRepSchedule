import Foundation
import SwiftData

@Model
class Plan {
    var id: UUID = UUID()
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Exercise.plan)
    var exercises: [Exercise] = []

    init(name: String) {
        self.name = name
    }
}
