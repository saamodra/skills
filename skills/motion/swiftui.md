# Motion in SwiftUI

Put the shared values in one place (an `enum Motion` next to the theme): the screen, content, press and fade animations; transition helpers that each take `reduceMotion` and return `.opacity` when it is on; and a `PressScaleStyle` ButtonStyle (scale 0.92 with the press spring; opacity 0.6 under Reduce Motion; `.contentShape(Rectangle())` so the whole frame hit-tests).

## Driving animations

- Observable models are mutated from async tasks (network pushes, optimistic state set in a `Task`, timers). `withAnimation` only catches mutations made synchronously inside it. Animate async changes from the view with `.animation(_:value:)` keyed on a small derived `Equatable`: a content-kind enum (`.playing(id)`, `.nothing(id)`, `.offline(id)`), an id, `error != nil`.
- An enum with a counter payload (`waitingToReconnect(attempt:)`) changes on every attempt. Key on a payload-free category instead.
- Put each `.animation` on the narrowest subview that changes. One on a container that holds a size-class `if/else` would crossfade the whole UI on an iPad rotation or Split View resize.
- Wrap taps in `withAnimation(.snappy)` for the synchronous part. A direction `@State` set before the tap (which side the new content enters from) is reset to 0 in the `withAnimation(_:completionCriteria:_:completion:)` completion, so later content that arrives without a tap enters in place.

## Swapping views

- `.id(x)` plus `.transition` inserts the new view and removes the old one at the same time. In a `VStack` both take layout space for the whole transition, so the stack doubles and jumps. Put every swapping slot in a `ZStack(alignment: .top)`; give a swapping image a fixed frame.
- Removal only animates when the `if` sits in an always-present container (`VStack { if let e = error { Banner(e).transition(...) } }`) with the `.animation` on the container.
- Content inside `.safeAreaInset` can pop when the inset height jumps. If it does, move the banner to a bottom `.overlay`.
- At the root, key the animation on the condition the branch actually switches on (`model.session != nil`), and put the app background behind the root `Group` (`.background(Color.background.ignoresSafeArea())`), or the crossfade and scale flash the window background.
- Artwork: key `.id` and the animation on the artwork hash only, so unrelated updates do not re-decode or flash it.

## Ticking views

`TimelineView` progress, time labels and the volume slider get `.transaction { $0.animation = nil }`, so no animated ancestor pulls them into a transition. Keep `.contentTransition(.numericText())` off clocks: it animates every tick.

## Glyphs

`.contentTransition(.symbolEffect(.replace))` needs an animation in the transaction; when the change arrives async, add `.animation(.snappy, value: isPlaying)` on the image.

## Reduced motion

Read `@Environment(\.accessibilityReduceMotion)` in every view that builds a move or scale transition and pass it to the transition helpers. Custom springs and moves do not adapt on their own.
