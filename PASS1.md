# Pass 1 Implementation Plan

This document details the implementation of Pass 1 as described in [DESIGN.md](DESIGN.md). Pass 1 covers everything in the design except cycles. The result is a fully functional app for flat (non-cycled) exercise schedules.

## Scope

Pass 1 includes:

- The full data model for plans and exercises (no cycle type)
- Planning mode: list view, exercise item editing, plan management
- Exercise mode: flat schedule walkthrough, set cards, timers, completion stats
- Persistence via SwiftData

Cycles, the per-rep card type, and cross-level drag interactions are deferred to Pass 2.

---

## Data Model

### `Plan` (SwiftData `@Model`)

```swift
@Model
class Plan {
    var id: UUID = UUID()
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Exercise.plan)
    var exercises: [Exercise] = []
}
```

Deleting a `Plan` cascades to all its exercises automatically.

### `Exercise` (SwiftData `@Model`)

```swift
@Model
class Exercise {
    var id: UUID = UUID()
    var plan: Plan?
    var order: Double                 // sort key; unique within a plan
    var name: String                  // may be empty
    var sets: Int                     // >= 1
    var reps: Int                     // >= 1
    var durationSeconds: Int64?        // nil means no timer; seconds only
    @Attribute(.externalStorage)
    var imageData: Data?              // stored outside SQLite
}
```

`Exercise` is a `@Model` so that `imageData` can carry `@Attribute(.externalStorage)` directly, keeping image blobs out of the SQLite store without any indirection. Ordering is an explicit `Int` rank — see the section below.

Duration is stored as `Int64?` (seconds). `Swift.Duration` is not a SwiftData-supported primitive type and cannot be stored directly. At the UI boundary, convert: `minutes = Int(durationSeconds / 60)`, `seconds = Int(durationSeconds % 60)`, and on commit: `durationSeconds = Int64(minutes * 60 + seconds)`.

### Ordering

Exercises are sorted ascending by `order`, a `Double`. Values are not required to be contiguous — only distinct. This means most insertions and moves are a single write.

**Fetching in order:**

```swift
@Query(sort: \Exercise.order) private var exercises: [Exercise]
```

Or, scoped to the selected plan via a predicate.

**Appending** (new exercise or duplicate at end): assign `(last.order + 1)`, or `1.0` if the plan is empty.

**Inserting between two exercises**: assign the midpoint of their `order` values — unless a renumber is required (see below):

```swift
exercise.order = (predecessor.order + successor.order) / 2
```

**Moving** is the same operation: compute the midpoint of the new neighbors and assign it. One write, no other exercises touched — unless a renumber is required (see below).

**Renumbering**: before computing a midpoint, check whether the gap between the two neighbors is less than `1e-10`. If so, reassign the entire plan's exercises evenly-spaced values (`1.0, 2.0, 3.0, ...`) first, then compute the midpoint using the updated values.

### Validity

An exercise is **valid** if the name contains at least one non-whitespace character, or `imageData != nil`. Validity is a computed property, not stored state.

The name field trims leading whitespace on every keystroke. On unfocus, the full value is trimmed of both leading and trailing whitespace.

### Default Plan

On first launch (no plans exist in the store), insert one `Plan` with a default name (e.g. "My Plan") and several pre-populated exercises. No cycles. This demonstrates the feature set without being overwhelming.

---

## App Structure

```
SetRepScheduleApp
└── ContentView              // root, holds selected plan
    ├── PlanningView         // planning mode
    │   ├── ExerciseRow      // one exercise in the list
    │   │   ├── SetsRepsButton + SetsRepsPopover
    │   │   ├── DurationButton + DurationPopover
    │   │   └── ImageButton + ImageSheet
    │   ├── PlanMenuButton   // top-left plan switcher
    │   └── PlayButton       // top-right, transitions to exercise mode
    └── ExerciseView         // exercise mode
        ├── SetCard          // one card per set
        └── CompletionView   // end-of-exercise stats
```

All navigation between planning and exercise mode is state-driven, not via `NavigationStack` pushes. The design requires a two-tap confirmation to exit exercise mode, and `NavigationStack` provides a system swipe-back gesture that cannot be cleanly disabled without reaching into `UINavigationController`. State-driven switching avoids that entirely.

`ContentView` is the single root view and owns:

- `@State var mode: AppMode` — `.planning` or `.exercise`
- `@State var selectedPlanId: UUID?` — persisted to `UserDefaults` (via `@AppStorage`)

It decides which view to display:

- If there are no plans and the plan picker has no selection: `ContentUnavailableView` with a "New Plan" button
- If `mode == .planning`: `PlanningView`, receiving `selectedPlanId` and a binding to `mode`
- If `mode == .exercise`: `ExerciseView`, receiving the selected plan's exercises and a binding to `mode`

`PlanningView` does not own `selectedPlanId` — it receives it from `ContentView`. Keeping this state in `ContentView` ensures that the selected plan ID is available to both planning and exercise mode without prop-drilling through an intermediate owner.

---

## Planning Mode

### PlanningView

Receives `selectedPlanId: UUID?` and `mode: Binding<AppMode>` from `ContentView`. Owns:

```swift
@Query private var plans: [Plan]
```

`@Query` predicates must be fixed at view init time. To scope exercises to the selected plan, pass `selectedPlanId` as an init parameter to a child view (e.g. `ExerciseListView`) that owns its own `@Query(filter:sort:)` initialized with that ID. This is the standard SwiftData pattern for dynamic predicates — do not attempt to mutate a `@Query` predicate after initialization.

Layout:

- `NavigationStack` (for title area) or a plain `ZStack` with a custom toolbar. A `NavigationStack` is the simpler choice; use `.navigationTitle` binding for the inline-editable title.
- The list of exercises rendered with `List` + `ForEach`.
- `.onMove` modifier on the `ForEach` for drag reordering.
- `.onDelete` (swipe-to-delete) on the `ForEach`.
- Floating `+` button overlaid at bottom-left using `ZStack` or `.overlay`.

#### Inline-editable plan title

Place a `TextField` in the `.principal` toolbar slot, styled to match the navigation title appearance:

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        TextField("Plan Name", text: $plan.name)
            .font(.headline)
            .multilineTextAlignment(.center)
    }
}
```

Tap to activate, keyboard dismiss to commit. The plan menu and play buttons go in separate `.topBarLeading` and `.topBarTrailing` toolbar items.

#### Zero state

When `plan.exercises.isEmpty`, show a `ContentUnavailableView` with an appropriate label and a button action to add the first exercise.

#### Plus button

Floating circular button, bottom-left, `z`-stacked above the list:

```swift
Button(action: addExercise) {
    Image(systemName: "plus")
        .frame(width: 56, height: 56)
        .background(Circle().fill(.tint))
        .foregroundStyle(.white)
}
```

`addExercise` appends a new `Exercise` with default values (e.g. sets: 3, reps: 10) to the plan, then sets `focusedExerciseId = newExercise.id` to move the keyboard to that row immediately.

`PlanningView` owns `@FocusState private var focusedExerciseId: Exercise.ID?`. Pass the projected value (`$focusedExerciseId`, of type `FocusState<Exercise.ID?>.Binding`) into each `ExerciseRow` as a parameter — passing the `@FocusState` property directly (not its projection) causes a compile error. Each `ExerciseRow` name field is annotated with `.focused(focusedExerciseId, equals: exercise.id)`. Setting `focusedExerciseId` programmatically on `PlanningView` causes SwiftUI to move focus to the matching field.

### ExerciseRow

Receives an `Exercise` reference. To bind SwiftUI controls to its properties, declare it with `@Bindable var exercise: Exercise` (iOS 17+), which lets you write `$exercise.name`, `$exercise.sets`, etc. directly without an explicit `Binding`. Layout is a horizontal stack:

```
[InvalidWarning?] [NameField] [SetsRepsButton] [DurationButton] [ImageButton] [DuplicateButton]
```

All buttons open popovers or sheets anchored to themselves.

#### Name field

```swift
TextField("Exercise name", text: $exercise.name)
    .focused($focusedExerciseId, equals: exercise.id)
```

No border; relies on the tap target and cursor appearance to communicate editability.

#### Invalid warning icon

```swift
if !exercise.isValid {
    Button {
        showInvalidPopover = true
    } label: {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
    }
    .popover(isPresented: $showInvalidPopover) {
        Text("A name or picture is required.")
            .padding()
    }
}
```

#### SetsRepsButton

Displays `"\(exercise.sets) x \(exercise.reps)"` as the label with subtitle `"Sets x Reps"`. Tapping presents a popover with two `Stepper` rows, one labeled "Sets" and one labeled "Reps", each constrained to strictly positive integers.

The popover commits on dismiss (tap outside). Since `Exercise` is a `@Model` reference type, changes are reflected immediately in the button preview without needing a binding.

```swift
.popover(isPresented: $showSetsRepsPopover) {
    VStack {
        Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...Int.max)
        Stepper("Reps: \(exercise.reps)", value: $exercise.reps, in: 1...Int.max)
    }
    .padding()
    .presentationCompactAdaptation(.popover)
}
```

`presentationCompactAdaptation(.popover)` ensures it stays as a popover rather than a sheet on compact size classes.

#### DurationButton

Shows a clock icon when unset, or `"M:SS"` when set. Opens a popover with two `Picker` wheels (minutes 0–59, seconds 0–59) styled `.wheel`. Includes a "Clear" button that sets `exercise.durationSeconds = nil`.

The popover owns local `@State var minutes: Int` and `@State var seconds: Int`. On `.onAppear`, initialize from `exercise.durationSeconds`: `minutes = Int((durationSeconds ?? 0) / 60)`, `seconds = Int((durationSeconds ?? 0) % 60)`. Commit back using `.onChange(of: isPresented) { if !isPresented { exercise.durationSeconds = Int64(minutes * 60 + seconds) } }` — `.onDisappear` is not reliably fired when a popover is dismissed by tapping outside on iOS.

```swift
Picker("Minutes", selection: $minutes) {
    ForEach(0..<60) { Text("\($0)").tag($0) }
}
.pickerStyle(.wheel)
.frame(width: 80)
```

#### ImageButton

Shows `camera.fill` icon when no image is set, or a small thumbnail (`Image(...).resizable().scaledToFill()` clipped to a small rounded square) when set.

**When no image is set**, tapping presents a `confirmationDialog` with two actions: "Take Photo" and "Choose from Library". "Choose from Library" uses `PhotosPicker` (PhotosUI, SwiftUI-native). "Take Photo" uses `UIImagePickerController` with `sourceType = .camera` wrapped in a `UIViewControllerRepresentable`. `UIImagePickerController` is deprecated as of iOS 16 for photo library access, but it remains the only practical option for camera capture — there is no SwiftUI-native camera API. If the camera is unavailable (e.g. simulator), skip the dialog and go straight to `PhotosPicker`.

**When an image is set**, tapping opens a sheet showing the full image with three buttons: "Take New Photo", "Choose from Library", and "Remove". The first two work identically to the no-image case and replace the existing image. "Remove" sets `exercise.imageData = nil`. All three dismiss the sheet.

#### DuplicateButton

Icon: `doc.on.doc`. Action: insert a copy of this exercise after it in the plan's exercise array. The copy gets a new `id`. Assign `order` using the same midpoint logic as an insert: midpoint between this exercise and the next, or `this.order + 1.0` if there is no next exercise. Apply the same renumber fallback if the gap is less than `1e-10`.

#### Reordering

Add `.onMove` to the `ForEach`. Do not force `editMode` active — when active, SwiftUI repurposes row taps for selection, which would break all interactive controls inside `ExerciseRow`. With `editMode` inactive, `onMove` still works: reordering is initiated with a long press on a row. No persistent drag handle is shown, which is an acceptable tradeoff to keep rows fully interactive.

Note: the long-press-to-drag gesture lives on the row, while button taps (popovers, confirmationDialog) live on individual controls. UIKit's gesture system should give button taps priority, but verify during implementation that there is no conflict between the drag gesture and the image button's confirmationDialog or other popovers.

Fallback if long-press drag does not work without `editMode` active: set `editMode` to `.active` programmatically when a long press is detected on any row, and immediately set it back to `.inactive` after the drop completes. This preserves the interactive controls during normal use while activating the full drag machinery on demand.

```swift
ForEach(exercises) { exercise in   // exercises from @Query(sort: \Exercise.order)
    ExerciseRow(exercise: exercise, ...)
}
.onMove(perform: move)
.onDelete(perform: delete)
```

### PlanMenuButton

Top-left circular button with `list.bullet` icon. Tapping presents a `Menu`:

```swift
Menu {
    ForEach(plans) { plan in
        Button(plan.name) { selectPlan(plan) }
    }
    Divider()
    Button { createNewPlan() } label: {
        Label("New Plan", systemImage: "plus")
    }
    Divider()
    Button(role: .destructive) { confirmDeletePlan() } label: {
        Label("Delete this Plan", systemImage: "trash")
    }
} label: {
    CircularButton(systemImage: "list.bullet")
}
```

Delete confirmation is handled with `.confirmationDialog` when the plan is non-empty.

If all plans are deleted, `selectedPlanId` becomes invalid. `ContentView` detects this (e.g. via `.onChange(of: plans)` or by checking whether the ID still maps to a known plan) and renders `ContentUnavailableView` with a "New Plan" action instead of `PlanningView`.

### PlayButton

Top-right circular button with `play.fill`, tinted `.green` via `.tint(.green)`. Do not use SwiftUI's `disabled()` modifier — disabled buttons have inconsistent tap-through behavior across iOS versions. Instead, always allow the tap and check conditions inside the action handler:

- If `plan.exercises.isEmpty`, do nothing.
- If any exercises are invalid, jiggle them and scroll them into view. Implement jiggle as a brief rotation animation triggered by a state toggle.
- Otherwise, set `mode = .exercise`.

Use `play.slash.fill` as the icon when the plan has invalid exercises.

---

## Exercise Mode

### ExerciseView

Receives the plan's sorted `[Exercise]` array directly — no flattening step. Owns:

- `exerciseIndex: Int` — index into the exercises array
- `setIndex: Int` — current set within the current exercise (0-based)
- `completedReps: [Exercise.ID: [Int]]` — per-exercise array of completed rep counts, one entry per set, for the completion summary
- `isConfirmingExit: Bool`

The current position is fully described by `(exerciseIndex, setIndex)`. Advancing past the last set of an exercise increments `exerciseIndex` and resets `setIndex` to 0. When `exerciseIndex >= exercises.count`, show `CompletionView`.

`ExerciseView` derives a `Binding<Int>` for the current set's rep count from `completedReps` and passes it to `SetCard`:

```swift
var currentRepBinding: Binding<Int> {
    let id = exercises[exerciseIndex].id
    return Binding(
        get: { self.completedReps[id, default: []].last ?? 0 },
        set: { newValue in
            var counts = self.completedReps[id, default: []]
            if counts.isEmpty { counts.append(0) }
            counts[counts.count - 1] = newValue
            self.completedReps[id] = counts
        }
    )
}
```

`SetCard` receives this binding and reads/writes the rep count through it. All mutations to `completedReps` happen on the main actor (SwiftUI state is always main-actor-bound), so no additional synchronization is needed.

Renders a `ZStack`:
- Background: solid color or subtle gradient
- Foreground: `SetCard` for the current exercise/set, offset and animated on swipe

`ExerciseView` owns the card's horizontal offset and drives the dismissal animation. When a card is dismissed — either by completing the final rep or by manual swipe — it flies off to the left with a rotation proportional to its horizontal offset, so it tumbles slightly as it exits, like a physical card being flicked away (a few degrees at full dismissal). The next card enters straight with no rotation. When a rightward swipe bounces back, the rotation reverses to zero along with the offset.

#### Exit button behavior

Top-left: initially a circular `chevron.left` button. On first tap, sets `isConfirmingExit = true`, transforming it into a text button saying "End Exercises". On second tap, exits.

### SetCard

A rounded-rectangle card, nearly full-screen width. Contains:

```swift
VStack(spacing: 0) {
    // Header area
    VStack {
        Text(set.exerciseName).font(.title).bold()
        Text("Set \(set.setIndex + 1) of \(set.totalSets)").foregroundStyle(.secondary)
    }
    .padding()

    // Image (if any)
    if let data = set.imageData, let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 300)
    }

    Spacer()

    // Progress bar + action button
    VStack(spacing: 0) {
        ProgressBar(value: Double(completedReps) / Double(set.reps))
            .frame(height: 4)
        ActionButton(set: set, completedReps: $completedReps, timerState: $timerState) {
            onRepCompleted()
        }
    }
}
.background(RoundedRectangle(cornerRadius: 20).fill(.background))
.shadow(radius: 8)
```

#### ActionButton states (no duration)

Button tinted `.green`. Label logic:

```swift
var label: String {
    if completedReps == set.reps - 1 {
        if set.setIndex == set.totalSets - 1 {
            return "Complete Exercise"
        } else {
            return "Complete Set \(set.setIndex + 1) of \(set.totalSets)"
        }
    } else {
        return "Complete Rep \(completedReps + 1) of \(set.reps)"
    }
}
```

Tapping increments `completedReps`. When `completedReps == set.reps`, trigger card advance.

#### ActionButton states (with duration)

Three sub-states:

1. **Idle**: shows "Start Timer (M:SS)". Background is neutral. Tap → start countdown, switch to state 2.
2. **Counting**: shows a countdown with clock icon. Background is neutral. Tap before expiry → flash `.red` briefly, then count the rep (advance to state 1 for next rep, or advance card if last rep).
3. **Expired**: timer finished naturally. Button tinted `.green`, shows "Complete Rep X of Y". Tap → count rep.

Implement with a `@State var timerState: TimerState` enum, a `@State var endDate: Date?`, and a `@State var remainingSeconds: Int64`. When the timer starts, set `endDate = Date.now.addingTimeInterval(Double(exercise.durationSeconds!))` and switch to `.counting`. Use `Timer.publish(every: 1, on: .main, in: .common).autoconnect()` with `.onReceive` to tick every second, updating `remainingSeconds = max(0, Int64(endDate.timeIntervalSinceNow))` and transitioning to `.expired` when it reaches zero. `.onReceive` stops automatically when the view disappears, so no explicit cancellation is needed.

#### Swipe to advance

The card tracks the drag offset in real time with no threshold — as soon as the user starts dragging left, the card (and its rotation) follow immediately. On release, commit the advance if the distance or velocity crosses a threshold; otherwise spring back to zero. On commit, record whatever rep count had been reached at the moment of swipe (which may be zero if the set was never started) into `completedReps`. Always append an entry — including 0 for an unstarted set — so the array length always equals `exercise.sets`. The completion percentage is `sum(completedReps[id]) / (sets × reps)`.

Rightward drags are resisted (scaled down, e.g. by 0.1) and always spring back on release.

### CompletionView

Shown when all sets are done. Contains:

- Congratulatory header text
- A non-interactive summary list showing each exercise with:
  - Completion icon (`.green` checkmark or `.red` X)
  - Completion percentage
  - Static sets × reps display
- "Done" button (top-left, replaces the exit button, no confirmation needed)
- "Return to Planning" button at the bottom of the list

#### Completion percentage calculation

For each exercise, sum the rep counts across all sets and divide by total expected reps (`sets × reps`). The completion icon is `.green` if every rep was completed, `.red` otherwise.

---

## Persistence

SwiftData handles `Plan` persistence automatically via the `@Model` macro and `ModelContainer`. No explicit save calls are needed; SwiftData auto-saves on change.

Set up the container in `SetRepScheduleApp`:

```swift
@main
struct SetRepScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Plan.self, Exercise.self])
    }
}
```

On the very first launch ever, inject the default plan. Gate this with an `@AppStorage` bool (e.g. `hasSeededDefaultPlan`). In `ContentView.onAppear`, if the flag is false, insert the seed data and set the flag to true. Subsequent launches — including ones where the user has deleted all plans — do not seed again.

Image bytes are stored directly on each `Exercise` model object via `@Attribute(.externalStorage) var imageData: Data?`. SwiftData stores the blob in an external file rather than inline in SQLite, so the main store stays small regardless of image sizes. No extra configuration is needed on `Plan`.

---

## File Structure

Suggested file layout within the `SetRepSchedule` target:

```
Views/
    PlanningView.swift
    ExerciseRow.swift
    SetsRepsPopover.swift
    DurationPopover.swift
    ImageButton.swift
    PlanMenuButton.swift
    ExerciseView.swift
    SetCard.swift
    ActionButton.swift
    CompletionView.swift
    CircularButton.swift
    ProgressBar.swift

Logic/
    Plan.swift           // @Model
    Exercise.swift       // @Model
```

---

## What Is Explicitly Excluded from Pass 1

The following items from DESIGN.md are deferred to Pass 2 and must not be partially implemented:

- `Cycle` data type
- Cycle items in the planning list
- Per-rep and per-set cycle modes
- The per-rep cycle card in exercise mode
- The plus button menu (the button adds an exercise directly, no menu)
- Drag-onto-cycle interactions
- Cross-level drag behavior
