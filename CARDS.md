# Exercise View: Card Stack Design

This document describes the visual design and animation behavior for the exercise view, which replaces the current single-card approach with a stacked deck metaphor.

## Structure

Each exercise is represented as a deck of cards:

- **Base card**: Contains the exercise's persistent information — name, picture, and notes. This card sits at the bottom of the stack beneath all set cards. It has a dotted outline in the position and size of the set cards that will be dealt onto it, hinting at what is coming, at the bottom of the base card about one third the height and inset slightly from the edges. Because the set cards are perfectly stacked and aligned, that area of the base card is not visible once dealing is complete.
- **Set cards**: One per set, about a third the size of the base card, stacked on top of the base card on the dotted zone. Each set card shows the set number and the action button. The set cards are perfectly aligned — no rotation, no horizontal or vertical offset. Only the topmost card is visible; the rest sit directly beneath it in the stack.

## Progress Bar

A progress bar runs along the top of the screen. It is persistent across the entire exercise session — it tracks the number of sets completed or skipped out of the total number of sets in the plan, across all exercises. It is the target of all set completion animations — completed and skipped set cards fly into it.

## Entering Animation

When a new exercise deck enters the screen:

1. The base card fades in and scales up from slightly below 1.0 to full size (fade + scale-in). This makes it appear to be coming from inside the screen, towards the user.
2. Once the base card animation completes, the set cards deal down onto it in quick succession, staggered by a short delay (roughly 60–80ms apart). Each set card animates from slightly above its final position downward, as if being dealt onto a table.
3. The stack settles with Set 1 on top, ready for interaction.

## Completing a Set

When the user completes a set, the set card flies up toward the progress bar and is absorbed into it:

1. The set card launches upward (or curves if flung in another direction — see Flinging below) and arcs toward the progress bar at the top of the screen.
2. On contact, the progress bar briefly stretches and jiggles — a rubbery, elastic reaction, as if it swallowed something and is digesting it. The feel is playful and videogame-like. The set card gets sucked into it like a black hole, along the lines of the old Genie animation in Mac OS X for minimizing windows.
3. The progress bar then increments to its new value with a smooth fill animation.
4. The next set card is now on top and becomes the active card. The base card remains stationary throughout.

## Completing the Last Set

When the user completes the final set:

1. The last set card flies into the progress bar exactly as described above.
2. Simultaneously, the base card fades out and scales forward toward the user — the same animation it used when entering, but continuing past full size and into nothing. The base card finishes this exit by roughly the 25% point of the set card's flight.
3. The screen is briefly empty, with only the set card still in flight. This gap is intentional — the flying set card gives the eye something to track so it doesn't feel dead.
4. At roughly the 75% point of the set card's flight, the next view — whether another exercise or the completion view — begins fading and scaling in from inside the screen.
5. The progress bar completes its fill and jiggle as normal.

The timing percentages (25%, 75%) are starting points, not hard requirements — adjust by feel during implementation.

The last set card's interaction is identical to all other set cards. The fade of the base card is purely a consequence of there being no sets remaining.

## Flinging

The set card can be flung in any direction — up, down, left, right, diagonally. Regardless of fling direction, the card curves in flight and homes in on the progress bar. The arc should feel physical: a fling downward will curve back up; a fling to the right will bend toward the top of the screen. The card should not teleport — the curve should be visible and satisfying.

## Drag, Threshold, and Reversal

All set card completion animations can be played in reverse:

- The user can drag a set card. As they drag, the card follows their finger.
- If the drag exceeds a threshold when the user releases their finger (either distance or velocity or both), the card commits — it curves toward the progress bar, and the absorption animation plays. 
- If the drag does not reach the threshold and the user releases, the card snaps back to its resting position with a small bounce, and the progress bar does not change.
- The snapped-back card returns to its position in the stack smoothly.

This means no set is ever accidentally skipped — the threshold acts as a confirmation.
