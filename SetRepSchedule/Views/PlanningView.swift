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
        Group {
            if exercises.isEmpty {
                ContentUnavailableView {
                    Label("No Exercises", systemImage: "figure.walk")
                } description: {
                    Text("Add exercises to this plan.")
                } actions: {
                    Button("Add Exercise") {
                        addExerciseToEnd()
                    }
                }
            } else {
                List {
                    ForEach(exercises) { exercise in
                        ExerciseRow(
                            exercise: exercise,
                            focusedExerciseId: $focusedExerciseId,
                            onDuplicate: { duplicateExercise(exercise) }
                        )
                    }
                    .onMove(perform: moveExercises)
                    .onDelete(perform: deleteExercises)
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onTapGesture {
            focusedExerciseId = nil
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            Button {
                addExerciseToEnd()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(8)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .padding(.trailing)
            .padding(.bottom)
        }
    }

    private func duplicateExercise(_ exercise: Exercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let copy = Exercise(
            plan: exercise.plan,
            order: 0,
            name: exercise.name,
            sets: exercise.sets,
            reps: exercise.reps,
            durationSeconds: exercise.durationSeconds,
            notes: exercise.notes,
            imageData: exercise.imageData
        )
        withAnimation {
            modelContext.insert(copy)
            // exercises is sorted by order; insert copy right after the original and renumber.
            var sorted = Array(exercises)
            sorted.insert(copy, at: index + 1)
            for (i, ex) in sorted.enumerated() {
                ex.order = i + 1
            }
            try? modelContext.save()
        }
    }

    private func addExerciseToEnd() {
        let order = (exercises.last?.order ?? 0) + 1
        let exercise = Exercise(plan: plan, order: order)
        modelContext.insert(exercise)
        try? modelContext.save()
        focusedExerciseId = exercise.id
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = exercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, exercise) in sorted.enumerated() {
            exercise.order = i + 1
        }
        try? modelContext.save()
    }

    private func deleteExercises(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(exercises[idx])
        }
        try? modelContext.save()
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
            .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            mode = .exercise
                        } label: {
                            Label("Start", systemImage: hasInvalidExercises ? "play.slash.fill" : "play.fill")
                                .labelStyle(.iconOnly)
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
                            onSelectPlan: { selectedPlanId = $0.id },
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
        try? modelContext.save()
        selectedPlanId = newPlan.id
    }

    private func deletePlan() {
        modelContext.delete(plan)
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
