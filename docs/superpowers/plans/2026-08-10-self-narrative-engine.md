# Eon Self-Narrative Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace repetitive hardcoded self-talk with Qwen-generated, evidence-grounded Eon narratives and a deterministic fallback.

**Architecture:** A pure context builder produces `SelfNarrativeContext`; a narrative engine renders typed entries through Qwen or fallback. A small continuity store prevents repetition and preserves provenance. Existing loops call this boundary instead of constructing status prose directly.

**Tech Stack:** Swift, SwiftUI, Combine, XCTest, existing Qwen handler and EventJournal.

## Global Constraints

- Qwen may formulate text but may not invent measurements, memories, commands, or claims of qualia.
- Every entry carries provenance and epistemic type.
- Fallback mode must work when Qwen is unloaded or fails.
- Narrative code cannot mutate runtime motors or Hermes.
- Keep generated text bounded for iOS memory and log size.

### Task 1: Narrative data model and fallback

**Files:**
- Create: `Eon-Y/Core/Narrative/SelfNarrativeEngine.swift`
- Test: `Eon-YTests/SelfNarrativeEngineTests.swift`

- [ ] Write tests for provenance, bounded fallback text, and repetition avoidance.
- [ ] Run the focused tests and verify they fail because the types do not exist.
- [ ] Add `SelfNarrativeKind`, `SelfNarrativeSource`, `SelfNarrativeContext`, `SelfNarrativeEntry`, `SelfNarrativeMemory`, and deterministic fallback rendering.
- [ ] Run the focused tests and verify they pass.

### Task 2: Context construction from live state

**Files:**
- Modify: `Eon-Y/Core/Narrative/SelfNarrativeEngine.swift`
- Modify: `Eon-Y/Core/Consciousness/ConsciousnessEngine.swift`
- Test: `Eon-YTests/SelfNarrativeEngineTests.swift`

- [ ] Add tests that context contains current metrics, attention, prediction error, and uncertainty without literal placeholder text.
- [ ] Build a context adapter from `UnifiedConsciousState`, `ConsciousThought`, and current brain state.
- [ ] Add structured EventJournal provenance for each generated entry.
- [ ] Verify focused tests and archive compilation.

### Task 3: Qwen generation boundary

**Files:**
- Modify: `Eon-Y/Core/Narrative/SelfNarrativeEngine.swift`
- Modify: `Eon-Y/Core/NeuralEngine/QwenHandler.swift`
- Test: `Eon-YTests/SelfNarrativeEngineTests.swift`

- [ ] Test that Qwen failure returns a fallback entry and never changes runtime state.
- [ ] Add a bounded prompt/response contract containing only serialized narrative context.
- [ ] Parse Qwen output into a typed entry and reject unsupported claims or missing provenance.
- [ ] Verify tests and build.

### Task 4: Migrate monologue and loops

**Files:**
- Modify: `Eon-Y/Core/Consciousness/ConsciousnessEngine.swift`
- Modify: `Eon-Y/Core/Autonomy/EonLiveAutonomy.swift`
- Modify: `Eon-Y/Core/Brain/EonBrain.swift`
- Test: `Eon-YTests/SelfNarrativeEngineTests.swift`

- [ ] Replace repeated status templates at the central emission points with narrative engine calls.
- [ ] Preserve loop semantics and thermal throttling; change only expression generation.
- [ ] Ensure each emitted line has source and epistemic type.
- [ ] Run focused tests and a Release archive.

### Task 5: UI and chat provenance

**Files:**
- Modify: `Eon-Y/Views/Home/FullLogView.swift`
- Modify: `Eon-Y/Views/Chat/ChatView.swift`
- Modify: `Eon-Y/Views/SelfAwareness/SelfAwarenessView.swift`

- [ ] Show source/type labels for model-generated and fallback text.
- [ ] Keep user-facing chat natural while retaining expandable provenance.
- [ ] Verify simulator build and inspect changed views.

### Task 6: Final verification

- [ ] Run all focused narrative tests.
- [ ] Run existing observability and consciousness tests.
- [ ] Archive Release with the Qwen model included.
- [ ] Review git diff and preserve unrelated user changes.
