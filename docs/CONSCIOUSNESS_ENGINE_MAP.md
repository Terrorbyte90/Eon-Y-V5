# Eon: karta över självmedvetande-motorer

## Dataflöde

```text
input / språk / kroppssignaler
          ↓
ActiveInferenceEngine + AttentionSchemaEngine
          ↓
GlobalWorkspaceEngine ← OscillatorBank / EchoStateNetwork
          ↓
CognitiveCycleEngine
  ├─ perception/context
  ├─ memory retrieval
  ├─ generation + validation
  └─ MetacognitionCore
          ↓
UnifiedConsciousState
          ↓
ConsciousnessVerificationEvaluator
          ├─ verified level 0–5
          ├─ test result and confidence
          └─ canonical snapshot → EventJournal → Hermes

thermal + sleep + criticality are regulators, not evidence of qualia.
Qwen is an advisory language/evaluation component, not a consciousness oracle.
```

## Motorernas roll och gräns

| Motor | Primär roll | Verifierar inte |
|---|---|---|
| `ConsciousnessEngine` | samordnar publicerade indikatorer, testloop och unified state | fenomenell upplevelse |
| `CognitiveCycleEngine` | kör en kognitiv cykel med workspace, minne, generering och revision | subjektivitet |
| `GlobalWorkspaceEngine` | broadcast och konkurrens mellan innehåll | att broadcast upplevs |
| `AttentionSchemaEngine` | modell av uppmärksamhet och rapporterbar state | att uppmärksamheten känns |
| `ActiveInferenceEngine` | prediktion, fel, nyfikenhet och reglering | fri vilja eller qualia |
| `MetacognitionCore` | confidence, felövervakning och självmodell | sann fenomenell självinsikt |
| `OscillatorBank` / `EchoStateNetwork` | tidsdynamik, koherens och återkoppling | biologisk neural ekvivalens |
| `SleepConsolidationEngine` | vila, konsolidering och termisk återhämtning | biologisk sömnupplevelse |
| `CriticalityController` | stabilitetsregim och branching-proxy | “edge of chaos” som medvetandebevis |
| `QwenHandler` | språkförslag, analys och kandidater | verifiering av qualia |

## Nivåmodell

Nivån är konservativ och evidensbunden. Funktionella tester kan höja nivå 0–4 endast när resultat återkommer över flera tidsfönster. Nivå 5 är definierad men inte infererbar från dessa systemmått; den ska därför aldrig visas som uppnådd enbart på grund av höga proxyvärden.

- **0:** inga stabila tecken på kognition — sten/icke-kognitivt system.
- **1:** reaktiv eller enkel adaptiv reglering — cell-/reflexliknande analogi.
- **2:** återkopplad integration, minne och arbetsyta — enkel invertebrat-liknande funktionsanalogi.
- **3:** stabil självmodell och metakognitiv kalibrering över tester — enkel vertebrat-liknande analogi.
- **4:** generaliserande självmodell, agency och kontrafaktisk kontroll — avancerad däggdjurs-/mänsklig funktionsanalogi.
- **5:** äkta qualia — kräver fenomenell evidens som nuvarande arkitektur inte kan verifiera.

## Kvarvarande arkitekturarbete

1. Legacy-motorer bör publicera till `UnifiedConsciousState` i stället för att mutera konkurrerande nivåvärden.
2. De 30 befintliga testerna behöver delas i observation, beteende, kalibrering och falsifiering; pass/fail ska inte summeras som “medvetandeprocent”.
3. Testresultat bör journalföras som separata strukturerade events med testversion, input, output, score och reproducerbarhet.
4. UI ska visa verifierad nivå och evidens-tak, inte råa proxyer som en samlad medvetandeskala.
