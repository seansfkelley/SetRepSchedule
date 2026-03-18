import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [Plan]
    @AppStorage("selectedPlanId") private var selectedPlanIdString: String = ""
    @AppStorage("hasSeededDefaultPlan") private var hasSeededDefaultPlan: Bool = false
    @State private var mode: AppMode = .planning

    private var selectedPlanId: UUID? {
        get { UUID(uuidString: selectedPlanIdString) }
    }

    private func setSelectedPlanId(_ id: UUID?) {
        selectedPlanIdString = id?.uuidString ?? ""
    }

    private var selectedPlan: Plan? {
        guard let id = selectedPlanId else { return nil }
        return plans.first { $0.id == id }
    }

    var body: some View {
        Group {
            if plans.isEmpty {
                ContentUnavailableView {
                    Label("No Plans", systemImage: "list.bullet.clipboard")
                } description: {
                    Text("Create a plan to get started.")
                } actions: {
                    Button("New Plan") {
                        createDefaultEmptyPlan()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let plan = selectedPlan {
                switch mode {
                case .planning:
                    PlanningView(
                        plan: plan,
                        mode: $mode,
                        selectedPlanId: Binding(
                            get: { selectedPlanId },
                            set: { setSelectedPlanId($0) }
                        )
                    )
                case .exercise:
                    let exercises = plan.exercises.sorted { $0.order < $1.order }
                    ExerciseView(exercises: exercises, mode: $mode)
                }
            } else {
                // selectedPlanId is set but points to a deleted plan — pick the first available
                ContentUnavailableView {
                    Label("Select a Plan", systemImage: "list.bullet")
                } description: {
                    Text("Choose a plan from the menu.")
                }
                .onAppear {
                    setSelectedPlanId(plans.first?.id)
                }
            }
        }
        .onAppear {
            seedDefaultPlanIfNeeded()
            // If no plan is selected, select the first one
            if selectedPlan == nil, let first = plans.first {
                setSelectedPlanId(first.id)
            }
        }
        .onChange(of: plans) { _, newPlans in
            // If the selected plan no longer exists in the updated list, pick the first available
            let selectionStillExists = newPlans.contains { $0.id == selectedPlanId }
            if !selectionStillExists {
                setSelectedPlanId(newPlans.first?.id)
                if mode == .exercise {
                    mode = .planning
                }
            }
        }
    }

    private func seedDefaultPlanIfNeeded() {
        guard !hasSeededDefaultPlan else { return }
        hasSeededDefaultPlan = true

        let plan = Plan(name: "My Plan")
        modelContext.insert(plan)

        let defaultExercises: [(String, Int, Int)] = [
            ("Squats", 3, 12),
            ("Push-ups", 3, 15),
            ("Lunges", 3, 10),
            ("Plank Hold", 3, 1),
            ("Glute Bridges", 3, 15),
        ]
        for (i, (name, sets, reps)) in defaultExercises.enumerated() {
            let exercise = Exercise(plan: plan, order: Double(i + 1), name: name, sets: sets, reps: reps)
            modelContext.insert(exercise)
        }

        setSelectedPlanId(plan.id)
    }

    private func createDefaultEmptyPlan() {
        let plan = Plan(name: "Untitled Plan")
        modelContext.insert(plan)
        setSelectedPlanId(plan.id)
    }
}
