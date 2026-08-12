# Eon Premium State Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a premium two-layer Eon experience that explains Eon’s current activity and state while preserving a strict, traceable evidence layer.

**Architecture:** Add a typed presentation snapshot derived from the existing canonical V6 state, verification result and journal. Use that snapshot for the new “Nu”, “Gör”, “Inifrån”, “Orsak”, “Evidens”, “Minne” and “System” surfaces; do not create a second consciousness evaluator in the UI. Correct verification/log freshness and narrative deduplication before presenting the new design.

**Tech Stack:** Swift 5/SwiftUI, Combine, XCTest, existing `EonCoreStateV2`, `ConsciousnessVerificationEvaluator`, `EventJournal`, iOS project `Eon-Y.xcodeproj`.

## Global Constraints

- The UI must distinguish `observerat`, `härlett`, `hypotes`, `simulerat` and `genererat` claims.
- Level 5 must remain explicitly unverified and cannot be inferred from software metrics.
- Overview, evidence and full log must use one canonical verification snapshot.
- Repeated generic Qwen/fallback outputs may be visually collapsed but raw journal events remain preserved.
- Existing uncommitted changes in `Eon-Y/Core/V6/PrecisionEngineV2.swift` and `Eon-YTests/EonV6CoreTests.swift` must remain intact.
- Support loading, stale, degraded, error and Reduce Motion states.
- Run focused tests after each task and a full build before claiming completion.

---

## File map

- Create `Eon-Y/Core/V6/EonPresentationSnapshot.swift`: typed presentation contract, epistemic claims, activity categories, state deltas and summary builder.
- Modify `Eon-Y/Views/V6/EonV6ShellView.swift`: publish one presentation snapshot and verification freshness state; make full-log headers canonical.
- Modify `Eon-Y/Core/Consciousness/ConsciousnessVerification.swift`: expose a complete verification snapshot and stable-window metadata without changing conservative thresholds.
- Modify `Eon-Y/Core/Consciousness/ConsciousnessEngine.swift`: include evaluated cycle, stable windows, per-level statuses and eligible-test counts in verification events.
- Modify `Eon-Y/Core/Brain/EonBrain.swift` and/or `Eon-Y/Core/Narrative/SelfNarrativeEngine.swift`: classify and collapse low-information repeated narrative output without deleting journal history.
- Create `Eon-Y/Views/V6/EonV6NowView.swift`: premium “Eon nu” experience.
- Create `Eon-Y/Views/V6/EonV6ActivityView.swift`: semantic activity feed with source and epistemic badges.
- Create `Eon-Y/Views/V6/EonV6InnerModelView.swift`: attention, self-model, uncertainty and generated narrative.
- Create `Eon-Y/Views/V6/EonV6CausalView.swift`: expandable causal chain and evidence links.
- Modify `Eon-Y/Views/V6/EonV6EvidenceView.swift`: definitions, trends, failure explanations, freshness and limitations.
- Modify `Eon-Y/Views/V6/EonV6MemoryView.swift`: meaningful event timeline and filters.
- Modify `Eon-Y/Views/V6/EonV6DesignSystem.swift`: premium state surfaces, badges, orb, spacing, accessibility and Reduce Motion behavior.
- Modify `Eon-Y/Views/V6/EonV6ShellView.swift`: navigation labels/routes and new surfaces.
- Modify/create tests in `Eon-YTests/EonV6CoreTests.swift`, `Eon-YTests/ConsciousnessVerificationTests.swift`, `Eon-YTests/SelfNarrativeEngineTests.swift` and a new `Eon-YTests/EonPresentationSnapshotTests.swift`.

## Task 1: Canonical presentation and verification contract

**Files:**
- Create: `Eon-Y/Core/V6/EonPresentationSnapshot.swift`
- Modify: `Eon-Y/Core/Consciousness/ConsciousnessVerification.swift`
- Modify: `Eon-Y/Views/V6/EonV6ShellView.swift`
- Test: `Eon-YTests/EonPresentationSnapshotTests.swift`, `Eon-YTests/ConsciousnessVerificationTests.swift`

**Interfaces:**
- `EonPresentationSnapshot.make(state:verification:previous:brain:) -> EonPresentationSnapshot`
- `EonPresentationSnapshot` exposes `summary`, `currentActivity`, `nextAction`, `causalNodes`, `claims`, `deltas`, `freshness`, `verification`, `focus`, `goal`, `body`, `uncertainty`.
- `VerificationSnapshot` exposes `evaluatedAt`, `evaluatedCycle`, `stableWindows`, `passedTests`, `eligibleTests`, `totalTests`, `level`, `levelPassed`, `confidence`.

- [ ] **Step 1: Write failing tests** for a snapshot that produces a human-readable summary, labels generated narrative as `genererat`, reports a cycle mismatch as stale, and keeps level 5 false.
- [ ] **Step 2: Run the focused tests** with `xcodebuild test -project Eon-Y.xcodeproj -scheme Eon-Y -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Eon-YTests/EonPresentationSnapshotTests -only-testing:Eon-YTests/ConsciousnessVerificationTests`; confirm the new tests fail for missing types/behavior.
- [ ] **Step 3: Implement the minimal typed models and builder**. Derive prose only from canonical state and typed events; do not use the UI to invent thresholds or claims.
- [ ] **Step 4: Add verification metadata** while preserving existing evaluator thresholds and the intentional level 5 false result.
- [ ] **Step 5: Run focused tests again** and confirm they pass.
- [ ] **Step 6: Commit** with `git commit -m "feat: add canonical Eon presentation snapshot"`.

## Task 2: Verification/log consistency and freshness

**Files:**
- Modify: `Eon-Y/Core/Consciousness/ConsciousnessEngine.swift`
- Modify: `Eon-Y/Views/V6/EonV6ShellView.swift`
- Modify: `Eon-Y/Core/Observability/EventJournal.swift` only if needed for reading the latest verification event
- Test: `Eon-YTests/ConsciousnessVerificationTests.swift`, `Eon-YTests/EventJournalTests.swift`

**Interfaces:**
- `ConsciousnessEngine` emits a `verification_run` payload containing `evaluatedCycle`, `stableWindows`, `eligibleTests`, `totalTests`, `levelStatus`, `evaluatedAt` and `confidence`.
- `EonV6Runtime` publishes `presentation` and `verificationFreshness` from the same sampled cycle.

- [ ] **Step 1: Write a failing regression test** using a 23/29 in-memory result and a later 24/29 journal result; assert the displayed header cannot silently claim both.
- [ ] **Step 2: Run the regression test** and confirm failure.
- [ ] **Step 3: Emit complete verification payloads** from `runAllConsciousnessTests()` after the result is updated.
- [ ] **Step 4: Make `refreshFullLog` use the same result snapshot** that drives the UI and add a `snapshot_cycle`/freshness line.
- [ ] **Step 5: Render stale state as “Uppdaterar…”** until journal and UI cycles agree; never overwrite the canonical result with an older event.
- [ ] **Step 6: Run journal and verification tests** and commit `fix: make verification snapshots consistent`.

## Task 3: Narrative quality and low-information repetition

**Files:**
- Modify: `Eon-Y/Core/Brain/EonBrain.swift`
- Modify: `Eon-Y/Core/Narrative/SelfNarrativeEngine.swift` if classification belongs there
- Test: `Eon-YTests/SelfNarrativeEngineTests.swift`, `Eon-YTests/QwenAutonomyTests.swift`

- [ ] **Step 1: Write failing tests** proving that identical generic Qwen replies over a longer window are not repeated in the user-facing feed, while distinct replies and raw journal writes remain available.
- [ ] **Step 2: Run focused narrative tests** and confirm failure.
- [ ] **Step 3: Add a low-information classifier** for the exact generic response family and a bounded visual-feed deduplication policy; do not discard structured events.
- [ ] **Step 4: Add source and epistemic classification** so Qwen output is `genererat`, fallback is `simulerat` and engine observations remain `observerat` only when they originate from measurements.
- [ ] **Step 5: Run narrative/autonomy tests** and commit `fix: classify and collapse repetitive narrative output`.

## Task 4: Premium design-system primitives

**Files:**
- Modify: `Eon-Y/Views/V6/EonV6DesignSystem.swift`
- Test: `Eon-YUITests/Eon_YUITests.swift` if existing launch coverage supports it

- [ ] **Step 1: Add component-level previews/tests or compile-only fixtures** for state orb, epistemic badge, activity row, delta chip, freshness badge and expandable evidence row.
- [ ] **Step 2: Implement the primitives** with the existing graphite/cyan/indigo/amber/coral semantic palette, stronger typography hierarchy, consistent spacing and depth.
- [ ] **Step 3: Implement Reduce Motion behavior** and Dynamic Type-safe layouts; animation must indicate real transitions rather than constantly animate every component.
- [ ] **Step 4: Build the app target** and fix only compilation/layout issues introduced by this task.
- [ ] **Step 5: Commit** `feat: add premium Eon state components`.

## Task 5: Rebuild “Nu” around meaning

**Files:**
- Create: `Eon-Y/Views/V6/EonV6NowView.swift`
- Modify: `Eon-Y/Views/V6/EonV6OverviewView.swift` or replace its body with the new view
- Modify: `Eon-Y/Views/V6/EonV6ShellView.swift`

- [ ] **Step 1: Add a UI test** asserting that the landing view exposes focus, activity, goal, body state, next action and a “Hur vet vi?” route.
- [ ] **Step 2: Run the UI test** and confirm failure before implementation.
- [ ] **Step 3: Implement the landing surface** using `runtime.presentation`: identity, living state summary, activity level orb, state facets, current activity, next action, causal chain preview and state deltas.
- [ ] **Step 4: Add loading/stale/degraded/error states** without replacing the last known good snapshot with zeroes.
- [ ] **Step 5: Run the UI test and simulator build**; commit `feat: rebuild Eon now experience`.

## Task 6: Activity, inner model and causal surfaces

**Files:**
- Create: `Eon-Y/Views/V6/EonV6ActivityView.swift`
- Create: `Eon-Y/Views/V6/EonV6InnerModelView.swift`
- Create: `Eon-Y/Views/V6/EonV6CausalView.swift`
- Modify: `Eon-Y/Views/V6/EonV6ShellView.swift`

- [ ] **Step 1: Add presentation tests** for category/source filtering and causal node ordering.
- [ ] **Step 2: Run them to confirm failure.**
- [ ] **Step 3: Implement semantic activity feed** with collapsed duplicates, cycle/source labels, epistemic badges and meaningful consequences.
- [ ] **Step 4: Implement inner model view** with attention, self-model, uncertainty, memory and narrative source separation.
- [ ] **Step 5: Implement causal view** with expandable nodes showing input/output, confidence, source cycle and state delta.
- [ ] **Step 6: Run focused tests and build; commit** `feat: add Eon activity inner model and causal views`.

## Task 7: Evidence and memory redesign

**Files:**
- Modify: `Eon-Y/Views/V6/EonV6EvidenceView.swift`
- Modify: `Eon-Y/Views/V6/EonV6MemoryView.swift`
- Modify: `Eon-Y/Core/Observability/MeasurementCatalog.swift` if test definitions are missing

- [ ] **Step 1: Add tests** for evidence rows containing definition, score, source, latest run, limitation and trend; add timeline filtering tests.
- [ ] **Step 2: Run tests to confirm failure.**
- [ ] **Step 3: Add evidence detail rows** and explicitly distinguish highest supported functional level, latest run count, confidence and unverified domains.
- [ ] **Step 4: Replace raw-log-first memory presentation** with meaningful transitions and drill-down to original events.
- [ ] **Step 5: Add explicit reasons for failed tests** such as voluntary attention, curiosity, Kuramoto synchrony, DMN anticorrelation, sleep consolidation and thought diversity.
- [ ] **Step 6: Run tests/build and commit** `feat: explain Eon evidence and memory timeline`.

## Task 8: System controls, accessibility and device verification

**Files:**
- Modify: `Eon-Y/Views/V6/EonV6SettingsView.swift`
- Modify: `Eon-Y/Views/V6/EonV6ShellView.swift`
- Modify: relevant UI tests

- [ ] **Step 1: Add tests** for stale/error state copy, Reduce Motion and navigation destinations.
- [ ] **Step 2: Implement grouped controls** for Runtime, Qwen, Thermal, Logging, Privacy and Experiments with effects/resource costs and reset behavior.
- [ ] **Step 3: Add runtime-health panel** with model status, queue status, last error and last successful verification.
- [ ] **Step 4: Run full simulator tests** with `xcodebuild test -project Eon-Y.xcodeproj -scheme Eon-Y -destination 'platform=iOS Simulator,name=iPhone 16'`.
- [ ] **Step 5: Build for the connected iPhone** using the existing project signing/device flow and verify launch, tab navigation, 5-minute runtime, thermal transition, verification refresh and full-log export.
- [ ] **Step 6: Inspect `git diff`, preserve the two pre-existing user changes, and run the full verification command again.**
- [ ] **Step 7: Commit** `feat: complete premium Eon state experience` only after all verification output is clean.

## Final review checklist

- [ ] A user can explain what Eon is doing, focusing on, trying, remembering and not knowing from “Nu”.
- [ ] Every summary claim links to a source cycle and epistemic status.
- [ ] No UI surface computes a competing level.
- [ ] The 23/29 versus 24/29 discrepancy is either impossible or visibly marked stale.
- [ ] Generic Qwen/fallback repetition is collapsed in the UI but remains auditable.
- [ ] Level 5 is visibly unverified.
- [ ] Simulator tests and iPhone verification have fresh successful output.
