# Motion in Jetpack Compose

Put the shared specs in one file (`Motion.kt`): screen, quick, bounce and color springs, a `contentSwap()` ContentTransform (fade + `scaleIn(initialScale = 0.96f)` togetherWith fadeOut), a `Modifier.pressScale(interactionSource)`, and a `Modifier.blockTouches()`.

## Screen stack

- Hand-roll the stack with one `AnimatedContent` at the root; a few screens with a hand-passed ViewModel need no navigation-compose.
- Key it on one derived **destination** computed from every input (auth state plus current screen), so signing out from a deep screen is a single transition. Use a data class that also carries what the screens need (host, ids), and `contentKey = { it.destination }` so a data change inside a destination does not re-run the transition.
- Inside the content lambda, read only the lambda's parameter. A leaving screen that reads the live outer state renders with the new state (a signed-in screen sliding out while already signed out).
- Direction from depth (root 0, then 1, 2...). Forward: `slideInHorizontally { it }` togetherWith `slideOutHorizontally { -it / 4 }`; back: the reverse. Set `targetContentZIndex` (positive forward, negative back) or the returning screen draws over the leaving one. Screens outside the stack (loading, sign-in) use fade + scale from 0.96 over an unfaded outgoing screen.
- Dim the covered screen with a black scrim drawn in `drawWithContent`, alpha from `transition.animateFloat` on `EnterExitState`. A `fadeOut` shows the root background through it and brightens light mode.
- Each child draws its own opaque background. `clipToBounds()` on a width-capped column, so slides stay inside it on tablets.
- `blockTouches()` on any child whose `transition.targetState != Visible`, so a leaving screen cannot be tapped.
- Wrap each child in `rememberSaveableStateHolder().SaveableStateProvider(destination)` and give lists `rememberLazyListState()`, so the screen revealed by a pop keeps its scroll. After a transition settles, `removeState` for destinations deeper than the current one, so they open fresh.

## Predictive back

- Drive the root from a `SeekableTransitionState` via `rememberTransition`; a `LaunchedEffect(state)` calls `seek.animateTo(state)` for ordinary navigation.
- `PredictiveBackHandler(enabled = not at the root)` replaces `BackHandler`; back at the root goes to the launcher. Collect progress into `seek.seekTo(progress, previousState)`.
- Change the screen state only on commit, and only when the live state still equals the state the gesture started from.
- In `catch (CancellationException)` and in the failed-commit branch, settle with `withContext(NonCancellable) { seek.animateTo(liveState) }` (live state from `rememberUpdatedState`). Settling on `seek.currentState` instead leaves the old screen up when navigation or sign-out interrupts the gesture, because the interrupting `animateTo` throws into the handler.

## Lists and cards

- In a `LazyColumn`, an `AnimatedVisibility` inside a conditional `item {}` never plays its exit (the item is removed at once). Give items stable keys and use `Modifier.animateItem()`; keep a banner item in place and swap only its message inside.
- A card swapped on another entity: `AnimatedContent` keyed on its id, sliding toward the tapped item's index; fade when either id has left the list. The card renders from the lambda parameter, never the live selection.
- Nested `AnimatedContent` for a media item covers artwork and text only. Sliders, transport and anything reading a ticking clock stay outside, or a change mid-drag resets the drag state and the ticks get pulled into the transition. Read the clock only inside the composable that shows it.
- Use one size animation per height: the card's `SizeTransform`, not also `animateContentSize`.
- `contentKey` collapses states that look the same (Idle and Loading both show a spinner), so entry does not blink spinner to spinner.

## Lifecycles stretched by exit animations

An exiting screen stays composed for the length of its exit, so its `DisposableEffect` cleanup runs late, after the next instance has started:

- Shared cleanup (clearing a one-time code, a session) becomes a viewer counter in the ViewModel: clear when the last viewer leaves. A re-entered screen shows its own loading state until its own request has run, never the previous instance's data.
- Camera (CameraX): `ProcessCameraProvider` is a process singleton. Unbind only this preview's use cases in `onDispose`, never `unbindAll()`. Start the camera once the enter transition has settled (`currentState == targetState == Visible`) and stop it as the exit starts.

## Overlays

An overlay that slides over a screen kept composed underneath (a scanner over a form): call `LocalFocusManager.clearFocus()` on open so the IME closes, block touches on the overlay, and `clearAndSetSemantics {}` on the screen underneath while the overlay is up, so TalkBack cannot reach it.

## Reduced motion

Compose scales every animation by the system animator duration scale (`MotionDurationScale`); Remove animations turns them off. No separate code path.
