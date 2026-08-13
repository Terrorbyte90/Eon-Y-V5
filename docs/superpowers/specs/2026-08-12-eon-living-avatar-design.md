# Eon living avatar

## Goal

Make the Nu view feel like an observable living state rather than a static image inside a dashboard.

## Design

The view becomes a full-height scene with Eon identity at the top, a large avatar in the center, concrete derived status and focus below it, and the three body-budget bars at the bottom.

The avatar uses SwiftUI-rendered layers over the Eon image: visible breathing, mouth-origin smoke particles, blink timing, gaze movement, subtle head drift, and state-colored atmospheric light. Animation is continuous but calm and runs at a bounded frame rate.

## State mapping

- Thermal pressure controls smoke intensity and warm/coral state color.
- Processing availability controls calm versus strained glow.
- Current activity/focus determines the concrete status copy and gaze mode.
- No animation is presented as evidence of qualia; labels remain derived/observational.

## Verification

Build the signed iPhone target, verify the app signature, install it on the connected device, launch it, and run `git diff --check`.
