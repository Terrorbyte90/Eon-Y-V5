# Coordinated Consciousness and Knowledge Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect V5's cognitive engines through a deterministic unified cycle and move heavyweight knowledge content out of Swift source literals into lazy-loaded resources.

**Architecture:** Add small value types for immutable state and subsystem deltas, then make one orchestrator own cycle ordering and metrics. Add a resource-backed knowledge store with an import/export boundary so the app can start without parsing the full corpus.

**Tech Stack:** Swift, SwiftUI, XCTest, Foundation, SQLite3 if already available in the target; no new third-party dependency.

## Global Constraints

- Preserve existing V5 user flows and persistent-memory compatibility.
- Do not claim any metric proves phenomenal consciousness.
- Do not load the full corpus into memory at startup.
- Keep theory metrics explicitly named as proxies.

### Task 1: Map existing interfaces and add test target fixtures

**Files:**
- Inspect: `Eon-Y/Core/Consciousness/*.swift`, `Eon-Y/Core/Brain/*.swift`, `Eon-Y/Core/Memory/*.swift`
- Modify: `Eon-YTests/Eon_YTests.swift`

- [ ] **Step 1: Write the failing contract tests** for state immutability, delta application, and deterministic cycle ordering.
- [ ] **Step 2: Run `xcodebuild test` for the existing scheme** and record whether the environment can build the iOS target.
- [ ] **Step 3: Keep only tests that express the new public contracts**, removing environment-only failures from the feature suite.

### Task 2: Implement unified state and subsystem deltas

**Files:**
- Create: `Eon-Y/Core/Consciousness/UnifiedConsciousState.swift`
- Create: `Eon-Y/Core/Consciousness/ConsciousnessDelta.swift`
- Modify: `Eon-YTests/Eon_YTests.swift`

- [ ] **Step 1: Add failing tests** for clamped normalized values, bounded workspace capacity, and applying independent deltas without mutation.
- [ ] **Step 2: Implement minimal Codable structs** for perception, broadcast, self, affect, memory, metacognition, and proxy metrics.
- [ ] **Step 3: Add `applying(_:)` to produce a new snapshot** and verify the tests pass.

### Task 3: Implement the deterministic consciousness orchestrator

**Files:**
- Create: `Eon-Y/Core/Consciousness/ConsciousnessOrchestrator.swift`
- Create: `Eon-Y/Core/Consciousness/ConsciousnessCycleInput.swift`
- Modify: `Eon-YTests/Eon_YTests.swift`

- [ ] **Step 1: Add a failing test** asserting the pipeline order: signal → prediction → attention → workspace → recurrence → self/metacognition → memory → action → metrics.
- [ ] **Step 2: Implement protocol-based stage closures** with a single `advance(input:)` entry point and a reduced mode for thermal pressure.
- [ ] **Step 3: Add proxy metric calculation** for global availability, recurrence depth, temporal continuity, self-model coupling, metacognitive calibration, and integration.
- [ ] **Step 4: Verify deterministic output** for identical input and pass all unit tests.

### Task 4: Connect V5 startup to the orchestrator without replacing existing engines

**Files:**
- Inspect/modify: `Eon-Y/Core/Consciousness/ConsciousnessEngine.swift`
- Inspect/modify: `Eon-Y/Core/Brain/EonBrain.swift`
- Modify: `Eon-YTests/Eon_YTests.swift`

- [ ] **Step 1: Add a failing integration test** proving one engine cycle publishes a unified snapshot.
- [ ] **Step 2: Adapt existing engine outputs** into deltas at the boundary, preserving their current public APIs.
- [ ] **Step 3: Wire lifecycle start/stop and thermal mode** through the orchestrator.
- [ ] **Step 4: Run unit and integration tests, then inspect for actor/MainActor violations.**

### Task 5: Create resource-backed knowledge schema and store

**Files:**
- Create: `Eon-Y/Core/Knowledge/KnowledgeRecord.swift`
- Create: `Eon-Y/Core/Knowledge/KnowledgeStore.swift`
- Create: `Eon-Y/Core/Knowledge/KnowledgeResourceLoader.swift`
- Create: `Eon-YTests/KnowledgeStoreTests.swift`

- [ ] **Step 1: Add failing tests** for bounded search, batch streaming, language filtering, and missing-resource behavior.
- [ ] **Step 2: Implement JSONL resource loading** with line-by-line decoding and a bounded result buffer.
- [ ] **Step 3: Add optional SQLite indexing only behind the existing Foundation/SQLite availability boundary**, keeping the JSONL fallback buildable.
- [ ] **Step 4: Verify no API reads the complete resource into one array.**

### Task 6: Export and migrate existing knowledge content

**Files:**
- Create: `Scripts/export_knowledge.py`
- Create: `Eon-Y/Resources/Knowledge/knowledge.v1.jsonl.gz`
- Create: `Eon-Y/Resources/Knowledge/manifest.json`
- Modify: `Eon-Y/Core/Knowledge/KnowledgeStore.swift`

- [ ] **Step 1: Add an export regression test** for stable IDs, Unicode preservation, duplicate detection, and record counts.
- [ ] **Step 2: Export the current V5 article/lexicon data** with provenance and checksums.
- [ ] **Step 3: Add versioned migration/checkpoint handling** so an interrupted import can resume and old storage remains readable.
- [ ] **Step 4: Remove only duplicate heavyweight Swift literals after export verification.**

### Task 7: Build, performance, and regression verification

**Files:**
- Modify: `Eon-YTests/*.swift`
- Modify: `README.md`

- [ ] **Step 1: Add startup and memory-budget tests** proving the full corpus is not parsed at launch.
- [ ] **Step 2: Run `xcodebuild test` on the available simulator scheme.**
- [ ] **Step 3: Run `xcodebuild build` with the app's normal configuration and capture warnings/errors.**
- [ ] **Step 4: Document the new resource format, migration command, and theory proxy limitations.**
- [ ] **Step 5: Review the diff and commit the completed implementation.**
