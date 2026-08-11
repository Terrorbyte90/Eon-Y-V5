# Eon v6 — Causal Phenomenology

V6 introduces a canonical state layer and a redesigned observability-first UI.

## Runtime boundary

The v6 state is `EonCoreStateV2`. Prediction records, precision, body pressure, affect, policies and causal edges are typed and bounded. The v6 runtime samples the existing engines without allowing the language layer to write into canonical state.

```text
existing engines → V6 read/sampling boundary → EonCoreStateV2
                                              ↓
                            evidence + causal observability
                                              ↓
                                    SwiftUI V6 surfaces
```

Qwen is represented by `EonLanguageReporter` as a read-only language boundary. Its result is a `EonLanguageProposal` with linguistic provenance and a source cycle.

## UI

The old seven-tab navigation is replaced by five focused surfaces:

- Nu: current state, causal chain and body budget.
- Inifrån: epistemic field, affect and language boundary.
- Evidens: theory families, stability and laboratory controls.
- Minne: timestamped, provenance-labelled internal traces.
- System: Qwen, thermal policy, Hermes export and experiments.

The visual language is a dark observatory: graphite surfaces, cyan system signal, indigo integration, amber policy and coral body pressure. The interface prioritizes “what is happening now?” and keeps state, evidence and generated language separate.

## Next migration boundary

The first v6 slice is intentionally additive. The next integration step is to replace sampling with a single producer that advances `EonCoreStateV2` from real prediction/outcome records, then route existing workspace, memory and thermal consumers through that state. This keeps the v5 runtime recoverable while v6 is validated.
