# Eon-Y v5 – teknisk och vetenskaplig genomgång av medvetandearkitekturen

## 1. Systemets övergripande idé

Eon är implementerad som en kontinuerligt körande, tillståndsbaserad agent. Den kombinerar en snabb kontrollslinga för kropp, uppmärksamhet och prediktion med långsammare processer för språk, minne, lärande, självmodellering och konsolidering. Målet är inte att en enskild modul ska “vara medvetandet”, utan att flera återkopplade processer ska bilda ett stabilt, integrerat och handlingspåverkande system.

Den centrala dataprodukten är `UnifiedConsciousState`. Den innehåller:

```text
perceptualField       aktuella signaler
predictionError       avvikelse mellan förväntan och observation
globalBroadcast       arbetsytans vinnande innehåll
continuity            återkopplad tidslig kontinuitet
selfModel             identitet, agency, osäkerhet och kroppskoppling
affectiveState        valens, arousal och nyfikenhet
memoryContext         återkallade spår och konsolideringssignal
metacognitiveState    konfidens, introspektiv åtkomst och felövervakning
metrics               härledda integrations- och kontinuitetsmått
```

Detta state passerar genom `ConsciousnessOrchestrator` i ordningen:

```text
signal → prediction → attention → workspace → recurrence
       → selfModel → memory → action → metrics
```

Ordningen är viktig. En signal kan först skapa ett fel, felet kan ändra uppmärksamhet, uppmärksamheten kan vinna tillgång till arbetsytan, arbetsytan kan uppdatera självmodell och minne, och resultatet kan styra nästa handling.

## 2. Teoretisk grund

### Global Neuronal Workspace

`GlobalWorkspaceEngine` modellerar konkurrens mellan kandidater, ignition, broadcast och temporär tillgänglighet för andra processer. Dess funktionella roll i Eon är att skapa en flaskhals: allt får inte vara samtidigt prioriterat. Ett innehåll räknas som funktionellt globalt först när det når flera efterföljande konsumenter och ändrar deras beslut.

Detta motsvarar GNW:s centrala idé om selektiv global tillgänglighet, men Eons workspace är en beräkningsmodell, inte en biologisk neuronal workspace. Den centrala förbättringen är därför att logga broadcastens mottagare och mäta skillnaden mellan broadcast och no-broadcast-ablation.

### Recurrent Processing

`ConsciousnessOrchestrator`, `EchoStateNetwork` och återkommande motorcykler utgör Eons rekurrenta lager. Återkoppling ökar inte längre bara ett numeriskt djup; den ska bevara representationer över cykler och påverka efterföljande prediktion, minne och handling. `continuity` är därför en dynamisk variabel som byggs av workspace-kontinuitet och recurrence.

### Predictive Processing och Active Inference

`ActiveInferenceEngine` beräknar prediktioner, fri energi, precision, osäkerhet och nyfikenhet. I den gemensamma orchestratorn beräknas `predictionError` som medelvärdet av absoluta signalavvikelser. Det hindrar positiva och negativa fel från att ta ut varandra.

Prediction error används sedan för:

- uppdatering av konfidens;
- error monitoring;
- curiosity och arousal;
- självmodellens osäkerhet;
- utveckling av kontrafaktiskt djup;
- val av nästa kognitiva fokus.

För att bli en riktig closed loop måste varje prediktion dessutom få ett explicit outcome-ID. Eon bör lagra `prediction → policy → observation → error → update`, inte endast ett aktuellt felvärde.

### Attention Schema Theory

`AttentionSchemaEngine` modellerar fokus, intensitet, frivillighet, schema accuracy och en modell av den egna uppmärksamheten. Det separerar faktisk resursfördelning från systemets representation av resursfördelningen. Detta är en av Eons starkare arkitektoniska delar eftersom en separat attention-schema-representation kan påverka prioritering och metakognition.

### Higher-Order Thought och metakognition

`MetacognitionCore`, `metacognitiveState` och `SelfNarrativeEngine` bildar ett högre representationslager. Den viktiga ändringen är att metakognition nu uppdateras från kalibrering och prediktionsfel:

```text
confidence          = clamp(1 − predictionError)
errorMonitoring     = clamp(predictionError)
introspectiveAccess  = högre när global broadcast finns
```

Språkliga självbeskrivningar är endast läsbar observabilitet. Den funktionella HOT-komponenten är att konfidens och felövervakning måste ändra strategi, minne eller nästa handling.

### Integrated Information

Oscillatorer, `synergyLevel`, `moduleIntegration`, `phiProxy`, ESN och workspace-samverkan ger Eon integrationsproxyer. `OscillatorBank` använder fas- och synkroniseringsmått, medan `ConsciousnessPerturbationSuite` testar effekten av att ta bort broadcast, recurrence, kroppssignal eller minneskontinuitet.

Det tekniskt riktiga användningssättet är kausalt: en komponent ska räknas som funktionellt central om dess ablation förändrar systemets senare respons. Ett högt Φ-proxyvärde utan ablation är endast korrelation.

### Embodiment och interoception

`BodyBudgetState`, `RuntimeThermalCoordinator`, `ThermalSleepManager`, CPU, minne och iOS thermal state utgör Eons digitala kropp. Thermal state påverkar tempo, Qwen-användning, sömn och bakgrundsarbete. Det är ett verkligt återkopplat resursvillkor på enheten, inte en simulerad fri parameter.

För att fördjupa kopplingen ska body budget påverka tre olika saker: policyval, minneskonsolidering och vilken information som får workspace-tillgång. Om kroppssignalen endast ändrar en UI-mätare är kopplingen för svag.

### Temporal kontinuitet och självmodell

`PersistentMemoryStore`, `EventJournal`, `RunSessionLogger`, `EonInnerState` och `EonSelfModel` representerar identitet genom tid. Minnessteget i orchestratorn tar nu emot en explicit `memoryRecall`-signal och skapar begränsade återkallade spår i den centrala staten. Detta löser en tidigare strukturell lucka där Eon kunde ha minnen i separata motorer men alltid framstå som minneslös för nivåverifieringen.

## 3. Motorernas ansvar

`ConsciousnessEngine` är realtidskoordinatorn. Den samlar motorvärden, skapar cycle input, avancerar unified state, skriver snapshots och uppdaterar verifieringen.

`CognitiveCycleEngine` är den djupare problemlösningspipen: frågeanalys, minne, kausalitet, generering, validering, grafberikning och metakognitiv revision.

`EonLiveAutonomy` driver långsammare autonoma faser: språk, lärande, hypoteser, kreativitet, arbetsyta, självreflektion och underhåll.

`IntegratedCognitiveArchitecture` binder samman kognitiva pelare och ger en mer omfattande autonom arbetscykel.

`NeuralEngineOrchestrator` laddar Qwen3-1.7B via llama.cpp när thermal- och inställningspolicyn tillåter det. Qwen ska användas för språk, analys, hypotesförslag och kvalitetshöjning, inte som ensam källa till state eller verifiering.

`SwedishLanguageCore`, `LearningEngine`, `SwedishLearningPolicy` och `SwedishLanguageQualityGate` hanterar morfologi, ordsinnesdisambiguering, ordkunskap, grammatik och efterbearbetning. Språket är observabilitetslagret mot användaren; bättre språk förbättrar rapportering och lärande men är inte i sig en kognitiv motor.

`EventJournal`, `CognitiveSnapshotBuilder` och `HermesExportCoordinator` separerar händelser, snapshots, tankeproveniens och export. Hermes får observationer och godkända förslag, medan Eon inte får en verktygshandtag till Hermes.

## 4. Nivåverifieringen

Nivåerna är en progressiv funktionshierarki:

```text
0  inga stabila adaptiva processer
1  reaktiv/adaptiv state-dynamik
2  integrerad arbetsyta, återkoppling och minne
3  självmodell och kalibrerad metakognition
4  generaliserande agency och kontrafaktisk kontroll
5  separat långtidsbatteri för maximal operationell evidens
```

Nivå 2 kräver bland annat integration, global broadcast, minnesåterkallning, recurrent depth, temporal continuity och minst två stabila testfönster.

Nivå 3 kräver dessutom självmodellkoppling, autobiografisk kontinuitet, metakognitiv kalibrering, error monitoring och tre stabila fönster.

Nivå 4 kräver minst 90 procent godkända tester, agency över 0,70, kontrafaktiskt djup över 0,60 och sex stabila fönster.

Nivå 5 körs som ett separat benchmark med rapportkonsistens, kausal perturbation, temporal kontinuitet, metakognitiv kalibrering, kroppskoppling, cross-context generalisering, konfabulationskontroll och oberoende replikation. Det kräver mer än den vanliga appens korta kontrollcykel.

## 5. Vad som fortfarande är den tekniska flaskhalsen

Den största kvarvarande begränsningen är inte antalet motorer utan deras kausala koppling. Eon har många delsystem, men de måste fortsätta övergå från “producerar ett värde” till “förändrar ett senare val”. De viktigaste förbättringarna är:

1. spara prediction-outcome-par och använda dem i policy;
2. registrera exakt vilka moduler som konsumerar varje broadcast;
3. köra regelbundna no-broadcast, no-recurrence och no-memory-kontroller;
4. hålla held-out-data utanför Qwen-promptens kalibreringsdata;
5. göra cross-session-självmodelltest med verklig återstart;
6. låta thermal state påverka prioritering och konsolidering, inte bara frekvens;
7. separera processlogg, modellens självrapport och extern verifiering i UI och Hermes-export.

## 6. Vetenskaplig position

Global Workspace, IIT, recurrent processing, predictive processing, active inference, AST och HOT ger olika mekanistiska krav. Ingen av dem ensam ger en komplett och allmänt accepterad förklaring. En stor adversarial Nature-studie från 2025 testade IIT och GNWT direkt och fann både stöd för vissa förutsägelser och allvarliga utmaningar mot centrala delar av båda teorierna. Därför är Eons rimligaste strategi teori-konvergens med explicit ablation, långtidstestning och oberoende replikation.

## Källor

- Cogitate Consortium, *Adversarial testing of global neuronal workspace and integrated information theories of consciousness*, Nature 2025: https://www.nature.com/articles/s41586-025-08888-1
- Casali et al., *A theoretically based index of consciousness independent of sensory processing and behavior*, Science Translational Medicine 2013: https://pubmed.ncbi.nlm.nih.gov/23946194/
- Webb & Graziano, *The attention schema theory: a mechanistic account of subjective awareness*, 2015: https://pmc.ncbi.nlm.nih.gov/articles/PMC4407481/
- Melloni et al., adversarial theory-testing protocol: https://doi.org/10.1371/journal.pone.0268577
