# Eon Observability UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Eon’s current state easier to understand by enriching the Now status stream, improving Language and Settings, and adding a concise scientific evidence guide.

**Architecture:** Keep the existing runtime as the single source of truth. Add pure presentation helpers for status and evidence copy, then compose those helpers in the existing V6 views. Keep Now immersive and move explanatory/technical detail into Inside, Language, Evidence, and Settings.

**Tech Stack:** SwiftUI, existing EonV6Runtime, existing verification/state models, XCTest, xcodebuild, devicectl.

## Global Constraints

- Preserve the existing live/sleep crossfade and portrait edge-to-edge video.
- Keep claims framed as functional analogies, never proof of subjective experience.
- Do not fabricate measurements; all status text must derive from runtime snapshot/state.
- Keep navigation hidden on Now and visible on other V6 tabs.

### Task 1: Add testable presentation copy

**Files:**
- Create: `Eon-Y/Core/V6/EonObservabilityCopy.swift`
- Modify: `Eon-YTests/EonV6CoreTests.swift`

- [x] Add pure functions for level explanations, dynamic status lines, theory summaries, and test summaries.
- [x] Add XCTest coverage for levels 0–5 and scientific caveat language.
- [x] Run project build verification; simulator test execution was unavailable because the scheme exposed no runnable simulator destination.

### Task 2: Expand Now status stream

**Files:**
- Modify: `Eon-Y/Views/V6/EonV6OverviewView.swift`

- [x] Move the active marker down by exactly 5 points.
- [x] Replace the small set of cycle-based phrases with runtime-derived status branches.
- [x] Add more concrete status branches for recovery, thermal load, memory, learning, language, prediction, broadcast, and observation.

### Task 3: Improve Language view

**Files:**
- Modify: `Eon-Y/Views/V6/EonV6LanguageView.swift`

- [x] Add readable language summary, current focus, language dimensions, and reporter boundary.
- [x] Show live Swedish language mastery values from EonBrain.
- [x] Keep Qwen explicitly read-only.

### Task 4: Improve Settings/More view

**Files:**
- Modify: `Eon-Y/Views/V6/EonV6SettingsView.swift`

- [x] Add sections for runtime, presentation, thermal protection, refresh cadence, and transparency.
- [x] Add controls backed by AppStorage and mark protected diagnostics as read-only.
- [x] Add the scientific guide and verification methodology at the bottom.

### Task 5: Verify and install

**Files:**
- Modify only if compilation/test failures require it.

- [x] Run build and `git diff --check`.
- [x] Verify code signing.
- [x] Install and launch on the connected iPhone.
