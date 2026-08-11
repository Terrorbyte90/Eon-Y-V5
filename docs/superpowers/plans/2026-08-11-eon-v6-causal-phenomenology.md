 # Eon v6 Causal Phenomenology Implementation Plan
 
 Goal: Evolve Eon into a causal, state-centered, inspectable cognitive system with redesigned SwiftUI surfaces.
 
 Architecture: Add a versioned v6 domain layer around one canonical EonCoreStateV2. Keep Qwen behind a language-reporting boundary. Replace navigation/UI composition with task-oriented views driven by canonical state and journal.
 
 Tech stack: Swift 5/SwiftUI, Codable, actors/MainActor, existing llama.cpp/Qwen, EventJournal and Hermes bridge.
 
 Global constraints:
 - No Hermes credentials in the app; no Eon command authority.
 - Qwen may propose language/analysis but may not mutate canonical cognitive state.
 - Every new state field has a producer, consumer and journal representation.
 - Thermal policy reduces work safely on iOS.
 - Build generic iOS after each architecture slice.
 - Preserve v5-final; v6 follows it.
 
 Task 1: V6 canonical state and causal records
 Create Eon-Y/Core/V6/EonCoreStateV2.swift, CausalTraceEngine.swift, PredictionRecordStore.swift and Eon-YTests/EonV6CoreTests.swift. Define Codable records for epistemic field, predictions, precision, body, affect, policy and causal edges. Add bounded history, deterministic IDs, roundtrip tests and causal ordering tests.
 
 Task 2: Precision, body, affect and policy coupling
 Create PrecisionEngineV2.swift, InteroceptiveBodyCore.swift, AffectiveCoreV2.swift and PolicySelectionCore.swift. Make prediction error, thermal load and outcomes alter precision, valence, body state and policy scores. Test policy changes under body/affect changes.
 
 Task 3: Evidence and perturbation laboratory
 Create ConsciousnessEvidenceEngine.swift. Extend ConsciousnessPerturbationSuite with self-model, valence and metacognition perturbations. Add multi-theory EvidenceProfile and held-out/language-off flags.
 
 Task 4: Qwen language boundary and observability
 Create LanguageReporter.swift. Extend CognitiveSnapshotBuilder and EonBrain so prose carries provenance and epistemic type, generated prose cannot become canonical state, and v6 state/causal traces are exported.
 
 Task 5: V6 UI redesign
 Create EonV6ShellView, EonV6OverviewView, EonV6InsideView, EonV6EvidenceView, EonV6MemoryView, EonV6SettingsView and EonV6DesignSystem under Eon-Y/Views/V6. Use a dark observatory system with graphite, indigo, cyan, warm affect accent and monospaced data labels. Make Overview answer what is happening now, Inside show canonical state and causal chain, Evidence show theory families/tests/ablations, and Settings expose model/thermal/logging/Hermes/experiment controls.
 
 Task 6: Verification and v6 artifact
 Run focused tests, generic iOS build, archive if signing permits, review warnings and commit v6 changes.
 
