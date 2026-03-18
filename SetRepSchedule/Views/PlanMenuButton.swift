import SwiftUI
import SwiftData

struct PlanMenuButton: View {
    @Query private var plans: [Plan]
    var selectedPlanId: UUID?
    var onSelectPlan: (Plan) -> Void
    var onCreateNewPlan: () -> Void
    var onDeletePlan: () -> Void

    var body: some View {
        Menu {
            ForEach(plans) { plan in
                Button(plan.name.isEmpty ? "Unnamed Plan" : plan.name) {
                    onSelectPlan(plan)
                }
            }
            Divider()
            Button {
                onCreateNewPlan()
            } label: {
                Label("New Plan", systemImage: "plus")
            }
            Divider()
            Button(role: .destructive) {
                onDeletePlan()
            } label: {
                Label("Delete this Plan", systemImage: "trash")
            }
        } label: {
            CircularButton(systemImage: "list.bullet")
        }
    }
}
