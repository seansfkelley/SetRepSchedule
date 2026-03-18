import SwiftUI
import SwiftData

enum AppMode {
    case planning
    case exercise
}

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @FocusState private var focusedExerciseId: UUID?
    var plan: Plan

    init(plan: Plan) {
        self.plan = plan
        let planId = plan.id
        _exercises = Query(
            filter: #Predicate<Exercise> { $0.plan?.id == planId },
            sort: \.order
        )
    }

    var body: some View {
        ZStack {
            if exercises.isEmpty {
                ContentUnavailableView {
                    Label("No Exercises", systemImage: "figure.walk")
                } description: {
                    Text("Add exercises to this plan.")
                } actions: {
                    Button("Add Exercise") {
                        addExercise()
                    }
                }
            } else {
                List {
                    ForEach(exercises) { exercise in
                        ExerciseRow(
                            exercise: exercise,
                            focusedExerciseId: $focusedExerciseId,
                        )
                    }
                    .onMove(perform: moveExercises)
                    .onDelete(perform: deleteExercises)
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onTapGesture {
            focusedExerciseId = nil
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            Button {
                addExercise()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(8)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    private func addExercise() {
        let order = (exercises.last?.order ?? 0) + 1.0
        let exercise = Exercise(plan: plan, order: order)
        modelContext.insert(exercise)
        let id = exercise.id
        Task { @MainActor in
            focusedExerciseId = id
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = exercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, exercise) in sorted.enumerated() {
            exercise.order = Double(i + 1)
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(exercises[idx])
        }
    }

    private func renumberExercises(_ list: [Exercise]) {
        for (i, exercise) in list.enumerated() {
            exercise.order = Double(i + 1)
        }
    }
}

struct PlanningView: View {
    @Bindable var plan: Plan
    @Binding var mode: AppMode
    @Binding var selectedPlanId: UUID?
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [Plan]
    @State private var showDeleteConfirmation = false

    private var hasInvalidExercises: Bool {
        plan.exercises.contains { !$0.isValid }
    }

    var body: some View {
        NavigationStack {
            ExerciseListView(plan: plan)
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            mode = .exercise
                        } label: {
                            Image(systemName: hasInvalidExercises ? "play.slash.fill" : "play.fill")
                        }
                        .tint(hasInvalidExercises ? .red : .green)
                        .disabled(hasInvalidExercises)
                    }
                    ToolbarItem(placement: .principal) {
                        TextField("Plan Name", text: $plan.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        PlanMenuButton(
                            selectedPlanId: selectedPlanId,
                            currentPlanName: plan.name,
                            onSelectPlan: { plan in
                                selectedPlanId = plan.id
                            },
                            onCreateNewPlan: createNewPlan,
                            onDeletePlan: {
                                if plan.exercises.isEmpty {
                                    deletePlan()
                                } else {
                                    showDeleteConfirmation = true
                                }
                            }
                        )
                    }
                }
                .alert("Delete \"\(plan.name)\"?", isPresented: $showDeleteConfirmation) {
                    Button("Delete Plan", role: .destructive) {
                        deletePlan()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all exercises in this plan.")
                }
        }
    }

    private func createNewPlan() {
        let newPlan = Plan(name: "Untitled Plan")
        modelContext.insert(newPlan)
        selectedPlanId = newPlan.id
    }

    private func deletePlan() {
        modelContext.delete(plan)
        // Try to select another plan
        let remaining = plans.filter { $0.id != plan.id }
        selectedPlanId = remaining.first?.id
    }
}

private struct PlanningViewPreview: View {
    var plan: Plan
    @State private var mode: AppMode = .planning
    @State private var selectedId: UUID?
    var body: some View {
        PlanningView(plan: plan, mode: $mode, selectedPlanId: $selectedId)
            .onAppear { selectedId = plan.id }
    }
}

#Preview("With exercises") {
    let container = previewContainer()
    let plan = previewFullPlan(in: container)
    return PlanningViewPreview(plan: plan)
        .modelContainer(container)
}

#Preview("Empty plan") {
    let container = previewContainer()
    let plan = previewPlan(in: container, name: "Morning Routine")
    return PlanningViewPreview(plan: plan)
        .modelContainer(container)
}
