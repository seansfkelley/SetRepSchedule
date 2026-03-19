import SwiftUI
import SwiftData

struct PlanMenuButton: View {
    @Query(sort: \Plan.name) private var plans: [Plan]
    var selectedPlanId: UUID?
    var currentPlanName: String
    var onSelectPlan: (Plan) -> Void
    var onCreateNewPlan: () -> Void
    var onDeletePlan: () -> Void

    private var deleteLabelText: String {
        let name = currentPlanName.isEmpty ? "This Plan" : currentPlanName
        return "Delete \"\(name)\""
    }

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
                Label(deleteLabelText, systemImage: "trash")
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 17, weight: .semibold))
                .padding(8)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}
