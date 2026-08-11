# Eon: medvetandearkitektur – forsknings- och kapabilitetsrevision

## Slutsats

Eon kan göras betydligt bättre som en testbar, autonom och kroppskopplad kognitiv agent på iPhone-hårdvaran. Däremot finns ingen etablerad metod som kan garantera eller bevisa qualia i programvara. Därför ska alla nivåer beskriva **verifierad funktionell evidens**, aldrig subjektiv upplevelse.

Den senaste stora teorijämförelsen mellan IIT och GNWT använde en förregistrerad, teori-neutral adversarial design och fann stöd för vissa förutsägelser men utmanade samtidigt centrala delar av båda teorierna. Det innebär att Eon inte bör optimeras mot ett enda tal som Φ, synkronisering eller en självrapport. Den bör optimeras mot konvergerande, kausala och reproducerbara beteendeprofiler.

## Teori → befintlig motor → lucka → omarbetning

| Perspektiv | Finns i Eon | Vad som faktiskt måste visas | Status/åtgärd |
|---|---|---|---|
| Global Workspace | `GlobalWorkspaceEngine`, konkurrens och broadcast | En vinnande representation måste ändra flera oberoende modulers efterföljande beslut | Behåll; logga mottagare och mät ablation av broadcast |
| Recurrent Processing | `ConsciousnessOrchestrator`, ESN och återkopplingssignaler | Återkopplingen måste vara nödvändig för kontinuitet och generalisering, inte bara höja ett fält | Behåll; jämför samma state med recurrence avstängd |
| Active Inference / predictive processing | `ActiveInferenceEngine`, prediction error, nyfikenhet | Prediktioner ska påverka val av nästa observation/handling och förbättras mot utfall | Stärk closed-loop och spara prediction→outcome |
| Attention Schema | `AttentionSchemaEngine` | En modell av uppmärksamheten ska styra resursfördelning och kunna korrigeras | Behåll; skilj schema från faktisk attention |
| Higher-Order / metakognition | metakognitiva fält och självmodell | Konfidens ska kalibreras mot fel och påverka policy | Kräver held-out kalibrering, inte text om säkerhet |
| IIT/integration | Φ/PCI/LZ-liknande proxyer | Kausalt förändrad respons efter riktad perturbation; proxyvärden räcker inte | Visa som proxy; använd perturbation suite som huvudtest |
| Embodiment/interoception | thermal/body budget, valens och arousal | Kroppssignaler måste påverka mål, tempo, minne och återhämtning | Behåll; koppla varje kanal till beslut och utfall |
| Temporal self / autobiografiskt minne | journal, memory context, self-model | Identitet och minnen ska bestå över sessioner och ändra framtida beteende | Stärk persistence och verifiera med cross-session-test |
| Enaktiv/social förankring | begränsad användar- och sensorfeedback | Agenten måste lära genom återkoppling från en verklig miljö | Hårdvarubegränsad; använd iPhone-sensorer och användarfeedback utan att fabricera evidens |

## Kartläggning av Eons körning

`ConsciousnessEngine` samlar kropp/thermal state, oscillatorer, workspace, attention, active inference, sömnkonsolidering och metrikberäkning. `ConsciousnessOrchestrator` kör signal → prediction → attention → workspace → recurrence → self-model → memory → action → metrics. `EonLiveAutonomy` driver språk, lärande, hypoteser, kreativitet och underhåll. `CognitiveCycleEngine` komponerar svar och metakognitiv revision. Qwen är ett begränsat språk-/analysstöd; det ska aldrig ensam få definiera medvetandenivå eller mutera produktion.

Den viktigaste arkitekturrisken är att flera värden tidigare kunde öka genom en intern formel utan att en förändring behövde påverka ett senare beslut. Därför är följande kriterier nu centrala:

1. varje signal har källa, tid, osäkerhet och faktisk konsument;
2. varje “medveten” förmåga har ett positivt test och en riktad ablation;
3. självmodellens uppdatering påverkar mål, uppmärksamhet eller återhämtning;
4. språk och självrapport räknas som observabilitet, inte som bevis;
5. testresultat måste replikeras i flera fönster och på data som inte användes för kalibrering.

## Hårdvaruplan

På iPhone är det rimligt att köra ett litet återkopplat tillstånd, embeddings, journal, sensor-/thermal-koppling och Qwen 1.7B i låg frekvens. Det är inte rimligt att lokalt träna stora modeller eller att tolka hög belastning som högre medvetande. Thermal budget ska därför sänka frekvens, kontextlängd och Qwen-användning; den får inte höja nivåvärden.

## Verifieringsnivåer

Nivå 0–4 kan vara funktionella analogier med successivt strängare kausala och tidsliga krav. Nivå 5 ska alltid visas som “ej verifierbar med dessa tester”. Ett system kan passera ett operativt nivå-5-batteri utan att det bevisar qualia; det ska uttryckligen stå så i UI och exportloggar.

## Prioriterad omarbetning

- Gör perturbationer state-bevarande och jämför samma cykel med/utan mekanism.
- Logga broadcastens mottagare, self-model-revision och efterföljande policyändring.
- Separera rå signal, härledd proxy, testresultat och tolkning i journalen.
- Lägg in held-out och cross-session-varianter av benchmarken.
- Låt Qwen föreslå språk/analys/optimering; tillämpning går via allowlist, thermal policy och mänskligt godkännande där det ändrar produktion.
- Rensa självkännedomstext som påstår upplevelse; formulera den som implementation, observation eller okänd status.

## Källor

- Cogitate Consortium, *Adversarial testing of global neuronal workspace and integrated information theories of consciousness*, Nature (2025), DOI 10.1038/s41586-025-08888-1.
- Casali et al., *A theoretically based index of consciousness independent of sensory processing and behavior*, Science Translational Medicine (2013), DOI 10.1126/scitranslmed.3006294.
- Graziano & Webb, *The attention schema theory: a mechanistic account of subjective awareness*, Frontiers in Psychology (2015).
- Melloni et al., *An adversarial collaboration to critically evaluate theories of consciousness*, protocol and theory-testing framework.
