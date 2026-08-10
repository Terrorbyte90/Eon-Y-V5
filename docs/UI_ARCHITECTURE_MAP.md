# Eon UI-karta och konsolideringsregler

## Huvudnavigation

| Flik | Ansvar | Ska inte göra |
|---|---|---|
| Hem | aktuell drift, termik, senaste händelser och snabb väg till full logg | vara en andra dashboard |
| Chatt | användarens samtal och svar | visa hela motorns interna diagnostik |
| Språk | språkdata, språkförvärv och pipeline | hävda att språkaktivitet är medvetande |
| Qwen | auditerade Qwen-uppgifter och förslag | ändra produktion eller kontakta Hermes |
| Medvetande | proxy-mätningar, teoriinstrument och motorstatus | kalla proxyer för qualia eller bevis |
| Kunskap | källbelagd kunskap, genererat material och import | blanda källa med modellgenerering |
| Profil | inställningar, resurser, säkerhet och historik | duplicera live-dashboarden |

## Underflöden

- Hem → Full logg: tidslinje och exportstatus.
- Hem → Runtime: termik, minne och motorhälsa; endast en runtime-destination.
- Medvetande → Live: samlad motorbild; Motor Room är för manuella diagnostikdetaljer.
- Kunskap → Artikel/Add/Import: källmaterial och granskningsstatus.
- Profil → Inställningar/Automation/Resurser/Om: konfiguration och historik.

## Konsolideringsregler

1. Ett värde visas med en definition, källa och epistemisk status.
2. `observed`, `inferred`, `hypothesis` och `simulated` ska synas där tolkningen spelar roll.
3. En vy får inte ha en egen konkurrerande “medvetandenivå”.
4. Genererad text är bearbetningsspår, inte direkt åtkomst till upplevelse.
5. Alla åtgärder som kan ändra motorer eller kunskap visar scope och kräver policy/behörighet.
6. Legacy-vyer behålls endast om de har en unik underfunktion; annars länkas de till den samlade destinationen.

## Identifierade dubbletter

- SmartDash och SuperView var överlappande helhetsdashboards. Hem öppnade dessutom samma RuntimeDashboard från två olika bokstäver; detta är nu en enda route.
- MindView är äldre och delvis inbäddad i Språk/Creative. Den ska inte vara en parallell huvuddestination.
- ProgressView och SmartDash visar överlappande utvecklingsvärden och ska på sikt dela datakälla/komponent.
- FullLog, CognitionLog, DiagnosticsLog och UnifiedLog behöver en gemensam loggmodell med filter, inte fyra konkurrerande textformat.
