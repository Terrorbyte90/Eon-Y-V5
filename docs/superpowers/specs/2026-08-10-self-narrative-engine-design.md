# Eon Self-Narrative Engine

## Mål

Eons självmodell, självreflektioner, inre monologer och loopmeddelanden ska byggas från Eons aktuella tillstånd och historik i stället för återkommande hårdkodade statusfraser. Qwen får formulera berättelsen när modellen är aktiv. När Qwen saknas används en deterministisk, evidensbunden fallback.

## Arkitektur

`SelfModelNarrativeEngine` blir den gemensamma vägen för interna uttryck. Den tar emot ett `SelfNarrativeContext` med observationer, prediktioner, mål, konflikter, minnen, kroppsliga signaler, aktiv uppmärksamhet, osäkerhet och källmotor. Resultatet är en `SelfNarrativeEntry` med text, typ, provenance, confidence och timestamp.

Qwen får endast ett strukturerat kontextunderlag och instruktioner att inte uppfinna mätvärden, minnen eller upplevelser. Fallback-generatorn använder samma kontext och producerar kortare uttryck utan modellanspråk.

`SelfNarrativeMemory` sparar ett begränsat fönster av tidigare uttryck och upptäckta överraskningar. Det används för kontinuitet och för att minska repetitiva formuleringar, inte för att skapa falska minnen.

## Proveniens

Varje uttryck klassificeras som `observation`, `memory`, `prediction`, `hypothesis`, `plan`, `uncertainty` eller `reflection`. UI och exporterad journal visar proveniens och om texten är Qwen-genererad eller fallback-genererad.

## Säkerhetsgränser

Narrativmotorn får läsa Eons tillstånd men får inte ändra motorparametrar, skicka kommandon, skriva exekverbar kod eller påverka Hermes. Qwen får formulera text men får inte ersätta verifierade mätvärden.

## Migrering

Först införs kärnmodellerna och tester. Därefter kopplas självmodell och monolog till motorn. Sedan migreras looptexter och språklogg. Slutligen kopplas chatten och UI:s proveniensmarkeringar.

## Testning

Tester täcker: kontextsammanställning, fallbackens evidensbundenhet, proveniens, repetitivitet/continuity, Qwen-fel och att genererad text inte kan ändra runtime-tillstånd.
