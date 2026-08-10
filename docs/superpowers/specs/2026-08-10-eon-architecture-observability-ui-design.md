# Eon V5: sammanhållen arkitektur, observability och operatörs-UI

## Mål

Göra Eon lättare att förstå, mäta, felsöka och vidareutveckla utan att påstå att proxy-mått bevisar medvetande eller qualia. Alla motorer ska bidra via ett gemensamt, versionsbart cykelsnapshot och händelseflöde. Hermes ska få en komplett men kostnadskontrollerad journal som kan återskapa vad Eon gjorde, vilka signaler som användes och vilka beslut som togs.

## Nulägesproblem

- Autonomi, medvetandecykel och språkcykler har flera separata timers och delvis överlappande ansvar.
- Monologen blandar systemhändelser, mätvärden, genererad text, hypoteser och påståenden i samma lista.
- Mätetal visas med starka etiketter som “medveten” eller “kritisk” trots att de är modellproxyer.
- Run-, cognition- och diagnosticsloggar har olika format och saknar ett gemensamt event-ID/cykel-ID.
- UI-vyerna presenterar samma tillstånd på flera sätt och Projekt-vyn är inte längre central.
- Qwen är tillgänglig som modellmotor men saknar en tydlig, auditerad roll som intern rådgivare/optimerare.
- Hermes-bron måste kunna skicka komplett data utan att Eon kan skicka kommandon eller exekverbart innehåll.

## Föreslagen arkitektur

### 1. Canonical cognitive state

Inför en `CognitiveSnapshot` som enda presentations- och exportkontrakt. Den innehåller:

- `schemaVersion`, `sessionID`, `cycleID`, `timestamp` och `runtimeMode`
- `inputs`: externa signaler, användarinput, thermal/battery/memory och datakällor
- `workspace`: kandidater, vinnande broadcast, saliens och återkopplings-ID
- `selfModel`: agens-, identitets-, kropp- och osäkerhetsvärden
- `affect`, `memory`, `metacognition` och `languageState`
- `theoryProxies`: varje proxy med värde, normalisering, confidence, källa och giltighetsvarning
- `motorStates`: status, duration, input/output event-ID och thermal budget per motor
- `qwen`: loaded/unloaded, tokens, latency, purpose, prompt hash och result summary; aldrig rå intern chain-of-thought i Hermes-journalen
- `claims`: maskinläsbara påståenden med evidensnivå (`observed`, `inferred`, `hypothesis`, `simulated`)

Motorer får inte skriva direkt i UI-state. De producerar typed `CognitiveDelta` och `CognitiveEvent` som orkestratorn reducerar deterministiskt till snapshot.

### 2. Cykelorkestrering

`ConsciousnessOrchestrator` blir den enda ägaren av cykelordningen:

1. samla signaler och budgetar
2. prediktion/prediktionsfel
3. attention-schema och kandidatpool
4. workspace-konkurrens och broadcast
5. återkoppling till minne, språk, affekt och självmodell
6. metakognition och felkalibrering
7. val av nästa arbetsfas
8. proxy-mätning och confidence
9. snapshot + event journal

Nuvarande autonoma loopar migreras stegvis till orkestratorn. Under migrationen får gamla motorer adapteras, men en motor får bara startas en gång och ska kunna stoppas. Thermal coordinator äger global degradering.

### 3. Event journal och Hermes-export

Skapa en append-only journal i JSONL med roterade segment:

- `events/YYYY-MM-DD/session-<id>/part-000001.jsonl.zst` eller gzip där komprimering är tillgänglig
- `snapshots/YYYY-MM-DD/session-<id>/snapshot-<cycle>.json`
- `indexes/YYYY-MM-DD/session-<id>.index.json`
- manifest med schema, checksumma, antal event, tidsintervall och exportstatus

Eventnivåer:

- `lifecycle`, `motor`, `workspace`, `memory`, `language`, `qwen`, `measurement`, `thermal`, `error`, `user`

Varje event har `eventID`, `sessionID`, `cycleID`, monotonic sequence, timestamp, source, severity, payload schema och provenance. Rå text begränsas och separeras från strukturerade data. Fullständig lokalloggning ska vara standard; Hermes får batchar med byte-/tidsbudget, exempelvis var 60:e sekund eller vid 256 KB, samt omedelbart vid error/thermal transition.

Hermes tar endast emot signerad data och kan aldrig skicka kommando, prompt, kod, URL eller parameterändring direkt till Eon. Qwen-förslag från Hermes behandlas som verifierade kunskapsdata eller experimentförslag och måste passera lokal policy/allowlist.

### 4. Qwen som intern rådgivare

Qwen får tre explicita roller:

- `languageCoach`: föreslår språk-/lexikonuppdateringar med provenance
- `evaluator`: analyserar snapshots och föreslår testbara hypoteser
- `optimizer`: föreslår parameterändring i sandboxad experimentprofil

Qwen får inte själv ändra produktionsvikter, nätverkskonfiguration, Hermes-policy eller köra verktyg. Varje förslag har input snapshot-ID, anledning, expected effect, risk, budget och acceptansstatus. Autonom körning begränsas av thermal/memory och en lokal policy.

### 5. Mätningar

Visa inte ett enda “medvetandenivå”-tal som sanning. Samla mätningar i fyra grupper:

- **Runtime:** thermal, CPU, memory, battery, model latency, tokens/s
- **Cognitive dynamics:** continuity, prediction error, workspace availability, recurrence, metacognitive calibration
- **Learning/language:** vocabulary coverage, morphology accuracy, retrieval hit rate, calibration, repetition rate
- **Theory proxies:** IIT-inspired integration proxy, GNW availability proxy, recurrent processing, HOT depth, predictive-processing/free-energy proxy och self-model coupling

Varje mätning visar definition, källa, confidence, tidsfönster och om värdet är observerat eller härlett. UI:t ska kunna visa trend, senaste värde och varning om datakvalitet.

### 6. UI och navigation

Ta bort Projekt-fliken. Ersätt den med `QwenLabView` för språk, utvärdering, experimentförslag och modellstatus. Föreslagen navigation:

- Hem: aktuell status, senaste beslut, thermal och kort trend
- Chatt: användarsamtal med tydlig käll-/confidence-markering
- Språk: språkpipeline, dataimport och förbättring
- Qwen: roller, kö, experiment och modellkontroller
- Medvetande: snapshot, teori-proxyer, workspace, självmodell och trender
- Kunskap: corpus, provenance, import och indexstatus
- Profil: inställningar, logg/export, integritet och diagnostik

Monologen delas i `Observationer`, `Beslut`, `Hypoteser`, `Minne`, `Qwen-förslag` och `System`. Varje rad visar källa, cycle/event-ID, confidence och om texten är genererad eller direkt observerad. Upprepade identiska rader dedupliceras visuellt men finns kvar i journalen.

### 7. Inställningar

Samla inställningar i sektionerna Runtime, Qwen, Hermes, Logging, Privacy och Experiments. Alla inställningar ska ha default, effekt, thermal-konsekvens och återställning. Hermes-URL/key material ska vara read-only i UI efter provisioning; inga fria fjärrkommandon eller godtyckliga endpointfält.

## Test- och verifieringsstrategi

- reducer-test för snapshot/delta och deterministisk cykelordning
- schema-/round-trip-test för events, snapshots och manifest
- journaltest med rotation, bytebudget, avbrott och återupptagning
- säkerhetstest som bevisar att inkommande data inte kan bli kommando eller prompt
- Qwen policytest för allowlist, thermal guard och sandboxad experimentprofil
- UI-test för navigation, empty/error states och långa loggar
- simulator-test med åtminstone 5 minuters autonom körning och crash-loggkontroll
- fysisk enhetstest med modell unload/load, thermal transition och bakgrunds-/förgrundsbyten

## Implementationsordning

1. Canonical event/snapshot schemas och adapters utan UI-förändring.
2. Gemensam journal, rotation, manifest och Hermes batching.
3. Orkestratorns lifecycle/thermal contract och deduplicerad monologmodell.
4. Mätkatalog med definitioner/confidence/trender.
5. QwenLab och säker autonom rådgivningsloop.
6. Navigation, vyer, inställningar och svenska texter.
7. Full verifiering, crash-fixar och ny archive.

## Framgångskriterier

- En cycleID kan följas från input via motorer och workspace till snapshot, monolog och Hermes-event.
- Hermes kan rekonstruera hela körningen utan att få kommandorättigheter.
- UI:t visar samma canonical state som exporteras.
- Alla påståenden om medvetande är märkta som observation, härledning, hypotes eller simulering.
- Qwen bidrar autonomt inom en lokal, auditerad och termiskt säker policy.
- Appen kan köra minst fem minuter i simulator utan crash och med kontrollerad minnes-/termalprofil.
