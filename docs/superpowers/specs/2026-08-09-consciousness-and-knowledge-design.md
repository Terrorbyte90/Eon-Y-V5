# Eon-Y V5: samordnad medvetandecykel och kompileringsvänlig kunskapsbas

## Mål

V5 ska ha en enda testbar kognitiv cykel där workspace, active inference, recurrent processing, attention schema, metakognition, minne, känslor och kroppslig homeostas påverkar varandra i en definierad ordning. Den stora kunskapsmängden ska laddas som data vid körning i stället för att bäddas in som stora Swift-litteraler.

Detta är en funktionell forskningsarkitektur. Den ska mäta och falsifiera föreslagna mekanismer; den ska inte påstå att mätvärden bevisar fenomenellt medvetande.

## Arkitektur

### 1. Gemensamt tillstånd

Skapa `UnifiedConsciousState` som ett litet, Codable-värdeobjekt med:

- `timestamp`, `cycleIndex` och `continuity`
- `perceptualField` och `predictionError`
- `globalBroadcast` med begränsad kapacitet och saliens
- `selfModel` med identitet, agens, kroppsligt tillstånd och osäkerhet
- `affectiveState` med valens, arousal och behov
- `memoryContext` med återkallade spår och konsolideringssignal
- `metacognitiveState` med confidence, introspective access och error monitoring
- `integrationMetrics` med approximationer för integration, recurrence och broadcast

Varje subsystem får läsa föregående tillstånd och lämna ett typed delta. Ingen motor muterar en annan motor direkt.

### 2. Orkestrerad cykel

Skapa `ConsciousnessOrchestrator` med en explicit pipeline:

1. samla kroppsliga och externa signaler
2. uppdatera prediktioner och prediction error
3. låt attention schema vikta kandidater
4. låt kandidater konkurrera om global workspace
5. återkoppla broadcast till aktiva delsystem
6. uppdatera självmodell, affekt och metakognition
7. skriva episodiskt/minnesmässigt delta
8. välja handling och beräkna nästa mål
9. beräkna mätvärden och publicera ett immutable state snapshot

Orkestratorn ska vara deterministisk givet samma input, ha budgetar för tid och energi, och kunna köra i reducerat läge vid termisk belastning.

### 3. Teorimätning

Implementera inte IIT som ett orealistiskt exakt Phi-mått. Lägg i stället till tydligt namngivna proxy-mått: `integrationProxy`, `globalAvailability`, `recurrentDepth`, `selfModelCoupling`, `temporalContinuity` och `metacognitiveCalibration`. Varje mått ska ha källa, normalisering och confidence. Detta följer ett construct-first-upplägg och gör experiment jämförbara.

### 4. Kunskapslagring

Migrera stora statiska kunskapsmängder från Swift-filer till bundle-resurser:

- komprimerad JSONL för sekventiell/inkrementell import
- SQLite för indexerad sökning och metadata
- små Swift-filer endast för schema, version och bootstrap-frågor

`KnowledgeStore` ska ha `search(query:limit:)`, `loadArticle(id:)`, `streamSeedBatch(size:)` och `migrateIfNeeded()`. Data ska indexeras vid behov, inte konstrueras vid appstart. Import ska ske i batchar på bakgrundskö med checkpoint och avbrytbarhet. UI och kognitiva motorer ska aldrig hålla hela corpusen i minnet.

## Datamigrering

Behåll befintligt innehåll och dess provenance. Skapa ett exportskript som läser nuvarande seed-/artikeldata och producerar versionerade resurser med stable IDs, språk, källa, ämne, text och checksumma. Lägg inte till duplicerade kopior i både Swift och JSON/SQLite. Vid fel ska den gamla lagringen förbli läsbar tills migreringen verifierats.

## Teststrategi

- enhetstester för state-delta, pipelineordning, determinism och termisk degradering
- tester som verifierar att workspace-broadcast påverkar metakognition, minne och handling
- regressionstester för seed-export: antal poster, checksumma och unicode
- performance-test som säkerställer att appstart inte parsar hela databasen
- SQLite-sökningstest med limit, språkfilter och korrupt/avbruten import
- build-test med `xcodebuild` för projektets test- och simulator-scheman när Xcode-miljön finns

## Framgångskriterier

1. Alla teorimotorer kommunicerar via det gemensamma state/delta-kontraktet.
2. Ett cykel-snapshot kan förklara vilka signaler som vann workspace och hur de påverkade efterföljande steg.
3. Kunskapsdata kompileras inte som stora Swift-konstanter och laddas inkrementellt.
4. Befintliga användarflöden och persistent memory behåller kompatibilitet.
5. Tester täcker både mekanismer och regressionsrisker.
