---
name: motion
description: The user's app motion style (Telegram-like springs, parallax screen push, crossfade content swaps, press bounce). Use when adding, changing or reviewing animations or screen transitions in an app UI, including SwiftUI and Jetpack Compose.
---

# Motion

The user wants motion that feels like Telegram: short, springy, **interruptible**. Smoothness comes from springs that keep their velocity when interrupted, not from long durations. Nothing waits for an animation to finish; tapping back mid-transition reverses it from where it is.

Apply the tokens below as the default. A project's design doc (`DESIGN.md` or similar) wins where it says otherwise; when it has no motion section, add one that states these rules.

## Tokens

| Use | Feel | Compose | SwiftUI |
| --- | --- | --- | --- |
| Screen push / pop | Critically damped, no overshoot, settles ~0.3 s | `spring(dampingRatio = 1f, stiffness = 1000f)` | native push and sheets; root swap `.smooth(duration: 0.45)` |
| Content swap (other device, new item, empty/offline card, banner) | 150-250 ms, no bounce | `spring(1f, 1500f)` | `.snappy` |
| Small controls (press, icon morph, chip) | Light bounce | `spring(0.6f, 800f)` | `.spring(response: 0.3, dampingFraction: 0.6)` |
| Color, dimming | Quick fade | `spring<Color>(1f, 1500f)` | `.easeInOut(duration: 0.25)` |

## Patterns

- **Screen push (Android, or any custom stack):** the incoming screen slides in over the full width. The screen underneath moves a quarter width the other way under a black scrim (about 12% light, 25% dark). Back reverses it. Predictive back follows the finger.
- **iOS screens:** keep the native navigation push, sheets and full-screen covers. The Telegram feel there lives in the state changes inside screens.
- **Whole-app swap** (signed out ↔ signed in, onboarding ↔ main): fade plus scale from 0.96.
- **Content swap:** crossfade with the incoming content scaling from 0.96-0.98. When the swap follows a tap on an item in a row (chips, tabs), the new content also slides in a short way (about 48 pt / dp) from that item's side.
- **Media / list item change:** swap only the artwork and text. Controls, sliders and progress stay in place and never re-key.
- **Banners:** slide in from their edge plus fade; leaving plays the reverse.
- **Small controls:** press scale to 0.92 with the bounce spring; play/pause and similar glyphs morph; selected-state color fades.

## Stay direct

Anything that ticks or follows a finger updates directly, with no animation: seek position, elapsed and remaining time, volume or any slider while dragging, countdowns, reconnect attempt counters. Key every animation on a small derived value (a content kind, an id, a Bool), so a live-state push such as a position or volume update stays direct.

Partial updates are common (title first, artist or artwork a beat later). Key a content swap on the field that identifies the item (title, plus app or source), so one change gives one crossfade.

## Reduced motion

Moves and scales become plain crossfades; haptics stay. Press feedback becomes an opacity dim (0.6) instead of a scale. Compose follows the system animator scale on its own; SwiftUI needs `accessibilityReduceMotion` read by hand.

## Platform reference

Read the one for the platform you are building before writing code; each lists the traps that break these patterns:

- Jetpack Compose: [compose.md](compose.md)
- SwiftUI: [swiftui.md](swiftui.md)

Worked example of both: the Kendali repo (`~/Projects/kendali`), `android/app/src/main/kotlin/dev/bysm/kendali/ui/Motion.kt` and `KendaliRoot.kt`, `ios/Kendali/Views/Theme.swift` and `RemoteView.swift`.

## Done when

Builds and tests prove only that it compiles. The motion is done when it has been watched on a device, emulator or simulator (screen-record: `adb shell screenrecord`, `xcrun simctl io booted recordVideo`) through:

- push → push → back → back, with back tapped mid-transition, and a predictive back gesture cancelled halfway;
- a content swap while something ticks: the ticking value keeps updating without animating;
- a banner appearing and leaving;
- any camera or media surface closed and reopened fast: it comes back live;
- sign-out from a deep screen;
- the same run with reduced motion on.

Report each flow you could not watch as unverified.
