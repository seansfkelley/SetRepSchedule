# SetRepSchedule

A simple, low-friction app for keeping track of repetitive, mindless exercise regimes, such as used in physical therapy.

## Overview

There are two modes: "planning" and "exercise". Users enter exercise names, sets, reps and durations in planning mode, arrange them in a desired order, and then enter exercise mode. In exercise mode, the app just steps through the entire schedule, at a pace you determine, until you reach the end.

The user may have multiple named plans they can switch between. The app remembers which plan was most recently selected.

## Planning Mode

Planning mode is a glorified list. The primary list element is an exercise. Exercise items can be grouped into cycle items.

The list has a title which is editable by tapping on it. This should use iOS-standard patterns to indicate it's inline interactive.

Edits to the plan are automatically saved immediately. There is no explicit save button.

In a blank plan, this list starts empty. Any time the list is empty, a zero state is shown with explanatory text and a button saying "Add Exercise".

### Exercise Item

Each exercise has, in left-to-right order:

- A free text field for the name.
- A button showing sets and reps.
  - Sets and reps must both be strictly positive integers.
  - The button displays in the format "A x B", where A is sets and B is reps, and has the subtitle "Sets x Reps".
  - When tapped, bring up a popover attached to the button with a pair of +/- numerical selectors that are subtitled "sets" and "reps" and allow tapping the buttons to adjust the count within the allowable range. 
    - The button preview updates in real time.
    - Tap outside the popover dismiss and commit.
- A button with a clock icon.
  - When tapped, opens a popover anchored to the button for setting a duration (minutes:seconds) using scrolling wheels a la the Clock app, plus a clear button.
  - The button preview updates in real time.
  - Tap outside to dismiss and commit.
  - If a duration is set, the list item button shows it. If it's unset, it shows the clock icon.
- A button with a camera icon.
  - When tapped, brings up the camera to take or select a picture for this item. This uses the standard iOS picture/camera selector feature. This isn't Instagram.
  - If there is a picture associated with this item, a tiny preview is shown instead of the camera icon.
    - Tapping it brings it up in a sheet to view larger, and allows removing it from the list item. This reverts the button to the camera icon. 
- A button with a duplication item. 
  - Tapping this duplicates the exercise into a new adjacent item, exactly as it currently is.
  - If this exercise is in a cycle, it duplicates it into the cycle rather than outside.
- A grab handle for dragging the list item. 

An exercise must have a picture and/or a name. If it has neither, it is considered invalid:

- Invalid exercises are free to participate in editing, layout and cycles as if they were valid. The only thing they prevent is transitioning to exercise mode.
- Invalid exercises have a red warning icon preceding their name. Tapping this brings up an explanatory popover, saying a picture and/or name is required. 

Exercise items can be deleted by swiping them to the left using the standard iOS pattern.

At the bottom left of the screen is a circular button with a plus. Tapping this button adds a new blank list item with default set/rep values and autofocuses the name field.

At the top left of the screen is circular button with a list icon:
  - Tapping this button brings up a menu listing every named plan you have.
    - Tapping one of these switches you immediately the other plan.
  - Under the last named plan item is a menu item with a plus and the title "New Plan".
    - Tapping this creates and switches to a new blank plan.
  - The last item of the list is separated by a divider, is marked destructive (red, trash can) and says "Delete this Plan".
    - If the plan has more than zero exercises in it, there is a confirmation dialog.
  - The app starts with one plan with a default name.
    - This plan has a few default exercises and one cycle to demonstrate the features.
  - If you delete all plans, the app reverts to a zero state with an explanatory message and a big button in the middle saying "New Plan" that creates a new blank plan.

### Organization and Cycle Items 

In addition to doing data entry on each list item, the list also allows dragging. Simple dragging to reorder exercises and cycles is supported. Dragging list items on top of each other will group them into a cycle.

A cycle is a set of two or more exercises:

- When exercises are in a cycle, they lose the ability to specify sets and reps independently. Instead, the cycle itself has the same set/rep interface as the exercise item described previously.
- Each exercise still has a name, clock button and camera button, as described previously.
- When moving into a cycle, exercises keep all their metadata, except their individual sets/reps.
- Cycles can be named with a text field in the same manner as an exercise, but do not have to be. There is no such thing as an "invalid" cycle.
- Cycles have an additional button on the right side, just before the grab handle, for configuring their type.
  - In "per-rep" mode, it will cycle through the contained exercises on a rep-by-rep basis, so each rep is different from the next.
  - In "per-set" mode, it will cycle through the contained exercises on a set-by-set basis, so you do a complete set of one exercise before moving onto a different exercise for the next set.
- Cycles do not have a duplication button.

Cycles exist at the same list level as top-level exercises:

- They can be dragged to reorder them relative to top-level exercises.
- More exercises can be dragged onto a cycle, which will append them to the end of the cycle, or can be dragged directly into a location in the cycle between (or above/below) other exercises.
- Cycles cannot be dragged onto exercises.

Cycles can be edited after creation:

- A cycle can be swiped to be deleted. Doing so deletes all the contained exercises.
- Exercises within a cycle can be swiped to be deleted.
- Exercises within a cycle can be dragged to reorder within the cycle, or dragged out of the cycle entirely.
- If deleted or removing an exercise from a cycle leaves it with one exercise, that exercise is automatically popped out to a top-level exercise where the cycle was, and the empty cycle removed.
- When exercises leave a cycle for any reason, they keep all their metadata and become a regular top-level exercise, inheriting the set/rep count of the cycle they were in.

### Switching to Exercise Mode

At the top right is a circular green "play" button. This transitions into exercise mode with the current plan.

If there are any invalid exercises in the schedule, this button is disabled and shows a play icon with a slash through it. Tapping the button jiggles all the currently-invalid list items, scrolling them into view if necessary.

If there are no exercises in the plan, the button is disabled.

## Exercise Mode

At the top left there is a circular left chevron button. Tapping this button transforms it into a text button that says "End Exercises". Tapping it again exits exercise mode.

In exercise mode, the user is walked through the schedule they have created. Each chunk of work is represented visually with a card. Each card is interactive and tracks performed work, and when a card is completed, it swipes away to the left and the next card is shown. Users can swipe a card manually to skip this chunk and proceed to the next one.

There are 2 types of cards, enumerated below.

### Set Card

For top-level exercises or cycles configured to be in "per-set" mode, this card shows a single set.

- At the top of the card is the name of the exercise with the subtitle "Set X of Y".
- Above this title is the name of the containing cycle, if any.
- Below the title is the associated picture, if any.
- The bottom of the card itself is one large button that goes all the way to the edges of the card.
    - If this exercise does not have an associated duration, it is green and says "Complete Rep X of Y".
        - Tapping it increases the rep count.
    - If this exercise has an associated duration, the button inherits the background color and starts by showing "Start Timer (X:Y)" where X:Y is the time.
        - When tapped, it switches to being labeled with a clock icon and counts down the time.
        - If the user taps again before the timer is expired, the button briefly flashes red and then it counts a rep.
        - If the timer expires, the button becomes green and says "Complete Rep X of Y". Tapping it then increases the rep count.
    - In either case...
      - ...if this is the last rep of the exercise, the text is instead "Complete Exercise".
      - ...if this is the last rep of a set but not exercise, the text is instead "Complete Set X of Y".
    - If this rep completes a set and/or an entire exercise, this button programmatically swipes to the next card in order.
    - Integrated along the top edge of this button is a blue progress bar showing the progress through the set.
- The entire card can be swiped away, which will move immediately onto the next card in the schedule.
  - The incomplete reps (or entire sets, if you never started this set) are counted for the statistics shown later.
- You cannot swipe back to a previous card. If you try to, there's just a bounce animation of the failed swipe.

Which card is next depends on whether this is a top-level exercise or a per-set cycle, and whether that exercise or cycle is complete. When in per-set cycle mode, the sets from different exercises are interleaved.

### Per-rep Cycle

In the case of a cycle configured to be in per-rep mode, a "set" is synthesized as a blend of the contained exercises.

This card looks largely the same as the regular set card, except:

- The "next" button's appearance and functionality varies according to which specific rep is current.
  - The primary text of the button refers to the rep count of the current exercise as if it were not part of a cycle, but the text also includes a subtitle stating "Rep X of Y Total" which counts reps across _all_ exercises in this cycle.
    - Remember that a cycle owns the set/rep count, so all exercises in a cycle have the same number of sets and reps.
  - The progress bar is displayed according to the total, not the reps for this exercise.
- The exercise title and picture switch on every rep. Specifically, on completing a rep, they animate away to the left _within_ the bounds of the card.
  - This programmatic action is not available to the user even if it looks like a swipe. If they attempt to swipe, the entire card will be swiped.
- For the purposes of phrasing and keeping track of progress, a "set" in this case is doing the rep count for one set, for _every_ contained exercise.

### End-of-exercise

When the last card is dismissed, the background itself displays a congratulatory note and provides some statistics.

The statistics show a compact version of the schedule.

- The layout is very similar to that of the schedule but less interactive.
- Instead of all the configuration buttons, it shows static versions of the configuration (sets, reps, durations, etc.).
- On the left edge before the titles, it shows an icon followed by a percentage.
  - The percentage counts how many sets/reps were completed. In the case of reps with duration, it simply tracks the binary "did complete entire time" for each rep rather than specific durations.
  - The icon is a green check mark if you did every set/rep.
  - The icon is a red X if you missed even a single set/rep.
  
The top-left chevron transforms to a "Done" button and no longer requires confirmation to leave. There is an additional, redundant, "Return to Planning" button after the statistics table which does the same thing.

## Libraries and Frameworks

SwiftUI, Swift Testing and Swift Data.

Each Plan is a SwiftData `@Model` object. Cycles and Exercises are plain Swift structs conforming to `Codable`, serialized as JSON and stored as a `Data` attribute on `Plan`. This keeps the data model simple — ownership is synonymous with containment, there is no cross-talk, and all deletes are cascades.

UI components deep in the tree (e.g. a button editing an Exercise) receive a `Binding<Exercise>` and can mutate fields directly without any awareness of the containing Plan. SwiftUI propagates the change up through the binding chain automatically.

Images are stored on disk using `@Attribute(.externalStorage)`.

## Future Work

Do not do anything on this list yet.

- Add a concept of "rest time" to each exercise item.
