import SwiftUI
import SwiftData

enum AppMode {
    case planning
    case exercise
}

// A child view that owns a dynamically-filtered @Query for exercises in one plan.
// @Query predicates must be fixed at init time, so we pass the plan ID at init.
struct ExerciseListView: View {
    @Query private var exercises: [Exercise]
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedExerciseId: UUID?
    var plan: Plan
    var onPlayTapped: ([Exercise]) -> Void

    init(plan: Plan, onPlayTapped: @escaping ([Exercise]) -> Void) {
        self.plan = plan
        self.onPlayTapped = onPlayTapped
        let planId = plan.id
        _exercises = Query(
            filter: #Predicate<Exercise> { $0.plan?.id == planId },
            sort: \.order
        )
    }

    var hasInvalidExercises: Bool {
        exercises.contains { !$0.isValid }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
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
                            onDuplicate: { duplicateExercise(exercise) }
                        )
                        .listRowSeparator(.hidden)
                    }
                    .onMove(perform: moveExercises)
                    .onDelete(perform: deleteExercises)
                }
                .listStyle(.plain)
            }

            Button(action: addExercise) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.tint))
                    .shadow(radius: 4)
            }
            .padding(.leading, 20)
            .padding(.bottom, 20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    playTapped()
                } label: {
                    CircularButton(systemImage: hasInvalidExercises ? "play.slash.fill" : "play.fill")
                        .tint(.green)
                }
            }
        }
    }

    private func playTapped() {
        guard !exercises.isEmpty else { return }
        if hasInvalidExercises {
            // Jiggle is triggered via the ExerciseRow - no direct access here.
            // The play action is blocked; invalid exercises are visually indicated in the rows.
            return
        }
        onPlayTapped(exercises)
    }

    private func addExercise() {
        let order = (exercises.last?.order ?? 0) + 1.0
        let exercise = Exercise(plan: plan, order: order)
        modelContext.insert(exercise)
        focusedExerciseId = exercise.id
    }

    private func duplicateExercise(_ source: Exercise) {
        let sortedExercises = exercises  // already sorted by @Query
        guard let idx = sortedExercises.firstIndex(where: { $0.id == source.id }) else { return }
        let next = idx + 1 < sortedExercises.count ? sortedExercises[idx + 1] : nil
        let newOrder: Double
        if let next {
            let gap = next.order - source.order
            if gap < 1e-10 {
                renumberExercises(sortedExercises)
                // After renumber, recalculate based on updated values
                let updated = exercises
                if let s = updated.first(where: { $0.id == source.id }),
                   let n = updated.first(where: { $0.id == next.id }) {
                    newOrder = (s.order + n.order) / 2
                } else {
                    newOrder = source.order + 1.0
                }
            } else {
                newOrder = (source.order + next.order) / 2
            }
        } else {
            newOrder = source.order + 1.0
        }
        let copy = Exercise(
            plan: plan,
            order: newOrder,
            name: source.name,
            sets: source.sets,
            reps: source.reps,
            durationSeconds: source.durationSeconds,
            imageData: source.imageData
        )
        modelContext.insert(copy)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sortedExercises = exercises
        sortedExercises.move(fromOffsets: source, toOffset: destination)
        for (i, exercise) in sortedExercises.enumerated() {
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
    var plan: Plan
    @Binding var mode: AppMode
    @Binding var selectedPlanId: UUID?
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [Plan]
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ExerciseListView(plan: plan, onPlayTapped: { _ in
                mode = .exercise
            })
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TextField("Plan Name", text: Bindable(plan).name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                ToolbarItem(placement: .topBarLeading) {
                    PlanMenuButton(
                        selectedPlanId: selectedPlanId,
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
            .confirmationDialog("Delete \"\(plan.name)\"?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
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
        let newPlan = Plan(name: "New Plan")
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
