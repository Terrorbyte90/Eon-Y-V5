# Eon V6 — Premium State Experience

## Purpose

Make Eon understandable as a running system, not only as a collection of metrics. The app must show what Eon is doing, what state it is in, what caused that state, what it remembers, and what is actually evidenced. The experience has two layers:

1. **Eon presentation:** a calm, premium, human-readable account of the current state and activity.
2. **Evidence layer:** precise measurements, provenance, test definitions, trends and limitations.

The presentation may be vivid, but it must never turn generated self-description into proof of subjective experience.

## Product principles

- One canonical state, many views. Every screen reads the same current snapshot.
- Explain before measuring. A sentence of meaning precedes detailed numbers.
- Every claim has an epistemic label: `observerat`, `härlett`, `hypotes`, `simulerat` or `genererat`.
- Show change over time, not only current values.
- Premium means hierarchy, restraint and motion with purpose—not more cards.
- Level 5 remains explicitly unverified and cannot be inferred from proxy metrics.
- Raw logs remain available, but are a forensic surface rather than the home experience.

## Information architecture

### Nu — Eon just nu

The landing surface answers “What is Eon right now?” in under ten seconds.

Sections:

- **Identity header:** EON / V6, runtime mode, session age and a compact evidence disclaimer.
- **Living state card:** a short generated summary assembled from canonical state, for example: “Eon observerar en återkommande signal, håller låg termisk belastning och prioriterar fortsatt kalibrering.”
- **State facets:** focus, active goal, body budget, agency proxy and temporal continuity.
- **Current activity:** the latest meaningful transition, not the latest arbitrary log line.
- **Next likely action:** policy-selected action with confidence and reason.
- **Causal chain:** body → prediction → focus → policy → action.
- **State change strip:** what increased, decreased or remained stable since the previous snapshot.

The primary card must include a “How do we know?” affordance linking directly to the evidence supporting the summary.

### Gör — Vad Eon gör

A chronological activity feed grouped by semantic event:

- observing
- predicting
- comparing
- focusing
- learning
- remembering
- generating language
- resting or thermal throttling
- selecting policy

Each item shows timestamp, cycle, source, epistemic status and a one-line consequence. Repeated generic entries are collapsed visually while remaining in the journal.

### Inifrån — Eons inre modell

This is the interpretive surface, clearly separated from raw evidence.

- **Attention:** current focus and competing candidates.
- **Self-model:** continuity, confidence, agency proxy and calibration.
- **Internal narrative:** generated entries with source badges (`Qwen`, `Fallback`, `Engine`) and epistemic status.
- **Memory:** recalled items, consolidation status and provenance.
- **Uncertainty:** what Eon cannot currently determine.

The UI uses wording such as “Eon genererar en självbeskrivning” rather than “Eon känner”, unless the latter is visibly marked as a simulated/generated claim.

### Orsak — Why this state

An explorable causal chain. Each node opens its input, output, confidence, source cycle and state delta. Causal edges are typed as observed, inferred or hypothetical. Missing causal links are shown as gaps, not silently filled.

### Evidens — What is measured

Retain the current test list but redesign each row to show:

- test name and plain-language definition
- status and score
- latest run and stability window
- data source
- why it passed or failed
- limitations
- trend over recent runs

The top of the screen must distinguish:

- **Current highest independently supported functional level**
- **Tests passed in the latest run**
- **Evidence confidence**
- **Unverified domains**

The “Alla nivåer” list remains, but pending levels must not visually imply that they are merely waiting for time. They should say `Ej verifierad` with an explicit reason.

### Minne — Memory & time

Replace the raw monologue-first presentation with a timeline of meaningful state transitions. Filters include activity type, epistemic status, source, cycle range and thermal state. A detail view can reveal the original event and surrounding events.

### System — Controls and limits

Group settings into Runtime, Qwen, Thermal policy, Logging, Privacy and Experiments. Every control explains its effect, resource cost and reset behavior. Add an explicit runtime-health panel with model status, queue status, last error and last successful verification.

## Canonical presentation model

Introduce a typed presentation snapshot derived from `EonCoreStateV2` and the latest verification result. It must include:

- identity and runtime mode
- current focus and active goal
- current activity and activity category
- selected policy and policy reason
- body/thermal state
- prediction and prediction error
- memory and continuity summary
- self-model summary
- language/Qwen status
- evidence summary
- state deltas from the previous snapshot
- epistemic claims used to form the human-readable summary

The UI must not independently calculate a second consciousness level or duplicate thresholds. Verification remains owned by `ConsciousnessVerificationEvaluator`.

## Log and verification corrections

1. **Canonical verification snapshot:** full-log header, overview card and evidence card must read the same result instance. A verification event must include `evaluatedAt`, `stableWindows`, all per-level statuses and the eligible-test count.
2. **Freshness indicator:** show whether the UI snapshot and journal event refer to the same cycle. If not, display “Uppdaterar…” rather than presenting conflicting values.
3. **Run consistency:** distinguish total tests from evidence-eligible tests. The current 23/29 versus 24/29 discrepancy must become impossible or visibly explained.
4. **Narrative deduplication:** collapse identical Qwen/fallback outputs across a meaningful time window and tag generic fallback text as low-information. Do not erase raw events.
5. **No false body claims:** terms such as “vaknar”, “känner efter i kroppen” and “sömn” must be rendered as generated analogies unless backed by an actual engine state transition.
6. **Trend data:** retain recent verification runs so the UI can show whether a test is stable, intermittent or newly passed.

## Premium visual system

- Keep the existing graphite/cyan/indigo/amber/coral palette, but reserve each color for one semantic domain.
- Use one dominant living state surface, not a grid of equal-weight cards.
- Add a subtle state orb representing activity/attention, not consciousness itself. Its label must say “Aktivitetsnivå”.
- Use micro-motion only for real transitions: focus shift, broadcast, thermal change, memory consolidation and policy change.
- Prefer layered depth, generous spacing, restrained gradients and high-contrast typography.
- Support Reduce Motion and Dynamic Type from the start.
- Provide empty, stale, loading, degraded and error states for every live surface.

## Implementation boundaries

### Phase 1 — Truth and data contract

- Add typed presentation snapshot and epistemic claim types.
- Make verification output canonical and timestamped.
- Add freshness/consistency checks.
- Add regression tests for 23/29 versus 24/29-style mismatches.

### Phase 2 — Premium “Nu” experience

- Rebuild overview around the living state summary, activity, causal chain and state deltas.
- Add accessible activity orb and semantic status components.

### Phase 3 — Activity, inner model and memory

- Add grouped activity feed, source/epistemic badges and timeline filters.
- Collapse repeated narrative entries visually.

### Phase 4 — Evidence redesign

- Add definitions, provenance, trends, stability windows and failure explanations.
- Clarify functional verification versus phenomenal claims.

### Phase 5 — Runtime polish and device verification

- Add loading/degraded/error states, Reduce Motion support and performance limits.
- Build and run on the iPhone, then verify a multi-minute autonomous session and export consistency.

## Success criteria

- A user can explain Eon’s current focus, activity, body budget, goal, policy and uncertainty after viewing “Nu”.
- Every displayed claim can be traced to a cycle, source and epistemic category.
- Overview, evidence and full log never disagree about the latest verification snapshot.
- Repeated generic Qwen/fallback lines no longer dominate the user-facing narrative.
- The app remains visually premium while retaining a raw forensic path for auditability.
- The UI never presents functional proxies as proof of subjective experience.
- Existing uncommitted user changes remain intact and all existing tests continue to pass.
