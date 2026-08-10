# Eon Architecture, Observability and UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Eon’s runtime, measurements, monologue, Qwen integration, Hermes export and UI coherent, auditable and thermally safe.

**Architecture:** Introduce canonical Codable event/snapshot types and a single journal boundary first. Existing engines publish adapters into that boundary; UI and Hermes consume the same data. Then consolidate lifecycle/thermal/Qwen policy before replacing navigation and views.

**Tech Stack:** Swift 5/SwiftUI, Foundation Codable, CryptoKit, URLSession, XCTest/XCUITest, llama.cpp/Qwen3 GGUF, iOS simulator.

## Global Constraints

- Proxy metrics must be labelled as proxies and never presented as proof of consciousness or qualia.
- Hermes is receive-only from Eon; inbound data is signed, schema-limited and cannot become commands, prompts, URLs or executable code.
- Qwen may propose language/evaluation/optimization actions but cannot directly mutate production parameters, network policy or run tools.
- Local model loading remains lazy and thermal/memory guarded.
- Large knowledge data remains runtime data, not large Swift literals.
- Existing user edits in `Eon-Y/Info.plist` and `ExportOptions-AppStore.plist` must be preserved.

### Task 1: Add canonical event and snapshot schemas

**Files:**
- Create: `Eon-Y/Core/Observability/CognitiveEvent.swift`
- Create: `Eon-Y/Core/Observability/CognitiveSnapshot.swift`
- Create: `Eon-Y/Core/Observability/MeasurementCatalog.swift`
- Test: `Eon-YTests/ObservabilitySchemaTests.swift`

**Interfaces:**
- `CognitiveEvent`: Codable/Sendable event with `eventID`, `sessionID`, `cycleID`, `sequence`, `timestamp`, `source`, `kind`, `severity`, `payload`.
- `CognitiveSnapshot`: Codable/Sendable immutable export object with runtime, workspace, self-model, memory, metacognition, language, Qwen, motor and proxy metrics.
- `MeasurementDescriptor`: id, label, definition, value, unit, confidence, provenance, temporalWindow and `epistemicStatus`.

- [ ] Write failing tests for event round-trip, stable IDs, snapshot round-trip and proxy epistemic labels.
- [ ] Run `xcodebuild test -project Eon-Y.xcodeproj -scheme Eon-Y -destination 'platform=iOS Simulator,id=07257257-AFB7-47FC-9D7F-6088C42D8223'` and confirm the new tests fail for missing types.
- [ ] Implement the minimal Codable value types with explicit enums and bounded payload fields.
- [ ] Re-run the focused tests and confirm they pass.
- [ ] Commit `feat: add canonical cognitive observability schemas`.

### Task 2: Build the unified append-only journal

**Files:**
- Create: `Eon-Y/Core/Observability/EventJournal.swift`
- Modify: `Eon-Y/Core/Logging/RunSessionLogger.swift`
- Modify: `Eon-Y/Core/Logging/CognitionLogger.swift`
- Modify: `Eon-Y/Core/Logging/ResourceDiagnosticsLogger.swift`
- Test: `Eon-YTests/EventJournalTests.swift`

**Interfaces:**
- `actor EventJournal` with `startSession()`, `append(_:)`, `append(snapshot:)`, `flush()`, `manifest()`, `recentSegments()`, `rotateIfNeeded()` and `exportBatch(maxBytes:maxAge:)`.
- JSONL segment files under Application Support `EonJournal/events/<date>/<sessionID>/` with a manifest and bounded rotation.

- [ ] Write failing tests for ordering, rotation at byte limit, interrupted append recovery and manifest counts.
- [ ] Run focused tests and verify the expected failures.
- [ ] Implement atomic append with one writer actor, sequence assignment, segment rotation and manifest updates.
- [ ] Add redaction/size limits for free text and make event payloads schema-limited.
- [ ] Adapt existing loggers to publish events while retaining UI compatibility.
- [ ] Run focused tests, then the existing logging/architecture tests.
- [ ] Commit `feat: add structured event journal`.

### Task 3: Integrate journal with the cognitive cycle

**Files:**
- Modify: `Eon-Y/Core/Consciousness/ConsciousnessEngine.swift`
- Modify: `Eon-Y/Core/Consciousness/ConsciousnessOrchestrator.swift`
- Modify: `Eon-Y/Core/Autonomy/EonLiveAutonomy.swift`
- Modify: `Eon-Y/Core/Brain/EonBrain.swift`
- Create: `Eon-Y/Core/Observability/CognitiveSnapshotBuilder.swift`
- Test: `Eon-YTests/CognitiveCycleObservabilityTests.swift`

**Interfaces:**
- `CognitiveSnapshotBuilder.reduce(previous:delta:events:) -> CognitiveSnapshot`.
- Every autonomous cycle gets one `sessionID`/`cycleID`, a start event, motor events, measurement events and one completed snapshot.

- [ ] Write failing tests for one snapshot per cycle, stable cycle ordering and source-labelled monologue events.
- [ ] Run the tests to verify they fail because current loops do not publish canonical snapshots.
- [ ] Add adapters around existing engine outputs rather than rewriting all motors at once.
- [ ] Mark generated monologue entries with `observed`, `inferred`, `hypothesis` or `simulated`.
- [ ] Deduplicate identical consecutive display entries while preserving every journal event.
- [ ] Verify simulator build and run a five-minute bounded cycle test.
- [ ] Commit `feat: publish canonical cognitive cycle snapshots`.

### Task 4: Harden Hermes export and storage

**Files:**
- Modify: `Eon-Y/Core/BackgroundSync/BackgroundTelemetryBridge.swift`
- Modify: `Eon-Y/Core/BackgroundSync/BackgroundDataImporter.swift`
- Create: `Eon-Y/Core/Observability/HermesExportCoordinator.swift`
- Create: `Eon-Y/Core/Observability/HermesExportPolicy.swift`
- Modify: `Eon-Y/Info.plist`
- Test: `Eon-YTests/HermesExportPolicyTests.swift`

**Interfaces:**
- `HermesExportCoordinator` batches journal segments/snapshots every 60 seconds or 256 KB, flushes immediately for errors and thermal transitions, and tracks ACK/checksum without accepting commands.
- `HermesExportPolicy` rejects inbound commands, prompts, executable text, arbitrary URLs and parameter mutations.

- [ ] Write failing tests proving allowed snapshot/event payloads pass and command-shaped payloads are rejected.
- [ ] Run focused tests and confirm failures.
- [ ] Implement signed batch envelopes, checksum, retry/backoff, upload size limits and local pending queue.
- [ ] Keep the crash fix: no `dataTask` on background URLSession; use a safe session for live JSON or file-backed upload tasks for true background delivery.
- [ ] Add daily/session directory layout and retention policy.
- [ ] Verify no Hermes response can reach Eon’s prompt, command, shell or parameter APIs.
- [ ] Commit `feat: add bounded Hermes journal export`.

### Task 5: Consolidate runtime, thermal and Qwen policy

**Files:**
- Modify: `Eon-Y/Core/Autonomy/RuntimeThermalCoordinator.swift`
- Modify: `Eon-Y/Core/Autonomy/ThermalSleepManager.swift`
- Modify: `Eon-Y/Core/NeuralEngine/NeuralEngineOrchestrator.swift`
- Create: `Eon-Y/Core/NeuralEngine/QwenAutonomyPolicy.swift`
- Create: `Eon-Y/Core/NeuralEngine/QwenTaskQueue.swift`
- Test: `Eon-YTests/QwenAutonomyPolicyTests.swift`

**Interfaces:**
- `QwenAutonomyPolicy.decide(snapshot:task:thermal:) -> QwenDecision` with allow/defer/reject and reason.
- `QwenTaskQueue` accepts only typed `languageCoach`, `evaluator` and `optimizer` tasks; optimizer output is a sandbox proposal, never a direct mutation.

- [ ] Write failing tests for thermal rejection, memory guard, unload behavior and forbidden task types.
- [ ] Run focused tests and confirm failures.
- [ ] Implement policy decisions, bounded queue depth, token/time budgets and automatic unload.
- [ ] Emit Qwen task/result events with prompt hash and summary, not raw hidden reasoning.
- [ ] Verify Qwen can autonomously contribute only through the policy queue.
- [ ] Commit `feat: add auditable Qwen autonomy policy`.

### Task 6: Replace Project tab with Qwen Lab

**Files:**
- Modify: `Eon-Y/App/RootNavigationView.swift`
- Create: `Eon-Y/Views/Qwen/QwenLabView.swift`
- Create: `Eon-Y/Views/Qwen/QwenTaskDetailView.swift`
- Create: `Eon-Y/Views/Qwen/QwenMeasurementReviewView.swift`
- Delete: `Eon-Y/Views/Project/ProjectView.swift`
- Test: `Eon-YUITests/QwenLabNavigationTests.swift`

- [ ] Write a failing UI test for the new tab and absence of Project.
- [ ] Implement navigation changes and lazy mounting.
- [ ] Add model status, task queue, language action, measurement review and sandbox proposal screens.
- [ ] Add explicit provenance and safety state to every Qwen result.
- [ ] Run UI tests on iPhone simulator.
- [ ] Commit `feat: replace project tab with Qwen lab`.

### Task 7: Consolidate measurements and rebuild consciousness views

**Files:**
- Modify: `Eon-Y/Views/SelfAwareness/SelfAwarenessView.swift`
- Modify: `Eon-Y/Views/SelfAwareness/ConsciousnessLiveView.swift`
- Modify: `Eon-Y/Views/SelfAwareness/MotorRoomView.swift`
- Modify: `Eon-Y/Views/Language/LanguageView.swift`
- Create: `Eon-Y/Views/Shared/MeasurementCard.swift`
- Create: `Eon-Y/Views/Shared/ProvenanceBadge.swift`
- Test: `Eon-YUITests/MeasurementPresentationTests.swift`

- [ ] Write UI tests for grouped runtime/cognitive/language/theory sections and warning states.
- [ ] Implement shared cards from `CognitiveSnapshot`, including definitions and trends.
- [ ] Replace unsupported absolute labels with proxy labels and confidence.
- [ ] Make monologue sections source-filterable and deduplicated.
- [ ] Verify dynamic type, dark mode, small iPhone and long-running updates.
- [ ] Commit `refactor: unify measurement and monologue presentation`.

### Task 8: Rework settings, chat and Swedish language surface

**Files:**
- Modify: `Eon-Y/Views/Profile/SettingsView.swift`
- Modify: `Eon-Y/Views/Profile/AutomationSettingsView.swift`
- Modify: `Eon-Y/Views/Chat/ChatView.swift`
- Modify: `Eon-Y/Views/Chat/ChatModeSheet.swift`
- Modify: `Eon-Y/Core/SpecialisedChat/SwedishResponseBuilder.swift`
- Modify: `Eon-Y/Core/Swedish/SwedishLanguageCore.swift`
- Test: `Eon-YTests/SettingsAndLanguageTests.swift`

- [ ] Write failing tests for defaults, Qwen unload toggle, thermal mode, Hermes export toggle and Swedish response provenance.
- [ ] Implement grouped settings with reset/default descriptions and safe disabled states.
- [ ] Improve chat source labels, uncertainty, follow-up handling, repetition suppression and Swedish terminology.
- [ ] Run unit/UI tests and inspect all settings states.
- [ ] Commit `feat: improve settings and Swedish chat experience`.

### Task 9: Full verification and release audit

**Files:**
- Modify: `README.md`
- Create: `docs/superpowers/reports/2026-08-10-eon-architecture-audit.md`

- [ ] Run all unit tests and UI tests.
- [ ] Build Debug and Release for simulator.
- [ ] Run a bounded five-minute autonomy session and inspect journal integrity.
- [ ] Run crash-log scan for CFNetwork, abort, memory pressure and model-load failures.
- [ ] Verify the bundle includes Qwen and all required knowledge resources.
- [ ] Review Swift concurrency warnings and classify remaining warnings.
- [ ] Update the audit report with evidence, known limitations and exact build artifacts.
- [ ] Commit `docs: record Eon architecture verification`.
