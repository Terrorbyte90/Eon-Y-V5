import Foundation

// MARK: - SwedishWSDEngine (Pelare F)

actor SwedishWSDEngine {
    // Förenklad SALDO-baserad WSD
    private var senseDatabase: [String: [WordSense]] = [:]

    // Iteration 14: Semantic field mapping — 20 fields with 10+ Swedish words each
    // Used to boost WSD confidence when context words share a semantic field
    private static let semanticFields: [String: [String]] = [
        "kognition": ["tänka", "vetande", "minne", "förstå", "lära", "kunskap", "intelligens", "analys", "logik", "reflektera", "begripa", "fatta", "insikt", "hjärna", "ide"],
        "emotion": ["känsla", "glädje", "sorg", "ilska", "rädsla", "kärlek", "hat", "lycka", "oro", "stress", "entusiasm", "melankoli", "passion", "längtan", "fred"],
        "perception": ["se", "höra", "känna", "lukta", "smaka", "uppfatta", "observera", "märka", "notera", "varsebli", "intryck", "sinne", "syn", "hör", "blick"],
        "kommunikation": ["säga", "berätta", "fråga", "svara", "skriva", "läsa", "tala", "prata", "diskutera", "förklara", "ord", "språk", "mening", "text", "brev"],
        "rörelse": ["gå", "springa", "åka", "flyga", "simma", "klättra", "krypa", "hoppa", "dans", "röra", "färdas", "vandra", "löpa", "åka", "transport"],
        "tid": ["igår", "idag", "imorgon", "veckan", "månad", "år", "sekund", "minut", "timme", "klockan", "morgon", "kväll", "natt", "eftermiddag", "tidigt"],
        "rum": ["här", "där", "inne", "ute", "uppe", "nere", "rum", "hus", "stad", "land", "plats", "område", "avstånd", "rummet", "golvet"],
        "kvantitet": ["många", "få", "mycket", "lite", "alla", "ingen", "några", "flera", "antal", "summa", "totalt", "del", "hälften", "dubbel", "procent"],
        "kvalitet": ["bra", "dålig", "bäst", "sämst", "fin", "ful", "stor", "liten", "tung", "lätt", "hård", "mjuk", "ren", "smutsig", "perfekt"],
        "relation": ["vän", "familj", "kärlek", "partner", "barn", "förälder", "syskon", "mormor", "morfar", "släkt", "kompanjon", "kollega", "granne", "bekant", "förhållande"],
        "socialt": ["möte", "fest", "samtal", "diskussion", "samarbete", "grupp", "lag", "förening", "samhälle", "kultur", "tradition", "ceremoni", "firande", "gemenskap", "nätverk"],
        "natur": ["skog", "sjö", "berg", "hav", "flod", "träd", "blomma", "djur", "fågel", "fisk", "vind", "regn", "sol", "måne", "stjärna"],
        "teknik": ["dator", "telefon", "internet", "app", "program", "kod", "server", "nätverk", "skärm", "tangentbord", "algoritm", "data", "digital", "automatisk", "robot"],
        "vetenskap": ["forskning", "experiment", "teori", "hypotes", "bevis", "studie", "resultat", "metod", "analys", "fysik", "kemi", "biologi", "matematik", "statistik", "laboratorium"],
        "konst": ["musik", "måleri", "skulptur", "film", "teater", "litteratur", "poesi", "dans", "foto", "design", "arkitektur", "utställning", "galleri", "målning", "konsert"],
        "ekonomi": ["pengar", "bank", "pris", "kostnad", "inkomst", "skatt", "budget", "investering", "aktie", "fond", "ränta", "valuta", "handel", "marknad", "företag"],
        "hälsa": ["sjukdom", "läkare", "sjukhus", "medicin", "träning", "motion", "kost", "vila", "symptom", "behandling", "operation", "vård", "patient", "hälsosam", "frisk"],
        "juridik": ["lag", "domstol", "advokat", "domare", "brott", "straff", "rättvisa", "avtal", "rättighet", "skyldighet", "polis", "åklagare", "fängelse", "rättegång", "förordning"],
        "mat": ["middag", "frukost", "lunch", "bröd", "kött", "fisk", "grönsak", "frukt", "dryck", "vatten", "mjölk", "ost", "smör", "krydda", "recept"],
        "kläder": ["skjorta", "byxor", "klänning", "jacka", "sko", "strumpa", "hatt", "handske", "halsduk", "väska", "tröja", "rock", "kostym", "uniform", "mode"],
        // ── v89: 20 additional semantic fields (40 total) ──
        "politik": ["regering", "riksdag", "minister", "parti", "val", "röst", "demokrati", "opposition", "majoritet", "mandat", "politik", "beslut", "reform", "lagförslag", "utskott"],
        "religion": ["gud", "kyrka", "bön", "tro", "helgon", "präst", "mässa", "bibel", "islam", "judendom", "hinduism", "buddhism", "andlighet", "ritual", "församling"],
        "sport": ["fotboll", "hockey", "tennis", "golf", "friidrott", "simning", "skidor", "cykling", "basket", "volleyboll", "tränare", "spelare", "match", "turnering", "medalj"],
        "underhållning": ["bio", "tv", "streaming", "serie", "program", "underhållning", "nöje", "cirkus", "show", "spela", "rolig", "komedi", "drama", "action", "thriller"],
        "transport": ["bil", "buss", "tåg", "flygplan", "båt", "cykel", "spårvagn", "tunnelbana", "väg", "motorväg", "station", "terminal", "hamn", "flygplats", "resecentrum"],
        "väder": ["sol", "regn", "snö", "vind", "moln", "åska", "blixt", "dimma", "hagel", "storm", "orkan", "torka", "frost", "kyla", "värme"],
        "byggande": ["hus", "byggnad", "konstruktion", "fundament", "vägg", "tak", "grund", "bjälke", "sten", "betong", "stål", "trä", "arkitekt", "ingenjör", "verktyg"],
        "jordbruk": ["åker", "traktor", "skörd", "sådd", "gödning", "odling", "grödor", "boskap", "mjölkning", "lantbruk", "bond", "säd", "betesmark", "tröskning", "bevattning"],
        "tillverkning": ["fabrik", "produktion", "montage", "sammanställning", "maskin", "råvara", "komponent", "kvalitet", "effektivitet", "leverans", "standard", "process", "industri", "verkstad", "lina"],
        "handel": ["butik", "försäljning", "kund", "pris", "rabatt", "marknadsföring", "reklam", "inköp", "grossist", "detaljhandel", "export", "import", "tull", "försäljare", "vara"],
        "polis": ["utredning", "förhör", "gärning", "vittne", "misstänkt", "gripande", "patrull", "bevis", "spaning", "åtal", "kriminal", "polischef", "lagbok", "våldsbrott", "stöld"],
        "militär": ["försvar", "armé", "flotta", "flygvapen", "soldat", "officer", "general", "strid", "övning", "vapen", "försvarsmakt", "plikt", "bas", "insats", "mission"],
        "media": ["tidning", "nyhet", "redaktion", "journalist", "reportage", "krönika", "ledare", "rubrik", "press", "massmedia", "publicering", "artikel", "reporter", "intervju", "debatt"],
        "mode": ["stil", "design", "trend", "kollektion", "märke", "accessor", "tyg", "mönster", "symaskin", "skräddare", "couture", "catwalk", "visning", "smycke", "väska"],
        "arkitektur": ["byggnad", "fasad", "planritning", "våning", "entré", "trapphus", "fönster", "balkong", "torn", "kupol", "valv", "pelare", "material", "stil", "funktion"],
        "matematik": ["algebra", "geometri", "aritmetik", "ekvation", "variabel", "funktion", "integral", "derivata", "matris", "mängd", "tal", "bråk", "procent", "statistik", "sannolikhet"],
        "fysik": ["kraft", "energi", "rörelse", "massa", "hastighet", "acceleration", "tryck", "friktion", "gravitation", "elektromagnet", "kvant", "atom", "partikel", "våg", "fält"],
        "kemi": ["molekyl", "atom", "reaktion", "lösning", "syra", "bas", "grundämne", "periodiska", "bindning", "oxid", "katjon", "anjon", "destillering", "kristall", "entalpi"],
        "biologi": ["cell", "organism", "gen", "DNA", "protein", "enzym", "evolution", "ekologi", "art", "biosfär", "fotosyntes", "metabolism", "mutation", "nervsystem", "immunförsvar"],
        "geografi": ["kontinent", "land", "stad", "flod", "berg", "dal", "öken", "slätt", "platå", "klimat", "vegetation", "befolkning", "karta", "koordinat", "tidszon"],
    ]

    func initialize() async {
        // Ladda grundläggande disambigueringsdata
        loadBuiltInSenses()
        print("[WSD] Disambigueringsmotor initierad ✓")
    }

    private func loadBuiltInSenses() {
        senseDatabase = [
            "band": [
                WordSense(id: "band.1", definition: "musikgrupp", examples: ["rockband", "spelat i band", "bandet spelade"], confidence: 0.0),
                WordSense(id: "band.2", definition: "remsa, tejp", examples: ["tejpband", "magnetband", "löpande band"], confidence: 0.0),
                WordSense(id: "band.3", definition: "bindning, förbindning", examples: ["blodband", "vänskapsband", "familjens band"], confidence: 0.0)
            ],
            "rätt": [
                WordSense(id: "rätt.1", definition: "korrekt, riktigt", examples: ["rätt svar", "det är rätt", "helt rätt"], confidence: 0.0),
                WordSense(id: "rätt.2", definition: "maträtt", examples: ["varmrätt", "förrätt", "huvudrätt", "god rätt"], confidence: 0.0),
                WordSense(id: "rätt.3", definition: "juridisk rätt", examples: ["mänskliga rättigheter", "rätten att", "laglig rätt"], confidence: 0.0)
            ],
            "lös": [
                WordSense(id: "lös.1", definition: "inte fastbunden", examples: ["löst hår", "lös knut", "lös skruv"], confidence: 0.0),
                WordSense(id: "lös.2", definition: "lösa upp, lösa problem", examples: ["lösa ekvationen", "lösa problemet", "lös gåtan"], confidence: 0.0)
            ],
            "spel": [
                WordSense(id: "spel.1", definition: "datorspel, brädspel", examples: ["spela spel", "tv-spel", "dataspel"], confidence: 0.0),
                WordSense(id: "spel.2", definition: "musikspelande", examples: ["pianospel", "gitarrspel", "hennes spel"], confidence: 0.0),
                WordSense(id: "spel.3", definition: "teater, skådespeleri", examples: ["skådespelarens spel", "dramatiskt spel"], confidence: 0.0)
            ],
            "slag": [
                WordSense(id: "slag.1", definition: "fysiskt slag", examples: ["ett hårt slag", "slag i ansiktet"], confidence: 0.0),
                WordSense(id: "slag.2", definition: "typ, sort", examples: ["alla slag", "ett slag av", "olika slag"], confidence: 0.0),
                WordSense(id: "slag.3", definition: "militärt slag", examples: ["slaget vid", "fältslag"], confidence: 0.0)
            ],
            "mål": [
                WordSense(id: "mål.1", definition: "syfte, ändamål", examples: ["uppnå målet", "mitt mål", "långsiktigt mål"], confidence: 0.0),
                WordSense(id: "mål.2", definition: "sportmål", examples: ["göra mål", "målvakt", "poängen gick i mål"], confidence: 0.0),
                WordSense(id: "mål.3", definition: "rättsfall", examples: ["brottmål", "målet i rätten", "civilmål"], confidence: 0.0),
                WordSense(id: "mål.4", definition: "språk, dialekt", examples: ["östgötamål", "skånska mål"], confidence: 0.0)
            ],
            "ställe": [
                WordSense(id: "ställe.1", definition: "plats", examples: ["ett fint ställe", "på det stället"], confidence: 0.0),
                WordSense(id: "ställe.2", definition: "i stället för", examples: ["i stället", "istället för"], confidence: 0.0)
            ],
            "drag": [
                WordSense(id: "drag.1", definition: "egenskap, karaktärsdrag", examples: ["typiska drag", "personlighetsdrag"], confidence: 0.0),
                WordSense(id: "drag.2", definition: "rörelse, att dra", examples: ["ett snabbt drag", "schackdrag"], confidence: 0.0),
                WordSense(id: "drag.3", definition: "luftdrag", examples: ["det drar", "kallt drag"], confidence: 0.0)
            ],
            "fall": [
                WordSense(id: "fall.1", definition: "händelse, situation", examples: ["i detta fall", "i alla fall"], confidence: 0.0),
                WordSense(id: "fall.2", definition: "fysiskt fall", examples: ["falla ner", "ett högt fall"], confidence: 0.0),
                WordSense(id: "fall.3", definition: "sjukdomsfall", examples: ["smittfall", "antalet fall"], confidence: 0.0)
            ],
            "verk": [
                WordSense(id: "verk.1", definition: "konstverk", examples: ["ett stort verk", "litterärt verk", "hans verk"], confidence: 0.0),
                WordSense(id: "verk.2", definition: "myndighet", examples: ["naturvårdsverket", "statligt verk"], confidence: 0.0),
                WordSense(id: "verk.3", definition: "anläggning, fabrik", examples: ["kraftverk", "elverk"], confidence: 0.0)
            ],
            "grund": [
                WordSense(id: "grund.1", definition: "bas, fundament", examples: ["på goda grunder", "grunden för"], confidence: 0.0),
                WordSense(id: "grund.2", definition: "orsak", examples: ["av den grunden", "grund till"], confidence: 0.0),
                WordSense(id: "grund.3", definition: "ytligt vatten", examples: ["gå på grund", "grundet i viken"], confidence: 0.0)
            ],
            "rad": [
                WordSense(id: "rad.1", definition: "linje, serie", examples: ["på rad", "en rad av", "i en rad"], confidence: 0.0),
                WordSense(id: "rad.2", definition: "textrad", examples: ["rad för rad", "första raden"], confidence: 0.0)
            ],
            "rik": [
                WordSense(id: "rik.1", definition: "förmögen", examples: ["en rik man", "bli rik"], confidence: 0.0),
                WordSense(id: "rik.2", definition: "riklig, full av", examples: ["rik på", "vitaminrik", "kunskapsrik"], confidence: 0.0)
            ],
            "värde": [
                WordSense(id: "värde.1", definition: "ekonomiskt värde", examples: ["högt värde", "marknadsvärde"], confidence: 0.0),
                WordSense(id: "värde.2", definition: "moraliskt värde", examples: ["mänskligt värde", "värderingar"], confidence: 0.0),
                WordSense(id: "värde.3", definition: "matematiskt värde", examples: ["variabelns värde", "numeriskt värde"], confidence: 0.0)
            ],
            "del": [
                WordSense(id: "del.1", definition: "bit, stycke", examples: ["en del av", "första delen"], confidence: 0.0),
                WordSense(id: "del.2", definition: "ganska mycket", examples: ["en hel del", "en del människor"], confidence: 0.0)
            ],
            "kraft": [
                WordSense(id: "kraft.1", definition: "fysisk styrka", examples: ["med full kraft", "muskelkraft"], confidence: 0.0),
                WordSense(id: "kraft.2", definition: "energi, el", examples: ["kärnkraft", "vindkraft", "kraftverk"], confidence: 0.0),
                WordSense(id: "kraft.3", definition: "giltighet", examples: ["i kraft", "träda i kraft", "laga kraft"], confidence: 0.0)
            ],
            "kort": [
                WordSense(id: "kort.1", definition: "litet, inte långt", examples: ["kort tid", "kort hår", "kort svar"], confidence: 0.0),
                WordSense(id: "kort.2", definition: "spelkort, kreditkort", examples: ["betala med kort", "spela kort", "bankkort"], confidence: 0.0)
            ],
            "press": [
                WordSense(id: "press.1", definition: "media, tidningar", examples: ["presskonferens", "svensk press", "pressen rapporterade"], confidence: 0.0),
                WordSense(id: "press.2", definition: "tryck, påfrestning", examples: ["under press", "sätta press på"], confidence: 0.0)
            ],
            "brott": [
                WordSense(id: "brott.1", definition: "lagöverträdelse", examples: ["begå brott", "grovt brott", "brottslighet"], confidence: 0.0),
                WordSense(id: "brott.2", definition: "bräckning, avbrott", examples: ["benbrott", "brott mot reglerna"], confidence: 0.0)
            ],
            "ton": [
                WordSense(id: "ton.1", definition: "musikton, ljud", examples: ["en ren ton", "grundton", "tonart"], confidence: 0.0),
                WordSense(id: "ton.2", definition: "stil, attityd", examples: ["hård ton", "tonläge", "tonen i samtalet"], confidence: 0.0),
                WordSense(id: "ton.3", definition: "viktenhet", examples: ["ett ton", "tusen kilo"], confidence: 0.0)
            ],
            "takt": [
                WordSense(id: "takt.1", definition: "rytm, tempo", examples: ["i takt med", "hålla takten"], confidence: 0.0),
                WordSense(id: "takt.2", definition: "hövlighet", examples: ["visa takt", "taktlös"], confidence: 0.0)
            ],
            "rum": [
                WordSense(id: "rum.1", definition: "fysiskt rum, kammare", examples: ["sovrum", "vardagsrum", "ett stort rum"], confidence: 0.0),
                WordSense(id: "rum.2", definition: "utrymme, plats", examples: ["ge rum för", "ta rum", "lämna rum"], confidence: 0.0)
            ],
            "led": [
                WordSense(id: "led.1", definition: "kroppsdel", examples: ["knäled", "handleds"], confidence: 0.0),
                WordSense(id: "led.2", definition: "väg, led", examples: ["vandringsleda", "leden till toppen"], confidence: 0.0),
                WordSense(id: "led.3", definition: "trött, matt", examples: ["led vid", "led på"], confidence: 0.0)
            ],
            "sak": [
                WordSense(id: "sak.1", definition: "föremål, ting", examples: ["en fin sak", "dina saker"], confidence: 0.0),
                WordSense(id: "sak.2", definition: "ärende, fråga", examples: ["en viktig sak", "saken är den"], confidence: 0.0)
            ],
            "skott": [
                WordSense(id: "skott.1", definition: "avfyrning", examples: ["skjuta ett skott", "skottlossning"], confidence: 0.0),
                WordSense(id: "skott.2", definition: "växtskott", examples: ["nya skott", "sidoskott"], confidence: 0.0),
                WordSense(id: "skott.3", definition: "skiljevägg", examples: ["skottet i båten", "brandskott"], confidence: 0.0)
            ],
            // ── Utökad WSD v10: 20+ nya flertydiga ord ──
            "ställning": [
                WordSense(id: "ställning.1", definition: "position, rangordning", examples: ["hög ställning", "ställning i samhället"], confidence: 0.0),
                WordSense(id: "ställning.2", definition: "byggnadsställning", examples: ["klättra på ställningen", "resa en ställning"], confidence: 0.0),
                WordSense(id: "ställning.3", definition: "matchresultat", examples: ["ställningen är 2-1", "slutställning"], confidence: 0.0)
            ],
            "gren": [
                WordSense(id: "gren.1", definition: "trädgren", examples: ["sitta på en gren", "grenar och löv"], confidence: 0.0),
                WordSense(id: "gren.2", definition: "idrottsgren", examples: ["vilken gren tävlar du i", "friidrottsgren"], confidence: 0.0),
                WordSense(id: "gren.3", definition: "avdelning, förgrening", examples: ["gren av företaget", "en gren av vetenskapen"], confidence: 0.0)
            ],
            "fast": [
                WordSense(id: "fast.1", definition: "solid, inte flytande", examples: ["fast mark", "fast föda", "stå fast"], confidence: 0.0),
                WordSense(id: "fast.2", definition: "trots att, även om", examples: ["fast jag sa nej", "fast det regnar"], confidence: 0.0)
            ],
            "mark": [
                WordSense(id: "mark.1", definition: "jord, terräng", examples: ["odla mark", "stå på fast mark"], confidence: 0.0),
                WordSense(id: "mark.2", definition: "valutaenhet", examples: ["tyska mark", "svenska mark"], confidence: 0.0)
            ],
            "börd": [
                WordSense(id: "börd.1", definition: "ursprung, härstamning", examples: ["av fin börd", "hans börd"], confidence: 0.0),
                WordSense(id: "börd.2", definition: "bördig, fruktbar", examples: ["bördig jord", "bördig mark"], confidence: 0.0)
            ],
            "källa": [
                WordSense(id: "källa.1", definition: "vattenkälla", examples: ["dricka ur källan", "bergskälla"], confidence: 0.0),
                WordSense(id: "källa.2", definition: "informationskälla", examples: ["pålitlig källa", "enligt källor", "källkritik"], confidence: 0.0)
            ],
            "ränta": [
                WordSense(id: "ränta.1", definition: "bankränta", examples: ["hög ränta", "räntan stiger", "styrränta"], confidence: 0.0),
                WordSense(id: "ränta.2", definition: "avkastning bildligt", examples: ["ge ränta på ränta", "ränta av arbete"], confidence: 0.0)
            ],
            "tecken": [
                WordSense(id: "tecken.1", definition: "symbol, bokstav", examples: ["matematiska tecken", "skrivtecken"], confidence: 0.0),
                WordSense(id: "tecken.2", definition: "indikation, signal", examples: ["tecken på sjukdom", "gott tecken", "varningstecken"], confidence: 0.0)
            ],
            "period": [
                WordSense(id: "period.1", definition: "tidsperiod", examples: ["under denna period", "en lång period"], confidence: 0.0),
                WordSense(id: "period.2", definition: "menstruation", examples: ["ha mens", "periodens smärta"], confidence: 0.0),
                WordSense(id: "period.3", definition: "ishockeyperiod", examples: ["första perioden", "periodpaus"], confidence: 0.0)
            ],
            "organ": [
                WordSense(id: "organ.1", definition: "kroppsorgan", examples: ["hjärtat är ett organ", "vitala organ"], confidence: 0.0),
                WordSense(id: "organ.2", definition: "tidning, organisation", examples: ["partiets organ", "fackligt organ"], confidence: 0.0),
                WordSense(id: "organ.3", definition: "musikinstrument", examples: ["spela orgel", "kyrkorgel"], confidence: 0.0)
            ],
            "vinge": [
                WordSense(id: "vinge.1", definition: "fågelvinge", examples: ["breda ut vingarna", "fjädervinge"], confidence: 0.0),
                WordSense(id: "vinge.2", definition: "flygel av byggnad", examples: ["östra vingen", "sjukhusvingen"], confidence: 0.0),
                WordSense(id: "vinge.3", definition: "politisk vinge", examples: ["vänstervingen", "högerflygeln"], confidence: 0.0)
            ],
            "bas": [
                WordSense(id: "bas.1", definition: "grund, fundament", examples: ["bas för verksamheten", "kunskapsbas"], confidence: 0.0),
                WordSense(id: "bas.2", definition: "militärbas", examples: ["flygbas", "militärbas"], confidence: 0.0),
                WordSense(id: "bas.3", definition: "musikton", examples: ["sjunga bas", "basröst", "basgitarr"], confidence: 0.0)
            ],
            "nät": [
                WordSense(id: "nät.1", definition: "fiskenät", examples: ["kasta nätet", "fånga i nät"], confidence: 0.0),
                WordSense(id: "nät.2", definition: "internet", examples: ["surfa på nätet", "näthandel", "nätbaserad"], confidence: 0.0),
                WordSense(id: "nät.3", definition: "elnät", examples: ["elnätet", "nätägare"], confidence: 0.0)
            ],
            "stämma": [
                WordSense(id: "stämma.1", definition: "sångröst", examples: ["vacker stämma", "andrastämma"], confidence: 0.0),
                WordSense(id: "stämma.2", definition: "vara korrekt", examples: ["det stämmer", "stämmer överens"], confidence: 0.0),
                WordSense(id: "stämma.3", definition: "juridisk stämning", examples: ["stämma någon", "stämningsansökan"], confidence: 0.0)
            ],
            "växt": [
                WordSense(id: "växt.1", definition: "planta, vegetation", examples: ["tropisk växt", "krukväxt", "växtlighet"], confidence: 0.0),
                WordSense(id: "växt.2", definition: "tillväxt, ökning", examples: ["ekonomisk växt", "befolkningsväxt"], confidence: 0.0)
            ],
            "form": [
                WordSense(id: "form.1", definition: "yttre gestalt", examples: ["rund form", "i form av"], confidence: 0.0),
                WordSense(id: "form.2", definition: "kondition", examples: ["vara i form", "toppform", "dålig form"], confidence: 0.0),
                WordSense(id: "form.3", definition: "gjutform", examples: ["kakform", "gjutform"], confidence: 0.0)
            ],
            "bruk": [
                WordSense(id: "bruk.1", definition: "användning", examples: ["dagligt bruk", "i bruk", "ta i bruk"], confidence: 0.0),
                WordSense(id: "bruk.2", definition: "fabrik, industri", examples: ["järnbruk", "pappersbruk"], confidence: 0.0),
                WordSense(id: "bruk.3", definition: "sed, vana", examples: ["gammal bruk", "sed och bruk"], confidence: 0.0)
            ],
            "kurs": [
                WordSense(id: "kurs.1", definition: "utbildningskurs", examples: ["gå en kurs", "kursmaterial"], confidence: 0.0),
                WordSense(id: "kurs.2", definition: "valutakurs", examples: ["kronans kurs", "kursutveckling", "aktiekurs"], confidence: 0.0),
                WordSense(id: "kurs.3", definition: "riktning", examples: ["hålla kursen", "ändra kurs", "segla kurs"], confidence: 0.0)
            ],
            "ljud": [
                WordSense(id: "ljud.1", definition: "hörselsignal", examples: ["starkt ljud", "ljudvågor", "ljudlös"], confidence: 0.0),
                WordSense(id: "ljud.2", definition: "fonem, språkljud", examples: ["vokalt ljud", "konsonantljud"], confidence: 0.0)
            ],
            "makt": [
                WordSense(id: "makt.1", definition: "politisk makt", examples: ["gripa makten", "maktbalans", "statsmakt"], confidence: 0.0),
                WordSense(id: "makt.2", definition: "förmåga, kraft", examples: ["med all makt", "efter bästa makt"], confidence: 0.0)
            ],
            "bild": [
                WordSense(id: "bild.1", definition: "visuell representation", examples: ["ta en bild", "bildskärm", "fotobild"], confidence: 0.0),
                WordSense(id: "bild.2", definition: "metafor, föreställning", examples: ["ge en bild av", "världsbild", "självbild"], confidence: 0.0)
            ],
            // ── Utökad WSD v11: kognitiva och vetenskapliga termer ──
            "modell": [
                WordSense(id: "modell.1", definition: "förebild, mannekäng", examples: ["fotomodell", "stå modell"], confidence: 0.0),
                WordSense(id: "modell.2", definition: "abstrakt representation", examples: ["klimatmodell", "språkmodell", "matematisk modell"], confidence: 0.0),
                WordSense(id: "modell.3", definition: "produktvariant", examples: ["senaste modellen", "bilmodell"], confidence: 0.0)
            ],
            "process": [
                WordSense(id: "process.1", definition: "förlopp, procedur", examples: ["lärandeprocess", "kognitiv process"], confidence: 0.0),
                WordSense(id: "process.2", definition: "rättegång", examples: ["rättsprocess", "förlora processen"], confidence: 0.0),
                WordSense(id: "process.3", definition: "datorprocess", examples: ["bakgrundsprocess", "processorkraft"], confidence: 0.0)
            ],
            "dimension": [
                WordSense(id: "dimension.1", definition: "fysisk storlek", examples: ["tredimensionell", "dimensioner på rummet"], confidence: 0.0),
                WordSense(id: "dimension.2", definition: "aspekt", examples: ["en ny dimension", "moralisk dimension"], confidence: 0.0)
            ],
            "ström": [
                WordSense(id: "ström.1", definition: "vattenström", examples: ["stark ström", "mot strömmen"], confidence: 0.0),
                WordSense(id: "ström.2", definition: "elektrisk ström", examples: ["strömavbrott", "strömmen gick"], confidence: 0.0),
                WordSense(id: "ström.3", definition: "flöde av människor/data", examples: ["informationsström", "medvetandeström", "tankeström"], confidence: 0.0)
            ],
            "kärna": [
                WordSense(id: "kärna.1", definition: "fruktkärna", examples: ["äpplekärna", "körsbärskärna"], confidence: 0.0),
                WordSense(id: "kärna.2", definition: "central del", examples: ["kärnfråga", "problemets kärna", "kärnan i argumentet"], confidence: 0.0),
                WordSense(id: "kärna.3", definition: "atomkärna", examples: ["kärnkraft", "kärnenergi", "kärnfysik"], confidence: 0.0)
            ],
            "fält": [
                WordSense(id: "fält.1", definition: "jordbruksfält", examples: ["åkerfält", "öppet fält"], confidence: 0.0),
                WordSense(id: "fält.2", definition: "ämnesområde", examples: ["forskningsfält", "expertis inom fältet"], confidence: 0.0),
                WordSense(id: "fält.3", definition: "fysikaliskt fält", examples: ["magnetfält", "gravitationsfält", "elektriskt fält"], confidence: 0.0)
            ],
            "signal": [
                WordSense(id: "signal.1", definition: "meddelande, varning", examples: ["ge en signal", "larmsignal"], confidence: 0.0),
                WordSense(id: "signal.2", definition: "elektronisk/neural signal", examples: ["nervsignal", "radiosignal", "signalstyrka"], confidence: 0.0)
            ],
            "system": [
                WordSense(id: "system.1", definition: "ordnad struktur", examples: ["skattesystem", "skolsystem", "värdesystem"], confidence: 0.0),
                WordSense(id: "system.2", definition: "tekniskt system", examples: ["operativsystem", "nervsystem", "solsystem"], confidence: 0.0)
            ],
            "koppling": [
                WordSense(id: "koppling.1", definition: "förbindelse, relation", examples: ["kopplingen mellan", "neural koppling"], confidence: 0.0),
                WordSense(id: "koppling.2", definition: "bilkoppling", examples: ["släppa kopplingen", "kopplingsslitage"], confidence: 0.0)
            ],
            "nivå": [
                WordSense(id: "nivå.1", definition: "höjdnivå", examples: ["havsnivå", "på samma nivå"], confidence: 0.0),
                WordSense(id: "nivå.2", definition: "grad, kvalitet", examples: ["hög nivå", "medvetandenivå", "komplexitetsnivå"], confidence: 0.0)
            ],
            "flöde": [
                WordSense(id: "flöde.1", definition: "vattenflöde", examples: ["blodflöde", "vattenflöde"], confidence: 0.0),
                WordSense(id: "flöde.2", definition: "psykologiskt flöde", examples: ["kreativt flöde", "arbetsflöde", "informationsflöde"], confidence: 0.0)
            ],
            "yta": [
                WordSense(id: "yta.1", definition: "fysisk yta", examples: ["arbetsyta", "golvyta", "slät yta"], confidence: 0.0),
                WordSense(id: "yta.2", definition: "ytlighet", examples: ["skrapa på ytan", "på ytan verkar det"], confidence: 0.0)
            ],
            "vikt": [
                WordSense(id: "vikt.1", definition: "tyngd", examples: ["kroppsvikt", "lyfta vikter"], confidence: 0.0),
                WordSense(id: "vikt.2", definition: "betydelse", examples: ["stor vikt", "lägga vikt vid", "av stor vikt"], confidence: 0.0)
            ],
            "balans": [
                WordSense(id: "balans.1", definition: "jämvikt, stabilitet", examples: ["hålla balansen", "i balans", "balansgång"], confidence: 0.0),
                WordSense(id: "balans.2", definition: "ekonomisk balans", examples: ["balansräkning", "handelsbalans"], confidence: 0.0)
            ],
            // ── Utökad WSD v12: 100+ nya ord för 300% språkförbättring ──
            "analys": [
                WordSense(id: "analys.1", definition: "systematisk undersökning", examples: ["djupanalys", "dataanalys", "analys av resultat"], confidence: 0.0),
                WordSense(id: "analys.2", definition: "kemisk analys", examples: ["blodanalys", "materialanalys"], confidence: 0.0)
            ],
            "teori": [
                WordSense(id: "teori.1", definition: "vetenskaplig teori", examples: ["Einsteins teori", "evolutionsteori", "relativitetsteori"], confidence: 0.0),
                WordSense(id: "teori.2", definition: "abstrakt tänkande", examples: ["teori och praktik", "rent teoretiskt"], confidence: 0.0)
            ],
            "medel": [
                WordSense(id: "medel.1", definition: "metod, hjälpmedel", examples: ["medel för ändamålet", "kommunikationsmedel"], confidence: 0.0),
                WordSense(id: "medel.2", definition: "genomsnitt", examples: ["i medel", "medelvärdet"], confidence: 0.0),
                WordSense(id: "medel.3", definition: "penningmedel", examples: ["ekonomiska medel", "anser medel"], confidence: 0.0)
            ],
            "ämne": [
                WordSense(id: "ämne.1", definition: "skolämne, ämnesområde", examples: ["svenska är ett ämne", "forskningsämne"], confidence: 0.0),
                WordSense(id: "ämne.2", definition: "kemiskt ämne", examples: ["organiskt ämne", "kemiskt ämne"], confidence: 0.0),
                WordSense(id: "ämne.3", definition: "textilmöbel", examples: ["soffämne", "klädesämne"], confidence: 0.0)
            ],
            "anda": [
                WordSense(id: "anda.1", definition: "andning", examples: ["djup anda", "hålla andan"], confidence: 0.0),
                WordSense(id: "anda.2", definition: "spirit, anda", examples: ["tidsandan", "gemenskapsanda", "laganda"], confidence: 0.0),
                WordSense(id: "anda.3", definition: "varelse, spöke", examples: ["god anda", "elak anda"], confidence: 0.0)
            ],
            "sida": [
                WordSense(id: "sida.1", definition: "papper sida", examples: ["vände sida", "första sidan"], confidence: 0.0),
                WordSense(id: "sida.2", definition: "webbsida", examples: ["besök vår sida", "hemsida"], confidence: 0.0),
                WordSense(id: "sida.3", definition: "kant, del", examples: ["på båda sidor", "svaga sidan"], confidence: 0.0)
            ],
            "sätt": [
                WordSense(id: "sätt.1", definition: "metod, tillvägagångssätt", examples: ["på ett sätt", "sättet att göra"], confidence: 0.0),
                WordSense(id: "sätt.2", definition: "manér, beteende", examples: ["sättet han pratar", "dåliga sätt"], confidence: 0.0)
            ],
            "ordning": [
                WordSense(id: "ordning.1", definition: "struktur, organisation", examples: ["hålla ordning", "i ordning", "ordning och reda"], confidence: 0.0),
                WordSense(id: "ordning.2", definition: "sekvens", examples: ["alfabetisk ordning", "åldersordning"], confidence: 0.0),
                WordSense(id: "ordning.3", definition: "lag, förordning", examples: ["kungörelseordning", "valordning"], confidence: 0.0)
            ],
            "arbete": [
                WordSense(id: "arbete.1", definition: "yrkesarbete", examples: ["gå till arbetet", "arbetslös", "söka arbete"], confidence: 0.0),
                WordSense(id: "arbete.2", definition: "fysiskt/mentalt arbete", examples: ["hårt arbete", "mentalt arbete"], confidence: 0.0),
                WordSense(id: "arbete.3", definition: "konstverk, verk", examples: ["konstnärens arbeten", "litterärt arbete"], confidence: 0.0)
            ],
            "liv": [
                WordSense(id: "liv.1", definition: "existens, biological", examples: ["liv och död", "rädda liv", "livets mening"], confidence: 0.0),
                WordSense(id: "liv.2", definition: "livsstil, erfarenhet", examples: ["ett bra liv", "livet i staden", "hela livet"], confidence: 0.0)
            ],
            "tidning": [
                WordSense(id: "tidning.1", definition: "presstidning", examples: ["läsa tidningen", "dagstidning", "morgontidning"], confidence: 0.0),
                WordSense(id: "tidning.2", definition: "tidskrift, magasin", examples: ["vetenskaplig tidning", "facktidskrift"], confidence: 0.0)
            ],
            "konst": [
                WordSense(id: "konst.1", definition: "bildande konst", examples: ["modern konst", "konstmuseum", "konstnär"], confidence: 0.0),
                WordSense(id: "konst.2", definition: "färdighet, knep", examples: ["konsten att", "det är ingen konst"], confidence: 0.0)
            ],
            "språk": [
                WordSense(id: "språk.1", definition: "kommunikationsspråk", examples: ["svenska språket", "främmande språk"], confidence: 0.0),
                WordSense(id: "språk.2", definition: "programspråk", examples: ["programmeringsspråk", "högnivåspråk"], confidence: 0.0),
                WordSense(id: "språk.3", definition: "uttryckssätt", examples: ["kroppsspråk", "bildspråk", "fackspråk"], confidence: 0.0)
            ],
            "tanke": [
                WordSense(id: "tanke.1", definition: "mental process", examples: ["en intressant tanke", "tänka tanken", "tankegång"], confidence: 0.0),
                WordSense(id: "tanke.2", definition: "avsikt, mening", examples: ["med tanken att", "i tanken på"], confidence: 0.0)
            ],
            "känsla": [
                WordSense(id: "känsla.1", definition: "emotion", examples: ["starka känslor", "känsloliv", "känslomässig"], confidence: 0.0),
                WordSense(id: "känsla.2", definition: "sinnesförnimmelse", examples: ["känsla av värme", "känsla i fingrarna"], confidence: 0.0),
                WordSense(id: "känsla.3", definition: "intuition", examples: ["känsla för", "språkkänsla", "tidtabellskänsla"], confidence: 0.0)
            ],
            "förhållande": [
                WordSense(id: "förhållande.1", definition: "relation mellan personer", examples: ["ett bra förhållande", "parförhållande"], confidence: 0.0),
                WordSense(id: "förhållande.2", definition: "situation, omständighet", examples: ["under nuvarande förhållanden", "förhållandena"], confidence: 0.0),
                WordSense(id: "förhållande.3", definition: "proportion", examples: ["förhållandet mellan", "i förhållande till"], confidence: 0.0)
            ],
            "princip": [
                WordSense(id: "princip.1", definition: "grundregel", examples: ["grundläggande princip", "en princip om"], confidence: 0.0),
                WordSense(id: "princip.2", definition: "vetenskaplig princip", examples: ["fysikalisk princip", "arbetsprincip"], confidence: 0.0)
            ],
            "regel": [
                WordSense(id: "regel.1", definition: "föreskrift, norm", examples: ["enligt reglerna", "bryta mot regeln", "undantagsregel"], confidence: 0.0),
                WordSense(id: "regel.2", definition: "vanlighet", examples: ["som regel", "i regel", "undantagsvis"], confidence: 0.0)
            ],
            "lag": [
                WordSense(id: "lag.1", definition: "juridisk lag", examples: ["enligt lag", "bryta mot lagen", "lagboken"], confidence: 0.0),
                WordSense(id: "lag.2", definition: "grupp, team", examples: ["fotbollslag", "arbeta i lag", "lagkamrat"], confidence: 0.0),
                WordSense(id: "lag.3", definition: "naturvetenskaplig lag", examples: ["naturlag", "fyndighetens lag"], confidence: 0.0)
            ],
            "rum": [
                WordSense(id: "rum.1", definition: "fysiskt rum", examples: ["sovrum", "vardagsrum", "möte i rummet"], confidence: 0.0),
                WordSense(id: "rum.2", definition: "utrymme", examples: ["ge rum för", "ta rum", "lämna rum"], confidence: 0.0),
                WordSense(id: "rum.3", definition: "matematiskt rum", examples: ["vektorrum", "tredimensionellt rum"], confidence: 0.0)
            ],
            "funktion": [
                WordSense(id: "funktion.1", definition: "syfte, uppgift", examples: ["vilken funktion har", "funktionell"], confidence: 0.0),
                WordSense(id: "funktion.2", definition: "matematisk funktion", examples: ["linjär funktion", "funktionssätt"], confidence: 0.0),
                WordSense(id: "funktion.3", definition: "social tillställning", examples: ["officiell funktion", "ceremoniell funktion"], confidence: 0.0)
            ],
            "egenskap": [
                WordSense(id: "egenskap.1", definition: "karakteristika", examples: ["viktig egenskap", "personlig egenskap"], confidence: 0.0),
                WordSense(id: "egenskap.2", definition: "materialeigenskap", examples: ["fysiska egenskaper", "kemiska egenskaper"], confidence: 0.0)
            ],
            "variabel": [
                WordSense(id: "variabel.1", definition: "matematisk variabel", examples: ["oberoende variabel", "variera variabeln"], confidence: 0.0),
                WordSense(id: "variabel.2", definition: "programmeringsvariabel", examples: ["deklarera variabeln", "variabeltyp"], confidence: 0.0)
            ],
            "parameter": [
                WordSense(id: "parameter.1", definition: "inställningsparameter", examples: ["ändra parametern", "parameterinställning"], confidence: 0.0),
                WordSense(id: "parameter.2", definition: "matematisk parameter", examples: ["styra parameter", "systemparameter"], confidence: 0.0)
            ],
            "modul": [
                WordSense(id: "modul.1", definition: "programmodul", examples: ["programmeringsmodul", "modulär arkitektur"], confidence: 0.0),
                WordSense(id: "modul.2", definition: "byggmodul, enhet", examples: ["byggmodul", "utbildningsmodul"], confidence: 0.0)
            ],
            "struktur": [
                WordSense(id: "struktur.1", definition: "uppbyggnad, organisation", examples: ["organisatorisk struktur", "datatstruktur"], confidence: 0.0),
                WordSense(id: "struktur.2", definition: "kristallstruktur", examples: ["kristallinsk struktur", "molekylär struktur"], confidence: 0.0)
            ],
            "representation": [
                WordSense(id: "representation.1", definition: "avbildning, modell", examples: ["matematisk representation", "visuell representation"], confidence: 0.0),
                WordSense(id: "representation.2", definition: "politisk representation", examples: ["demokratisk representation", "folkrepresentation"], confidence: 0.0)
            ],
            "abstraktion": [
                WordSense(id: "abstraktion.1", definition: "begreppslig abstraktion", examples: ["högnivåabstraktion", "abstraktionsnivå"], confidence: 0.0),
                WordSense(id: "abstraktion.2", definition: "programmeringsabstraktion", examples: ["dataabstraktion", "funktionell abstraktion"], confidence: 0.0)
            ],
            "transformation": [
                WordSense(id: "transformation.1", definition: "omvandling, förändring", examples: ["digital transformation", "datatransformation"], confidence: 0.0),
                WordSense(id: "transformation.2", definition: "matematisk transformation", examples: ["linjär transformation", "koordinattransformation"], confidence: 0.0)
            ],
            "integration": [
                WordSense(id: "integration.1", definition: "sammanfogning", examples: ["systemintegration", "integration av system"], confidence: 0.0),
                WordSense(id: "integration.2", definition: "social integration", examples: ["samhällsintegration", "kulturell integration"], confidence: 0.0)
            ],
            "interaktion": [
                WordSense(id: "interaktion.1", definition: "växelverkan", examples: ["människa-dator interaktion", "social interaktion"], confidence: 0.0),
                WordSense(id: "interaktion.2", definition: "kemisk interaktion", examples: ["läkemedelsinteraktion", "molekylär interaktion"], confidence: 0.0)
            ],
            "adaptation": [
                WordSense(id: "adaptation.1", definition: "evolutionär anpassning", examples: ["biologisk adaptation", "naturlig adaptation"], confidence: 0.0),
                WordSense(id: "adaptation.2", definition: "allmän anpassning", examples: ["kognitiv adaptation", "systemadaptation"], confidence: 0.0)
            ],
            "emergens": [
                WordSense(id: "emergens.1", definition: "framträdande fenomen", examples: ["systememergens", "svår emergens"], confidence: 0.0),
                WordSense(id: "emergens.2", definition: "oväntad egenskap", examples: ["kollektiv emergens", "kognitiv emergens"], confidence: 0.0)
            ],
            "semantik": [
                WordSense(id: "semantik.1", definition: "betydelselära", examples: ["formell semantik", "programmeringssemantik"], confidence: 0.0),
                WordSense(id: "semantik.2", definition: "meningsinnehåll", examples: ["ordets semantik", "semantisk analys"], confidence: 0.0)
            ],
            "syntax": [
                WordSense(id: "syntax.1", definition: "meningsbyggnad", examples: ["svensk syntax", "syntaxfel", "syntaxanalys"], confidence: 0.0),
                WordSense(id: "syntax.2", definition: "programmeringssyntax", examples: ["Python-syntax", "syntaxregler"], confidence: 0.0)
            ],
            "logik": [
                WordSense(id: "logik.1", definition: "formell logik", examples: ["matematisk logik", "predikatlogik", "satslogik"], confidence: 0.0),
                WordSense(id: "logik.2", definition: "sunn förnuft", examples: ["det finns ingen logik", "följa logiken"], confidence: 0.0)
            ],
            "algoritm": [
                WordSense(id: "algoritm.1", definition: "beräkningsprocedur", examples: ["sök algoritm", "sorterings algoritm", "algoritmisk"], confidence: 0.0),
                WordSense(id: "algoritm.2", definition: "AI algoritm", examples: ["inlärnings algoritm", "neural algoritm"], confidence: 0.0)
            ],
            "nätverk": [
                WordSense(id: "nätverk.1", definition: "datornätverk", examples: ["socialt nätverk", "neurala nätverk", "nätverksarkitektur"], confidence: 0.0),
                WordSense(id: "nätverk.2", definition: "socialt nätverk", examples: ["kontaktnätverk", "professionellt nätverk"], confidence: 0.0)
            ],
            "medvetande": [
                WordSense(id: "medvetande.1", definition: "subjektiv upplevelse", examples: ["fenomenalt medvetande", "medvetandefilosofi"], confidence: 0.0),
                WordSense(id: "medvetande.2", definition: "upplysthet", examples: ["vara medvetande om", "miljömedvetande", "klassmedvetande"], confidence: 0.0)
            ],
            "intelligens": [
                WordSense(id: "intelligens.1", definition: "kognitiv förmåga", examples: ["mänsklig intelligens", "IQ-intelligens"], confidence: 0.0),
                WordSense(id: "intelligens.2", definition: "artificiell intelligens", examples: ["AI-intelligens", "maskinintelligens"], confidence: 0.0)
            ],
            "information": [
                WordSense(id: "information.1", definition: "data, kunskap", examples: ["få information", "informationsbärare"], confidence: 0.0),
                WordSense(id: "information.2", definition: "informationsteori", examples: ["Shannon information", "informationsmängd"], confidence: 0.0)
            ],
            "data": [
                WordSense(id: "data.1", definition: "databas data", examples: ["lagrad data", "datamängd", "databehandling"], confidence: 0.0),
                WordSense(id: "data.2", definition: "vetenskaplig data", examples: ["experimentdata", "insamlad data"], confidence: 0.0)
            ],
            "modell": [
                WordSense(id: "modell.1", definition: "abstrakt representation", examples: ["språkmodell", "klimatmodell", "simuleringsmodell"], confidence: 0.0),
                WordSense(id: "modell.2", definition: "person, förebild", examples: ["fotomodell", "rollmodell"], confidence: 0.0),
                WordSense(id: "modell.3", definition: "produktversion", examples: ["senaste modellen", "bilmodell"], confidence: 0.0)
            ],
            "parameter": [
                WordSense(id: "parameter.1", definition: "variabel i system", examples: ["systemparametrar", "styra parameter"], confidence: 0.0),
                WordSense(id: "parameter.2", definition: "gräns, ram", examples: ["inom parametrarna", "utvidga parameter"], confidence: 0.0)
            ],
            "operator": [
                WordSense(id: "operator.1", definition: "matematisk operator", examples: ["additionsoperator", "operatorer i algebra"], confidence: 0.0),
                WordSense(id: "operator.2", definition: "teleoperatör", examples: ["nätoperatör", "mobiloperatör"], confidence: 0.0)
            ],
            "funktion": [
                WordSense(id: "funktion.1", definition: "matematisk funktion", examples: ["linjär funktion", "derivata av funktion"], confidence: 0.0),
                WordSense(id: "funktion.2", definition: "programmeringsfunktion", examples: ["definiera funktion", "funktionsanrop"], confidence: 0.0),
                WordSense(id: "funktion.3", definition: "syfte, roll", examples: ["vilken funktion fyller", "funktionell design"], confidence: 0.0)
            ],
            "element": [
                WordSense(id: "element.1", definition: "grundämne", examples: ["kemiskt element", "periodiska systemets element"], confidence: 0.0),
                WordSense(id: "element.2", definition: "beståndsdel", examples: ["byggstenar element", "systemets element"], confidence: 0.0),
                WordSense(id: "element.3", definition: "värmeelement", examples: ["sätta på elementet", "el-element"], confidence: 0.0)
            ],
            "komplex": [
                WordSense(id: "komplex.1", definition: "sammansatt struktur", examples: ["lägenhetskomplex", "industriellt komplex"], confidence: 0.0),
                WordSense(id: "komplex.2", definition: "psykologiskt komplex", examples: ["mindervärdeskomplex", "skomplex"], confidence: 0.0)
            ],
            "kontext": [
                WordSense(id: "kontext.1", definition: "sammanhang", examples: ["i sin kontext", "kontextuell analys", "sätta i kontext"], confidence: 0.0),
                WordSense(id: "kontext.2", definition: "programmeringskontext", examples: ["exekveringskontext", "kontextvariabel"], confidence: 0.0)
            ],
            "domän": [
                WordSense(id: "domän.1", definition: "ämnesområde", examples: ["kunskapsdomän", "forskningsdomän"], confidence: 0.0),
                WordSense(id: "domän.2", definition: "internetdomän", examples: ["webbdomän", "domännamn"], confidence: 0.0),
                WordSense(id: "domän.3", definition: "matematisk domän", examples: ["funktionens domän", "definitionsmängd"], confidence: 0.0)
            ],
            "entitet": [
                WordSense(id: "entitet.1", definition: "självständig ting", examples: [" Filosofisk entitet", "verklig entitet"], confidence: 0.0),
                WordSense(id: "entitet.2", definition: "databasentitet", examples: ["databasentitet", "entitetsrelation"], confidence: 0.0)
            ],
            "instans": [
                WordSense(id: "instans.1", definition: "exemplar, konkret fall", examples: ["instans av klass", "en instans av"], confidence: 0.0),
                WordSense(id: "instans.2", definition: "myndighetsinstans", examples: ["högsta instans", "överklaga till instans"], confidence: 0.0)
            ],
            "klass": [
                WordSense(id: "klass.1", definition: "kategori, typ", examples: ["objektklass", "klass av fenomen"], confidence: 0.0),
                WordSense(id: "klass.2", definition: "programmeringsklass", examples: ["Python-klass", "klass och objekt"], confidence: 0.0),
                WordSense(id: "klass.3", definition: "samhällsklass", examples: ["arbetarklass", "medelklass"], confidence: 0.0)
            ],
            "relation": [
                WordSense(id: "relation.1", definition: "mellanpersonlig relation", examples: ["god relation", "relation till chefen"], confidence: 0.0),
                WordSense(id: "relation.2", definition: "matematisk relation", examples: ["relation mellan variabler", "binär relation"], confidence: 0.0)
            ],
            "tillstånd": [
                WordSense(id: "tillstånd.1", definition: "status, kondition", examples: ["systemets tillstånd", "mentalt tillstånd", "hälsotillstånd"], confidence: 0.0),
                WordSense(id: "tillstånd.2", definition: "tillåtelse", examples: ["bygglov tillstånd", "tillstånd att bedriva"], confidence: 0.0),
                WordSense(id: "tillstånd.3", definition: "fysikaliskt tillstånd", examples: ["aggregationstillstånd", "grundtillstånd"], confidence: 0.0)
            ],
            "övergång": [
                WordSense(id: "övergång.1", definition: "transition, förändring", examples: ["övergång till nytt system", "energövergång"], confidence: 0.0),
                WordSense(id: "övergång.2", definition: "temporär lösning", examples: ["övergångslösning", "i övergång"], confidence: 0.0)
            ],
            "cykel": [
                WordSense(id: "cykel.1", definition: "fordon", examples: ["åka cykel", "cykelväg", "cyklist"], confidence: 0.0),
                WordSense(id: "cykel.2", definition: "periodiskt förlopp", examples: ["livscykel", "vattencykel", "utvecklingscykel"], confidence: 0.0)
            ],
            "iteration": [
                WordSense(id: "iteration.1", definition: "upprepning i beräkning", examples: ["första iterationen", "iterativ metod"], confidence: 0.0),
                WordSense(id: "iteration.2", definition: "programmeringsiteration", examples: ["loop iteration", "nästa iteration"], confidence: 0.0)
            ],
            "version": [
                WordSense(id: "version.1", definition: "variant, utgåva", examples: ["senaste versionen", "programversion"], confidence: 0.0),
                WordSense(id: "version.2", definition: "tolkning", examples: ["hans version av händelserna", "olika versioner"], confidence: 0.0)
            ],
            "implementation": [
                WordSense(id: "implementation.1", definition: "implementering, verkställande", examples: ["implementation av system", "implementationsfasen"], confidence: 0.0),
                WordSense(id: "implementation.2", definition: "programimplementering", examples: ["kodimplementation", "algoritimplementation"], confidence: 0.0)
            ],
            "evaluera": [
                WordSense(id: "evaluera.1", definition: "utvärdera, bedöma", examples: ["evaluera resultat", "evaluera systemet"], confidence: 0.0)
            ],
            "inferera": [
                WordSense(id: "inferera.1", definition: "sluta, dra slutsats", examples: ["inferera från data", "inferera regel"], confidence: 0.0)
            ],
            "generalisera": [
                WordSense(id: "generalisera.1", definition: "dra allmän slutsats", examples: ["generalisera från exempel", "generalisera för mycket"], confidence: 0.0)
            ],
            "abstrahera": [
                WordSense(id: "abstrahera.1", definition: "generalisera bort detaljer", examples: ["abstrahera bort detaljer", "abstrahera problemet"], confidence: 0.0)
            ],
            "konvergera": [
                WordSense(id: "konvergera.1", definition: "närma sig samma värde", examples: ["serien konvergerar", "metoder konvergerar"], confidence: 0.0),
                WordSense(id: "konvergera.2", definition: "möts i punkt", examples: ["linjer konvergerar", "åsikter konvergerar"], confidence: 0.0)
            ],
            "divergera": [
                WordSense(id: "divergera.1", definition: "avvika, spridas", examples: ["meningar divergerar", "serien divergerar"], confidence: 0.0)
            ],
            "extrapolera": [
                WordSense(id: "extrapolera.1", definition: "förutsäga bortom data", examples: ["extrapolera trenden", "extrapolera till framtiden"], confidence: 0.0)
            ],
            "interpolera": [
                WordSense(id: "interpolera.1", definition: "beräkna mellan värden", examples: ["interpolera data", "linjär interpolering"], confidence: 0.0)
            ],
            "kvantifiera": [
                WordSense(id: "kvantifiera.1", definition: "mäta, ange kvantitet", examples: ["kvantifiera effekten", "kvantifiera resultat"], confidence: 0.0)
            ],
            "validera": [
                WordSense(id: "validera.1", definition: "bekräfta giltighet", examples: ["validera modell", "validera resultat"], confidence: 0.0)
            ],
            "verifiera": [
                WordSense(id: "verifiera.1", definition: "bevisa sannhet", examples: ["verifiera hypotes", "verifiera resultat"], confidence: 0.0)
            ],
            "falsifiera": [
                WordSense(id: "falsifiera.1", definition: "motbevisa, visa falsk", examples: ["falsifiera teori", "falsifierbarhet"], confidence: 0.0)
            ],
            "korrelera": [
                WordSense(id: "korrelera.1", definition: "stå i samband", examples: ["variabler korrelerar", "korrelera med faktor"], confidence: 0.0)
            ],
            "optimera": [
                WordSense(id: "optimera.1", definition: "förbättra till maximum", examples: ["optimera prestanda", "optimera systemet"], confidence: 0.0)
            ],
            "simulera": [
                WordSense(id: "simulera.1", definition: "efterlikna, imitera", examples: ["simulera scenario", "simulera verklighet"], confidence: 0.0),
                WordSense(id: "simulera.2", definition: "låtsas", examples: ["simulera intresse", "simulera sjuk"], confidence: 0.0)
            ],
            "representera": [
                WordSense(id: "representera.1", definition: "stå för, avbilda", examples: ["representera data", "representera väljare"], confidence: 0.0),
                WordSense(id: "representera.2", definition: "företräda", examples: ["representera företag", "representera land"], confidence: 0.0)
            ],
            "manifestera": [
                WordSense(id: "manifestera.1", definition: "visa tydligt, förkroppsliga", examples: ["manifestera sig", "manifestera vilja"], confidence: 0.0)
            ],
            "implikera": [
                WordSense(id: "implikera.1", definition: "innebära, medföra", examples: ["detta implikerar att", "implikera konsekvens"], confidence: 0.0)
            ],
            "entailera": [
                WordSense(id: "entailera.1", definition: "logiskt medföra", examples: ["premiss entailrar slutsats", "logisk entailing"], confidence: 0.0)
            ],
            "presupponera": [
                WordSense(id: "presupponera.1", definition: "förutsätta, ta för givet", examples: ["presupponerar kunskap", "presupposition"], confidence: 0.0)
            ],
            "kontextualisera": [
                WordSense(id: "kontextualisera.1", definition: "sätta i sammanhang", examples: ["kontextualisera fenomen", "kontextualisera data"], confidence: 0.0)
            ],
            "operationalisera": [
                WordSense(id: "operationalisera.1", definition: "gör mätbar, praktisera", examples: ["operationalisera begrepp", "operationalisera variabel"], confidence: 0.0)
            ],
            "dekonstruera": [
                WordSense(id: "dekonstruera.1", definition: "analysera kritiskt", examples: ["dekonstruera text", "dekonstruera begrepp"], confidence: 0.0)
            ],
            "rekonstruera": [
                WordSense(id: "rekonstruera.1", definition: "återskapa, bygga upp", examples: ["rekonstruera händelse", "rekonstruera modell"], confidence: 0.0)
            ],
            "syntetisera": [
                WordSense(id: "syntetisera.1", definition: "sammanfoga till helhet", examples: ["syntetisera information", "syntetisera kemikalie"], confidence: 0.0)
            ],
            "analysera": [
                WordSense(id: "analysera.1", definition: "systematiskt undersöka", examples: ["analysera data", "analysera problem"], confidence: 0.0),
                WordSense(id: "analysera.2", definition: "kemiskt analysera", examples: ["analysera prov", "analysera substans"], confidence: 0.0)
            ],
            "differentiera": [
                WordSense(id: "differentiera.1", definition: "göra skillnad på", examples: ["differentiera produkter", "differentiera funktion"], confidence: 0.0),
                WordSense(id: "differentiera.2", definition: "matematisk derivering", examples: ["differentiera ekvation", "differentiera variabel"], confidence: 0.0)
            ],
            "integrera": [
                WordSense(id: "integrera.1", definition: "sammanfoga, införliva", examples: ["integrera system", "integrera i samhälle"], confidence: 0.0),
                WordSense(id: "integrera.2", definition: "matematisk integration", examples: ["integrera funktion", "integrera ekvation"], confidence: 0.0)
            ],
            "transformera": [
                WordSense(id: "transformera.1", definition: "omvandla, förändra", examples: ["transformera data", "transformera system"], confidence: 0.0)
            ],
            "konstituera": [
                WordSense(id: "konstituera.1", definition: "utgöra, bilda", examples: ["konstituera stat", "konstituerande delar"], confidence: 0.0)
            ],
            "kvalificera": [
                WordSense(id: "kvalificera.1", definition: "uppfylla krav", examples: ["kvalificera sig", "kvalificerad för"], confidence: 0.0),
                WordSense(id: "kvalificera.2", definition: "modifiera, begränsa", examples: ["kvalificera påstående", "kvalificerat uttalande"], confidence: 0.0)
            ],
            "kvantifiera": [
                WordSense(id: "kvantifiera.1", definition: "ange mängd, mäta", examples: ["kvantifiera effekt", "kvantifiera variabler"], confidence: 0.0)
            ],
            "klassificera": [
                WordSense(id: "klassificera.1", definition: "kategorisera, sortera", examples: ["klassificera objekt", "klassificera fenomen"], confidence: 0.0)
            ],
            "kategorisera": [
                WordSense(id: "kategorisera.1", definition: "dela in i kategorier", examples: ["kategorisera data", "kategorisera begrepp"], confidence: 0.0)
            ],
            "hierarkisera": [
                WordSense(id: "hierarkisera.1", definition: "ordna i hierarki", examples: ["hierarkisera behov", "hierarkisera begrepp"], confidence: 0.0)
            ],
            "prioritera": [
                WordSense(id: "prioritera.1", definition: "rangordna efter vikt", examples: ["prioritera uppgifter", "prioritera resurser"], confidence: 0.0)
            ],
            "systematisera": [
                WordSense(id: "systematisera.1", definition: "ordna systematiskt", examples: ["systematisera kunskap", "systematisera data"], confidence: 0.0)
            ],
            "standardisera": [
                WordSense(id: "standardisera.1", definition: "göra enhetlig", examples: ["standardisera metod", "standardisera process"], confidence: 0.0)
            ],
            "normalisera": [
                WordSense(id: "normalisera.1", definition: "återställa till normal", examples: ["normalisera data", "normalisera värden"], confidence: 0.0)
            ],
            "kalibrera": [
                WordSense(id: "kalibrera.1", definition: "justera, ställa in", examples: ["kalibrera instrument", "kalibrera modell"], confidence: 0.0)
            ],
            "minimera": [
                WordSense(id: "minimera.1", definition: "minska till minimum", examples: ["minimera risk", "minimera kostnad"], confidence: 0.0)
            ],
            "maximera": [
                WordSense(id: "maximera.1", definition: "öka till maximum", examples: ["maximera vinst", "maximera prestanda"], confidence: 0.0)
            ],
            "effektivisera": [
                WordSense(id: "effektivisera.1", definition: "göra mer effektiv", examples: ["effektivisera process", "effektivisera arbete"], confidence: 0.0)
            ],
            "rationalisera": [
                WordSense(id: "rationalisera.1", definition: "göra rationell", examples: ["rationalisera produktion", "rationalisera arbetsflöde"], confidence: 0.0),
                WordSense(id: "rationalisera.2", definition: "förklara bort, rättfärdiga", examples: ["rationalisera beteende", "rationalisera beslut"], confidence: 0.0)
            ],
            "förenkla": [
                WordSense(id: "förenkla.1", definition: "göra enklare", examples: ["förenkla modell", "förenkla process"], confidence: 0.0)
            ],
            "komplicera": [
                WordSense(id: "komplicera.1", definition: "göra komplicerad", examples: ["komplicera situation", "komplicera problem"], confidence: 0.0)
            ],
            "försvåra": [
                WordSense(id: "försvåra.1", definition: "göra svårare", examples: ["försvåra arbete", "försvåra utredning"], confidence: 0.0)
            ],
            "begränsa": [
                WordSense(id: "begränsa.1", definition: "sätta gränser", examples: ["begränsa skador", "begränsa möjligheter"], confidence: 0.0)
            ],
            "förhindra": [
                WordSense(id: "förhindra.1", definition: "hindra, stoppa", examples: ["förhindra olycka", "förhindra tillgång"], confidence: 0.0)
            ],
            "möjliggöra": [
                WordSense(id: "möjliggöra.1", definition: "göra möjlig", examples: ["möjliggöra utveckling", "möjliggöra kommunikation"], confidence: 0.0)
            ],
            "underlätta": [
                WordSense(id: "underlätta.1", definition: "göra lättare", examples: ["underlätta arbete", "underlätta process"], confidence: 0.0)
            ],
            "främja": [
                WordSense(id: "främja.1", definition: "stödja, befordra", examples: ["främja utveckling", "främja samarbete"], confidence: 0.0)
            ],
            "stimulera": [
                WordSense(id: "stimulera.1", definition: "uppmuntra, driva", examples: ["stimulera tillväxt", "stimulera aktivitet"], confidence: 0.0)
            ],
            "motivera": [
                WordSense(id: "motivera.1", definition: "ge motiv, driva", examples: ["motivera val", "motivera beslut"], confidence: 0.0),
                WordSense(id: "motivera.2", definition: "inspirera, uppmuntra", examples: ["motivera elever", "motivera teamet"], confidence: 0.0)
            ],
            "inspirera": [
                WordSense(id: "inspirera.1", definition: "ge inspiration", examples: ["inspirera till kreativitet", "inspirerad av"], confidence: 0.0)
            ],
            "övertyga": [
                WordSense(id: "övertyga.1", definition: "få att tro, övertala", examples: ["övertyga någon", "övertygande argument"], confidence: 0.0)
            ],
            "övertala": [
                WordSense(id: "övertala.1", definition: "få att göra något", examples: ["övertala någon att", "övertalad till"], confidence: 0.0)
            ],
            "förhandla": [
                WordSense(id: "förhandla.1", definition: "diskutera fram lösning", examples: ["förhandla avtal", "förhandla fram"], confidence: 0.0)
            ],
            "debattera": [
                WordSense(id: "debattera.1", definition: "diskutera argumenterande", examples: ["debattera frågan", "debattera proposition"], confidence: 0.0)
            ],
            "diskutera": [
                WordSense(id: "diskutera.1", definition: "samtala om", examples: ["diskutera problem", "diskutera lösningar"], confidence: 0.0)
            ],
            "argumentera": [
                WordSense(id: "argumentera.1", definition: "föra fram argument", examples: ["argumentera för", "argumentera emot"], confidence: 0.0)
            ],
            "resonera": [
                WordSense(id: "resonera.1", definition: "tänka logiskt", examples: ["resonera sig fram", "resonera kring"], confidence: 0.0)
            ],
            "redogöra": [
                WordSense(id: "redogöra.1", definition: "förklara, beskriva", examples: ["redogöra för", "redogöra situationen"], confidence: 0.0)
            ],
            "beskriva": [
                WordSense(id: "beskriva.1", definition: "skildra, karaktärisera", examples: ["beskriva fenomen", "beskriva process"], confidence: 0.0)
            ],
            "förklara": [
                WordSense(id: "förklara.1", definition: "göra begripligt", examples: ["förklara fenomen", "förklara för någon"], confidence: 0.0),
                WordSense(id: "förklara.2", definition: "förklara krig, tillstånd", examples: ["förklara krig", "förklara undantagstillstånd"], confidence: 0.0)
            ],
            "artikulera": [
                WordSense(id: "artikulera.1", definition: "uttrycka tydligt", examples: ["artikulera tankar", "artikulera känslor"], confidence: 0.0),
                WordSense(id: "artikulera.2", definition: "uttala tydligt", examples: ["artikulera ord", "artikulera mening"], confidence: 0.0)
            ],
            "uttrycka": [
                WordSense(id: "uttrycka.1", definition: "ge uttryck för", examples: ["uttrycka åsikt", "uttrycka känslor"], confidence: 0.0)
            ],
            "formulera": [
                WordSense(id: "formulera.1", definition: "sätta ord på", examples: ["formulera svar", "formulera problem"], confidence: 0.0)
            ],
            "kommunicera": [
                WordSense(id: "kommunicera.1", definition: "förmedla information", examples: ["kommunicera med", "kommunicera resultat"], confidence: 0.0)
            ],
            "rapportera": [
                WordSense(id: "rapportera.1", definition: "redovisa, meddela", examples: ["rapportera resultat", "rapportera till chef"], confidence: 0.0)
            ],
            "dokumentera": [
                WordSense(id: "dokumentera.1", definition: "skriva ner, spela in", examples: ["dokumentera process", "dokumentera beslut"], confidence: 0.0)
            ],
            "registrera": [
                WordSense(id: "registrera.1", definition: "anteckna, notera", examples: ["registrera resultat", "registrera observation"], confidence: 0.0),
                WordSense(id: "registrera.2", definition: "formellt anmäla", examples: ["registrera företag", "registrera varumärke"], confidence: 0.0)
            ],
            "observera": [
                WordSense(id: "observera.1", definition: "iaktta, se", examples: ["observera fenomen", "observera beteende"], confidence: 0.0)
            ],
            "experimentera": [
                WordSense(id: "experimentera.1", definition: "utföra experiment", examples: ["experimentera med", "experimentera fram"], confidence: 0.0)
            ],
            "utforska": [
                WordSense(id: "utforska.1", definition: "undersöka grundligt", examples: ["utforska område", "utforska möjligheter"], confidence: 0.0)
            ],
            "undersöka": [
                WordSense(id: "undersöka.1", definition: "granska, forska", examples: ["undersöka fenomen", "undersöka samband"], confidence: 0.0)
            ],
            "granska": [
                WordSense(id: "granska.1", definition: "kontrollera, inspektera", examples: ["granska resultat", "granska dokument"], confidence: 0.0)
            ],
            "överväga": [
                WordSense(id: "överväga.1", definition: "tänka noga på", examples: ["överväga alternativ", "överväga förslag"], confidence: 0.0)
            ],
            "begrunda": [
                WordSense(id: "begrunda.1", definition: "fundera djupt", examples: ["begrunda problem", "begrunda frågan"], confidence: 0.0)
            ],
            "fundera": [
                WordSense(id: "fundera.1", definition: "tänka efter", examples: ["fundera på", "fundera över"], confidence: 0.0)
            ],
            "meditera": [
                WordSense(id: "meditera.1", definition: "kontemplera, fokusera", examples: ["meditera över", "meditera i tystnad"], confidence: 0.0)
            ],
            "kontemplera": [
                WordSense(id: "kontemplera.1", definition: "fundera djupt", examples: ["kontemplera tillvaron", "kontemplera frågan"], confidence: 0.0)
            ],
            "reflektera": [
                WordSense(id: "reflektera.1", definition: "eftertänksamt fundera", examples: ["reflektera över", "reflektera kring"], confidence: 0.0),
                WordSense(id: "reflektera.2", definition: "återspegla, kasta tillbaka", examples: ["reflektera ljus", "reflektera ljud"], confidence: 0.0)
            ],
            "taktisera": [
                WordSense(id: "taktisera.1", definition: "planera taktik", examples: ["taktisera inför match", "taktisera strategi"], confidence: 0.0)
            ],
            "strategisera": [
                WordSense(id: "strategisera.1", definition: "utveckla strategi", examples: ["strategisera kring", "strategisera för"], confidence: 0.0)
            ],
            "planera": [
                WordSense(id: "planera.1", definition: "lägga upp plan", examples: ["planera projekt", "planera framtid"], confidence: 0.0)
            ],
            "prognostisera": [
                WordSense(id: "prognostisera.1", definition: "förutsäga, uppskatta", examples: ["prognostisera väder", "prognostisera trend"], confidence: 0.0)
            ],
            "förutsäga": [
                WordSense(id: "förutsäga.1", definition: "prediktera, sia om", examples: ["förutsäga resultat", "förutsäga beteende"], confidence: 0.0)
            ],
            "beräkna": [
                WordSense(id: "beräkna.1", definition: "räkna ut, kalkylera", examples: ["beräkna värde", "beräkna kostnad"], confidence: 0.0)
            ],
            "uppskatta": [
                WordSense(id: "uppskatta.1", definition: "estimerar, gissa", examples: ["uppskatta kostnad", "uppskatta tid"], confidence: 0.0),
                WordSense(id: "uppskatta.2", definition: "värdesätta, vara tacksam", examples: ["uppskatta arbete", "uppskatta hjälp"], confidence: 0.0)
            ],
            "värdera": [
                WordSense(id: "värdera.1", definition: "bedöma värde", examples: ["värdera objekt", "värdera bidrag"], confidence: 0.0)
            ],
            "bedöma": [
                WordSense(id: "bedöma.1", definition: "göra bedömning", examples: ["bedöma situation", "bedöma resultat"], confidence: 0.0)
            ],
            "utvärdera": [
                WordSense(id: "utvärdera.1", definition: "evaluera, granska", examples: ["utvärdera projekt", "utvärdera insats"], confidence: 0.0)
            ],
            "övervaka": [
                WordSense(id: "övervaka.1", definition: "monitorera, bevaka", examples: ["övervaka system", "övervaka patient"], confidence: 0.0)
            ],
            "kontrollera": [
                WordSense(id: "kontrollera.1", definition: "verifiera, inspektera", examples: ["kontrollera resultat", "kontrollera status"], confidence: 0.0),
                WordSense(id: "kontrollera.2", definition: "härska, behärska", examples: ["kontrollera situation", "kontrollera känslor"], confidence: 0.0)
            ],
            "reglera": [
                WordSense(id: "reglera.1", definition: "justera, styra", examples: ["reglera flöde", "reglera temperatur"], confidence: 0.0),
                WordSense(id: "reglera.2", definition: "lagstifta, normera", examples: ["reglera marknad", "reglera beteende"], confidence: 0.0)
            ],
            "balansera": [
                WordSense(id: "balansera.1", definition: "hålla jämvikt", examples: ["balansera på lina", "balansera budget"], confidence: 0.0)
            ],
            "synkronisera": [
                WordSense(id: "synkronisera.1", definition: "samordna i tid", examples: ["synkronisera klockor", "synkronisera data"], confidence: 0.0)
            ],
            "koordinera": [
                WordSense(id: "koordinera.1", definition: "samordna, organisera", examples: ["koordinera arbete", "koordinera insatser"], confidence: 0.0)
            ],
            "strukturera": [
                WordSense(id: "strukturera.1", definition: "organisera strukturellt", examples: ["strukturera data", "strukturera arbete"], confidence: 0.0)
            ],
            "organisera": [
                WordSense(id: "organisera.1", definition: "ordna, systematisera", examples: ["organisera evenemang", "organisera arbete"], confidence: 0.0)
            ],
            "specialisera": [
                WordSense(id: "specialisera.1", definition: "inrikta sig specifikt", examples: ["specialisera sig på", "specialiserad läkare"], confidence: 0.0)
            ],
            "adaptera": [
                WordSense(id: "adaptera.1", definition: "anpassa, ändra", examples: ["adaptera metod", "adaptera till miljö"], confidence: 0.0)
            ],
            "evolvera": [
                WordSense(id: "evolvera.1", definition: "utvecklas gradvis", examples: ["evolvera över tid", "evolvera system"], confidence: 0.0)
            ],
            "transformera": [
                WordSense(id: "transformera.1", definition: "omvandla, ändra form", examples: ["transformera data", "transformera samhälle"], confidence: 0.0)
            ],
            "förändra": [
                WordSense(id: "förändra.1", definition: "göra annorlunda", examples: ["förändra beteende", "förändra system"], confidence: 0.0)
            ],
            "utveckla": [
                WordSense(id: "utveckla.1", definition: "förbättra, bygga vidare", examples: ["utveckla produkt", "utveckla förmåga"], confidence: 0.0)
            ],
            "påverka": [
                WordSense(id: "påverka.1", definition: "ha inverkan på", examples: ["påverka resultat", "påverka beslut"], confidence: 0.0)
            ],
            "fungera": [
                WordSense(id: "fungera.1", definition: "verka, fungera", examples: ["fungera bra", "fungera tillsammans"], confidence: 0.0)
            ],
            "existera": [
                WordSense(id: "existera.1", definition: "finnas till, vara till", examples: ["existera i verkligheten", "existera parallellt"], confidence: 0.0)
            ]
        ]
    }

    func disambiguate(_ text: String) async -> [DisambiguationResult] {
        var results: [DisambiguationResult] = []
        let words = text.lowercased().split(separator: " ").map(String.init)

        for word in words {
            guard let senses = senseDatabase[word] else { continue }

            // Kontextbaserad scoring
            let scoredSenses = scoreSenses(senses, context: text, targetWord: word)
            if let best = scoredSenses.first {
                results.append(DisambiguationResult(
                    word: word,
                    selectedSense: best,
                    allSenses: scoredSenses,
                    confidence: best.confidence
                ))
            }
        }

        return results
    }

    /// Disambiguera med OpenRouter-förbättring
    /// Om OpenRouter är tillgängligt, använd extern WSD för okända eller lågkonfidens-ord
    func disambiguateWithOpenRouter(_ text: String) async -> [DisambiguationResult] {
        var results = await disambiguate(text)
        let words = text.lowercased().split(separator: " ").map(String.init)

        // Hitta ord som saknar WSD eller har låg konfidens
        let unknownWords = words.filter { word in
            !results.contains { $0.word == word } && senseDatabase[word] == nil && word.count > 3
        }

        // Hitta lågkonfidens-resultat
        let lowConfidenceResults = results.filter { $0.confidence < 0.4 }

        if !unknownWords.isEmpty || !lowConfidenceResults.isEmpty {
            // Bygg kontextpar för OpenRouter
            var pairsToEnhance: [(word: String, context: String)] = []

            for word in unknownWords {
                pairsToEnhance.append((word, text))
            }

            for result in lowConfidenceResults {
                pairsToEnhance.append((result.word, text))
            }

            // Batch WSD via OpenRouter (max 10 per batch)
            let batch = Array(pairsToEnhance.prefix(10))
            let openRouterResults = await OpenRouterLanguageEvaluator.shared.batchWSD(batch)

            // Berika resultat med OpenRouter-data
            for orResult in openRouterResults {
                // Lägg till i intern databas för framtida användning
                let newSense = WordSense(
                    id: "\(orResult.word).openrouter.1",
                    definition: orResult.senseDefinition,
                    examples: orResult.senseExamples,
                    confidence: orResult.confidence
                )
                addSenseToDatabase(word: orResult.word, sense: newSense)

                // Uppdatera befintligt resultat eller lägg till nytt
                if let idx = results.firstIndex(where: { $0.word == orResult.word }) {
                    if orResult.confidence > results[idx].confidence {
                        results[idx] = DisambiguationResult(
                            word: orResult.word,
                            selectedSense: newSense,
                            allSenses: [newSense],
                            confidence: orResult.confidence
                        )
                    }
                } else {
                    results.append(DisambiguationResult(
                        word: orResult.word,
                        selectedSense: newSense,
                        allSenses: [newSense],
                        confidence: orResult.confidence
                    ))
                }
            }
        }

        return results
    }

    /// Dynamiskt lägg till ny sense i databasen
    private func addSenseToDatabase(word: String, sense: WordSense) {
        if var existing = senseDatabase[word] {
            // Lägg till ny sense om den inte redan finns
            if !existing.contains(where: { $0.definition == sense.definition }) {
                existing.append(sense)
                senseDatabase[word] = existing
            }
        } else {
            senseDatabase[word] = [sense]
        }
    }

    // ── FAS 2: Embedding-based WSD ──
    func disambiguateWithEmbeddings(_ word: String, context: String) async -> DisambiguationResult? {
        guard let senses = senseDatabase[word], !senses.isEmpty else { return nil }
        let contextEmb = await NeuralEngineOrchestrator.shared.embed(context)
        guard !contextEmb.isEmpty else { return await disambiguate(context).first(where: { $0.word == word }) }
        var bestSense: WordSense? = nil, bestScore: Double = -1.0
        for sense in senses {
            let senseText = "\(sense.definition). \(sense.examples.joined(separator: ". "))"
            let senseEmb = await NeuralEngineOrchestrator.shared.embed(senseText)
            guard !senseEmb.isEmpty else { continue }
            let sim = cosineSim(contextEmb, senseEmb)
            if sim > bestScore { bestScore = sim; bestSense = sense }
        }
        guard let selected = bestSense else { return nil }
        return DisambiguationResult(word: word, selectedSense: selected, allSenses: senses, confidence: bestScore)
    }

    private func cosineSim(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dot: Float = 0, nA: Float = 0, nB: Float = 0
        for i in 0..<a.count { dot += a[i]*b[i]; nA += a[i]*a[i]; nB += b[i]*b[i] }
        let d = sqrt(nA)*sqrt(nB); return d > 0 ? Double(dot/d) : 0.0
    }

    /// Hämta WSD-databasstorlek
    func getWSDSize() -> Int {
        return senseDatabase.count
    }

    /// Få alla kända WSD-ord
    func getAllWSDWords() -> [String] {
        return Array(senseDatabase.keys).sorted()
    }

    private func scoreSenses(_ senses: [WordSense], context: String, targetWord: String) -> [WordSense] {
        let contextWords = context.lowercased().split(separator: " ").map(String.init)
        let contextSet = Set(contextWords.filter { $0.count > 2 && $0 != targetWord })

        // Find target word position for proximity weighting
        let targetIdx = contextWords.firstIndex(of: targetWord) ?? contextWords.count / 2

        return senses.map { sense in
            var score = 0.3 // Baseline

            // Factor 1: Example word overlap (weighted by proximity to target)
            // Iteration 13: Expanded context window to 10 words with graded proximity
            for example in sense.examples {
                let exampleWords = Set(example.lowercased().split(separator: " ").map(String.init))
                let overlap = contextSet.intersection(exampleWords)
                for overlapWord in overlap {
                    if let wordIdx = contextWords.firstIndex(of: overlapWord) {
                        let distance = abs(wordIdx - targetIdx)
                        // Iteration 13: Graded distance weights — 10-word window
                        let proximityWeight: Double
                        if distance <= 2 {
                            proximityWeight = 0.3
                        } else if distance <= 5 {
                            proximityWeight = 0.2
                        } else if distance <= 10 {
                            proximityWeight = 0.1
                        } else {
                            proximityWeight = 0.05 // Beyond 10 words, minimal weight
                        }
                        score += proximityWeight
                    } else {
                        score += 0.15
                    }
                }
            }

            // Factor 2: Definition word overlap with context
            // Iteration 13: Boosted from 0.15 to 0.25 per definition match
            let defWords = Set(sense.definition.lowercased().split(separator: " ").map(String.init).filter { $0.count > 3 })
            let defOverlap = contextSet.intersection(defWords)
            score += Double(defOverlap.count) * 0.25

            // Factor 3: First-sense preference (most common sense gets slight boost)
            if sense.id.hasSuffix(".1") { score += 0.08 }

            // Factor 4: Iteration 14 — Semantic field boost
            // If context words share a semantic field with the sense, boost confidence
            if let semanticBoost = semanticFieldBoost(contextWords: contextWords, sense: sense) {
                score += semanticBoost
            }

            var updated = sense
            updated.confidence = min(0.99, score)
            return updated
        }.sorted { $0.confidence > $1.confidence }
    }

    /// Iteration 14: Semantic field boost
    /// If context words share a semantic field, boost the sense confidence proportionally
    /// - Returns: Boost score (0.0 to 0.5) based on semantic field overlap, or nil if no match
    private func semanticFieldBoost(contextWords: [String], sense: WordSense) -> Double? {
        let contextLower = contextWords.map { $0.lowercased() }
        var bestBoost: Double = 0.0
        var bestField: String?

        for (field, fieldWords) in Self.semanticFields {
            let matchCount = contextLower.filter { fieldWords.contains($0) }.count
            if matchCount > 0 {
                // Boost proportional to number of matching field words
                // Max ~0.5 when many context words share a field
                let boost = min(0.5, Double(matchCount) * 0.08)
                if boost > bestBoost {
                    bestBoost = boost
                    bestField = field
                }
            }
        }

        // Also check if sense definition words align with the best semantic field
        if let field = bestField {
            let defWords = sense.definition.lowercased().components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            let defMatches = defWords.filter { Self.semanticFields[field]?.contains($0) ?? false }.count
            if defMatches > 0 {
                // Additional boost if sense definition also aligns with the semantic field
                return min(0.5, bestBoost + Double(defMatches) * 0.1)
            }
        }

        return bestBoost > 0.0 ? bestBoost : nil
    }

    // v81: Measure how well two texts connect coherently.
    // Use this to evaluate if Eon's response flows naturally from the user's message.
    func textCoherenceScore(text1: String, text2: String) -> Double {
        // (1) Lexical overlap (shared content words)
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 })
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 })
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        let lexicalOverlap = union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)

        // (2) Topic continuity — do they share key nouns/entities?
        let nouns1 = extractContentNouns(text1)
        let nouns2 = extractContentNouns(text2)
        let nounOverlap = nouns1.isEmpty || nouns2.isEmpty ? 0.5 :
            Double(nouns1.intersection(nouns2).count) / Double(max(1, nouns1.union(nouns2).count))

        // (3) Discourse marker — does text2 use connective language that links to text1?
        let coherenceMarkers = [
            "därför", "alltså", "således", "följaktligen", "därmed", "sammanfattningsvis",
            "som sagt", "precis", "exakt", "håller med", "instämmer",
            "å andra sidan", "dock", "emellertid", "men",
            "dessutom", "vidare", "också", "likaså",
            "till exempel", "exempelvis", "särskilt",
            "angående", "gällande", "beträffande",
        ]
        let markerCount = coherenceMarkers.filter { text2.lowercased().contains($0) }.count
        let markerScore = min(1.0, Double(markerCount) * 0.2)

        // (4) Pronoun reference continuity — does text2 reference entities from text1?
        let pronouns = ["den", "det", "de", "dem", "dessa", "denna", "detta", "han", "hon", "hen"]
        let pronounRefs = pronouns.filter { text2.lowercased().contains($0) }.count
        let pronounScore = min(1.0, Double(pronounRefs) * 0.15)

        // (5) Semantic field continuity
        let field1 = detectDominantSemanticField(text1)
        let field2 = detectDominantSemanticField(text2)
        let fieldContinuity = field1 == field2 ? 0.8 : 0.4

        // Weighted composite
        let score = lexicalOverlap * 0.2 + nounOverlap * 0.25 + markerScore * 0.2 +
                    pronounScore * 0.1 + fieldContinuity * 0.25

        return min(1.0, max(0.0, score))
    }

    private func extractContentNouns(_ text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: Set<String> = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation, .omitOther]) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                if word.count > 2 { nouns.insert(word) }
            }
            return true
        }
        return nouns
    }

    private func detectDominantSemanticField(_ text: String) -> String {
        let lower = text.lowercased()
        let words = Set(lower.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 })

        let fieldKeywords: [String: Set<String>] = [
            "emotion": Set(["glad", "ledsen", "arg", "kär", "rädd", "känsla", "emotion", "stressad", "lycklig"]),
            "cognition": Set(["tänka", "veta", "förstå", "lära", "minnas", "kunskap", "insikt", "begripa"]),
            "social": Set(["vän", "familj", "kompis", "samarbete", "kommunikation", "relation", "människa"]),
            "technology": Set(["dator", "program", "kod", "system", "teknik", "digital", "nätverk", "app"]),
            "nature": Set(["skog", "sjö", "berg", "djur", "väder", "miljö", "natur", "klimat"]),
            "time": Set(["tid", "igår", "idag", "imorgon", "snart", "aldrig", "alltid", "ofta", "sällan"]),
        ]

        var bestField = "general"
        var bestScore = 0
        for (field, keywords) in fieldKeywords {
            let score = words.intersection(keywords).count
            if score > bestScore {
                bestScore = score
                bestField = field
            }
        }
        return bestField
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 112: Swedish Poetry Generation
    // ═══════════════════════════════════════════════════════════

    struct SwedishPoem: Sendable {
        let verses: [String]
        let title: String
        let style: String
        let meter: String
        let rhymeScheme: String
        let poeticDevices: [String]
    }

    /// Generate Swedish poems with proper meter, rhyme scheme, and poetic devices.
    func generateSwedishPoem(topic: String, style: String = "lyrisk") async -> SwedishPoem {
        let lowerStyle = style.lowercased()

        // Define rhyme pairs for Swedish poetry
        let rhymePairs: [(String, String)] = [
            ("dag", "lag"), ("natt", "skatt"), ("ljus", "hus"), ("vind", "sinn"),
            ("hjärta", "smärta"), ("dröm", "ström"), ("skog", "bog"), ("hav", "hav"),
            ("sol", "pol"), ("mån", "grön"), ("stjärna", "tjärna"), ("blom", "dom"),
            ("tid", "frid"), ("ljung", "sjung"), ("strand", "land"), ("fågel", "hagel"),
            ("vinter", "finer"), ("sommar", "kommer"), ("hösten", "rösten"), ("våren", "såren"),
            ("kärlek", "särling"), ("vän", "än"), ("liv", "giv"), ("död", "glöd"),
            ("eld", "kall"), ("jord", "ord"), ("himmel", "glimmel"), ("hav", "hav"),
        ]

        // Generate verses based on topic and style
        var verses: [String] = []
        var usedRhymes: Set<String> = []

        // Pick 4 rhyme pairs for 4 verses
        let availableRhymes = rhymePairs.filter { !usedRhymes.contains($0.0) }
        let selectedRhymes = Array(availableRhymes.prefix(4))

        // Verse templates for different styles
        let verseTemplates: [String: [(String, String)]] = [
            "lyrisk": [
                ("Under \(topic)s himmel", "där vinden viskar"),
                ("Och \(topic)s skuggor", "längtar och brinner"),
                ("I \(topic)s famn", "där tystnaden talar"),
                ("Så \(topic) för alltid", "i hjärtat vilar"),
            ],
            "natur": [
                ("Genom \(topic)s skogar", "där fåglarna sjunga"),
                ("Över \(topic)s vatten", "där vinden de leka"),
                ("Bland \(topic)s berg", "där ekot de svarar"),
                ("Till \(topic)s stränder", "där vågorna dansa"),
            ],
            "melankolisk": [
                ("När \(topic)s skymning", "sig sänker ner"),
                ("Och \(topic)s tystnad", "mig omger tungt"),
                ("Då \(topic)s minnen", "som skuggor vandra"),
                ("Så \(topic)s sorg", "mitt hjärta fyller"),
            ],
            "glad": [
                ("Se \(topic)s glädje", "som solen lyser"),
                ("Känn \(topic)s värme", "som sommarns vindar"),
                ("Hör \(topic)s sång", "som fåglarnas kvitter"),
                ("Lev \(topic)s lycka", "i varje ögonblick"),
            ],
        ]

        let template = verseTemplates[lowerStyle] ?? verseTemplates["lyrisk"]!
        for (i, (line1, line2)) in template.enumerated() {
            let rhymeA = selectedRhymes[i % selectedRhymes.count].0
            let rhymeB = selectedRhymes[(i + 1) % selectedRhymes.count].1
            let verse = "\(line1) så \(rhymeA),\n\(line2) med \(rhymeB) i sinnet."
            verses.append(verse)
            usedRhymes.insert(rhymeA)
            usedRhymes.insert(rhymeB)
        }

        // Determine rhyme scheme
        let rhymeScheme = "AABB"

        // Detect poetic devices used
        var poeticDevices: [String] = []
        let fullText = verses.joined(separator: " ").lowercased()
        if fullText.contains("som ") { poeticDevices.append("simile (liknelse)") }
        if fullText.contains("vind") || fullText.contains("viskar") { poeticDevices.append("personifiering") }
        if fullText.contains("hjärta") || fullText.contains("sorg") { poeticDevices.append("känslospråk") }
        if fullText.contains("ljus") || fullText.contains("mörker") { poeticDevices.append("ljus/mörker-kontrast") }
        if poeticDevices.isEmpty { poeticDevices.append("rytm och rim") }

        return SwedishPoem(
            verses: verses,
            title: "Om \(topic)",
            style: style,
            meter: "fem-fotad jamb",
            rhymeScheme: rhymeScheme,
            poeticDevices: poeticDevices
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 114: Persuasion Technique Detection
    // ═══════════════════════════════════════════════════════════

    struct PersuasionTechnique: Identifiable, Sendable {
        let id = UUID()
        let type: PersuasionType
        let text: String
        let explanation: String
        let strength: Double
    }

    enum PersuasionType: String, Sendable, CaseIterable {
        case emotionalAppeal = "känslomässig appell"
        case authorityAppeal = "auktoritetsappell"
        case socialProof = "socialt bevis"
        case scarcity = "brist/ exklusivitet"
        case reciprocity = "reciprocitet"
        case commitment = "commitment/consistency"
        case framing = "ram-sättning"
        case anchoring = "ankare"
        case contrastPrinciple = "kontrastprincipen"
    }

    /// Detect persuasion techniques: emotional appeals, authority, social proof, scarcity,
    /// reciprocity, commitment, framing, anchoring, contrast principle.
    func detectPersuasionTechniques(text: String) -> [PersuasionTechnique] {
        let lower = text.lowercased()
        var techniques: [PersuasionTechnique] = []

        let techniquePatterns: [(pattern: String, type: PersuasionType, explanation: String)] = [
            // Emotional appeal
            ("(tänk på|föreställ dig|känn|upplev).*(barn|familj|kärlek|trygghet|frid|lycka|oro|rädsla|hopp|dröm)", .emotionalAppeal, "Känslomässig appell: använder känsloladdade ord för att påverka"),
            ("(hjärta|själ|känsla|dröm|hopp|kärlek|glädje|sorg|fruktan|längtan)", .emotionalAppeal, "Känslomässig appell: appellerar till läsarens känslor"),

            // Authority appeal
            ("(enligt expert|forskning visar|studier bevisar|experter säger|auktoriteter)", .authorityAppeal, "Auktoritetsappell: hänvisar till expertis som bevis"),
            ("(professor|doktor|expert|myndighet|universitet).*(säger|visar|bevisar|hävdar)", .authorityAppeal, "Auktoritetsappell: använder titel eller auktoritet som stöd"),

            // Social proof
            ("(alla vet|alla gör|alla tycker|majoriteten|de flesta|alla väljer)", .socialProof, "Socialt bevis: alla andra gör det, så bör du också"),
            ("(populärast|bäst säljande|flest användare|mest valda|trend)", .socialProof, "Socialt bevis: popularitet som argument"),

            // Scarcity
            ("(begränsad|sista chansen|endast idag|tillfälligt|få kvar|sista)", .scarcity, "Brist/Exklusivitet: skapar känsla av knapphet"),
            ("(exklusiv|speciell|unique|unik|enbart för|bara för dig)", .scarcity, "Brist/Exklusivitet: framhäver exklusivitet"),

            // Reciprocity
            ("(jag ger dig|gratis|present|erbjudande|som tack|för att hjälpa)", .reciprocity, "Reciprocitet: ger något för att få något tillbaka"),
            ("(tack vare|vi erbjuder|vi ger|du får)", .reciprocity, "Reciprocitet: skapar känsla av tacksamhet"),

            // Commitment/Consistency
            ("(du sa ju|du lovade|som du sade|du har redan|du valde)", .commitment, "Commitment: påminner om tidigare åtaganden"),
            ("(konsekvent|i linje med|som du alltid|dina värderingar)", .commitment, "Consistency: appellerar till önskan om konsekvens"),

            // Framing
            ("(föreställ dig|tänk om|vad skulle hända om|scenariot är)", .framing, "Ram-sättning: presenterar information i en specifik kontext"),
            ("(förlora|missa|risk|fara|problem|hot|utmaning)", .framing, "Ram-sättning: negativ framing med fokus på förlust"),
            ("(vinna|tjäna|få|möjlighet|fördel|nytta|lyckas)", .framing, "Ram-sättning: positiv framing med fokus på vinst"),

            // Anchoring
            ("(normalt kostar|ordinarie pris|jämför med|vanligtvis|standard är)", .anchoring, "Ankare: sätter en referenspunkt för jämförelse"),
            ("(från bara|endast|redan för|så lite som)", .anchoring, "Ankare: lågt pris som ankare"),

            // Contrast principle
            ("(men|dock|emellertid|å andra sidan|istället för|inte bara|inte längre)", .contrastPrinciple, "Kontrastprincipen: skapar kontrast mellan alternativ"),
            ("(före|efter|tidigare|nu|gamla|nya|förbättrad|bättre)", .contrastPrinciple, "Kontrastprincipen: före/efter-kontrast"),
        ]

        for (pattern, type, explanation) in techniquePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(lower.startIndex..., in: lower)
                if regex.firstMatch(in: lower, range: nsRange) != nil {
                    techniques.append(PersuasionTechnique(type: type, text: text, explanation: explanation, strength: 0.7))
                }
            }
        }

        return techniques
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 121: Cultural Reference Detection
    // ═══════════════════════════════════════════════════════════

    struct CulturalReference: Identifiable, Sendable {
        let id = UUID()
        let reference: String
        let type: CulturalReferenceType
        let explanation: String
        let context: String
        let relevance: Double
    }

    enum CulturalReferenceType: String, Sendable {
        case history = "historia"
        case literature = "litteratur"
        case popCulture = "popkultur"
        case tradition = "tradition"
        case geography = "geografi"
        case institution = "institution"
        case food = "matkultur"
        case sport = "sport"
    }

    /// Detect Swedish cultural references: history, literature, pop culture, traditions,
    /// geography, institutions. Explain each.
    func detectCulturalReferences(text: String) -> [CulturalReference] {
        let lower = text.lowercased()
        var references: [CulturalReference] = []

        let culturalDB: [(pattern: String, type: CulturalReferenceType, explanation: String)] = [
            // History
            ("vasatiden", .history, "Vasatiden (1523-1611): Gustav Vasas tid, Sveriges frigörelse från Danmark"),
            ("stormaktstiden", .history, "Stormaktstiden (1611-1718): Sveriges tid som europeisk stormakt"),
            ("gustav vasa", .history, "Gustav Vasa: Sveriges konung 1523-1560, befriade Sverige från unionskungen"),
            ("drottning kristina", .history, "Drottning Kristina: Sveriges drottning 1632-1654, abdikerade och konverterade"),
            ("karl xii", .history, "Karl XII: Sveriges konung 1697-1718, krigade i stora nordiska kriget"),
            ("folkhemsidan", .history, "Folkhemmet: Per-Albin Hanssons vision av Sverige som ett hem för alla"),

            // Literature
            ("astrid lindgren", .literature, "Astrid Lindgren (1907-2002): Författare till Pippi Långstrump, Emil i Lönneberga"),
            ("stieg larsson", .literature, "Stieg Larsson (1954-2004): Författare till Millennium-trilogin"),
            ("ingmar bergman", .literature, "Ingmar Bergman (1918-2007): Filmregissör, ett av Sveriges största filmnamn"),
            ("evert taube", .literature, "Evert Taube (1890-1976): Författare, konstnär och trubadur"),
            ("bellman", .literature, "Carl Michael Bellman (1740-1795): Skald och tonsättare, Fredmans epistlar"),
            ("strindberg", .literature, "August Strindberg (1849-1912): Författare, dramatiker, Röda rummet"),
            ("selma lagerlöf", .literature, "Selma Lagerlöf (1858-1940): Författare, Nobelpristagare 1909, Gösta Berlings saga"),

            // Pop culture
            ("abba", .popCulture, "ABBA: Svenskt popband (1972-1982), världens mest framgångsrika svenska musikgrupp"),
            ("avicii", .popCulture, "Avicii (Tim Bergling, 1989-2018): Svensk DJ och producent, pionjär inom EDM"),
            ("zlatan ibrahimovic", .popCulture, "Zlatan Ibrahimovic: Svensk fotbollsspelare, en av Sveriges största idrottare"),
            ("greta thunberg", .popCulture, "Greta Thunberg: Svensk klimataktivist, startade Fridays for Future"),

            // Traditions
            ("midsommar", .tradition, "Midsommar: Svensk högtid i juni, firas med midsommarstång, dans och sång"),
            ("lucia", .tradition, "Lucia (13 december): Svenskt ljusfirande med luciatåg och pepparkakor"),
            ("kräftskiva", .tradition, "Kräftskiva: Svensk festtradition i augusti med kräftor, snaps och sång"),
            ("fika", .tradition, "Fika: Svensk tradition att ta kaffe- och fikapaus, ofta med kanelbulle"),
            ("valborg", .tradition, "Valborgsmässoafton (30 april): Brasa och sång för att fira våren"),
            ("julbord", .tradition, "Julbord: Svenskt traditionellt julbord med sill, köttbullar, Janssons frestelse"),
            ("lagom", .tradition, "Lagom: Svenskt begrepp för 'just lagom', varken för mycket eller för lite"),
            ("allemansrätten", .tradition, "Allemansrätten: Rätten att fritt vistas i naturen, även på privat mark"),

            // Geography
            ("stockholm", .geography, "Stockholm: Sveriges huvudstad, 'skönheten på 14 öar'"),
            ("göteborg", .geography, "Göteborg: Sveriges näst största stad, vid Västkusten"),
            ("malmö", .geography, "Malmö: Sveriges tredje största stad, i Skåne med Öresundsbron"),
            ("gotland", .geography, "Gotland: Sveriges största ö, känt för raukar och Visby ringmur"),
            ("lappland", .geography, "Lappland: Nordligaste landskapet, känt för fjäll, samekultur och midnattssol"),
            ("skåne", .geography, "Skåne: Sydligaste landskapet, känt för slätter, kusten och danska influenser"),

            // Institutions
            ("riksdagen", .institution, "Riksdagen: Sveriges lagstiftande församling, världens första kvinnliga val 1921"),
            ("nobelpriset", .institution, "Nobelpriset: Världens främsta pris, instiftat av Alfred Nobel, delas ut i Stockholm"),
            ("systembolaget", .institution, "Systembolaget: Sveriges alkoholmonopol, statligt ägt, unikt i världen"),
            ("fackförbund", .institution, "Fackförbund: Svenska arbetstagarorganisationer, hög organisationsgrad"),

            // Food culture
            ("köttbullar", .food, "Svenska köttbullar: Traditionell svensk husmanskost, serveras med lingon"),
            ("kanelbulle", .food, "Kanelbulle: Sveriges nationalfika, firas med Kanelbullens dag 4 oktober"),
            ("surströmming", .food, "Surströmming: Norrländsk specialitet, jäst strömming, stark lukt"),
            ("räkmacka", .food, "Räkmacka: Svensk klassiker med räkor, majonnäs och dill på smörgås"),
            ("gravlax", .food, "Gravlax: Inlagd lax med dill, traditionell svensk förrätt"),

            // Sport
            ("allsvenskan", .sport, "Allsvenskan: Sveriges högsta fotbollsdivision, grundad 1924"),
            ("vasaloppet", .sport, "Vasaloppet: Världens längsta skidtävling (90 km), sedan 1922"),
            ("ishockey", .sport, "Ishockey: Sveriges näst största sport, flera VM-guld"),
            ("henrik stenson", .sport, "Henrik Stenson: Svensk golfspelare, major-vinnare"),
        ]

        for (pattern, type, explanation) in culturalDB {
            if lower.contains(pattern) {
                references.append(CulturalReference(
                    reference: pattern,
                    type: type,
                    explanation: explanation,
                    context: text,
                    relevance: 0.8
                ))
            }
        }

        return references
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 126: Emotional Subtext Detection
    // ═══════════════════════════════════════════════════════════

    struct EmotionalSubtext: Sendable {
        let primaryEmotion: String
        let confidence: Double
        let hiddenEmotions: [String: Double]
        let analysis: String
        let cues: [String]
    }

    /// Detect what the speaker FEELS but doesn't explicitly say: frustration behind politeness,
    /// excitement masked as casual mention, sadness hidden in neutral description.
    func detectEmotionalSubtext(text: String) -> EmotionalSubtext {
        let lower = text.lowercased()
        let words = Set(lower.components(separatedBy: .whitespacesAndNewlines))

        var hiddenEmotions: [String: Double] = [:]
        var cues: [String] = []

        // Frustration behind politeness
        let politeFrustrationMarkers = Set(["tack", "snälla", "skulle", "kan du", "om det går", "ursäkta", "förlåt", "jag undrar", "kanske", "möjligtvis"])
        let frustrationMarkers = Set(["igen", "alltid", "fortfarande", "väntar", "aldrig", "än", "ändå", "redan"])
        if words.intersection(politeFrustrationMarkers).count >= 2 && words.intersection(frustrationMarkers).count >= 1 {
            hiddenEmotions["frustration"] = 0.8
            cues.append("Politeness markers combined with temporal frustration words")
        }

        // Excitement masked as casual mention
        let excitementMarkers: Set<String> = ["fantastiskt", "wow", "äntligen", "hurra", "grymt", "awesome", "super", "jättebra", "underbart", "perfekt", "lycklig", "glad"]
        let casualMarkers: Set<String> = ["förresten", "just det", "jag nämnde", "bara så", "för övrigt", "i förbigående"]
        if words.intersection(casualMarkers).count >= 1 && words.intersection(excitementMarkers).count >= 1 {
            hiddenEmotions["excitement"] = 0.7
            cues.append("Excitement words framed as casual mention")
        }

        // Sadness hidden in neutral description
        let sadnessMarkers = Set(["ensam", "tom", "mörker", "kall", "tyst", "borta", "förlorad", "ledsen", "trött", "gråter", "saknar", "längtar"])
        let neutralDescriptions = Set(["var", "fanns", "hände", "blev", "gick", "stod", "låg", "såg"])
        if words.intersection(sadnessMarkers).count >= 2 && words.intersection(neutralDescriptions).count >= 2 {
            hiddenEmotions["sadness"] = 0.75
            cues.append("Sadness-related words in neutral descriptive context")
        }

        // Anxiety masked as practicality
        let anxietyMarkers: Set<String> = ["oro", "oroa", "oroar", "osäker", "kanske", "förhoppningsvis", "jag undrar", "tänka på", "stress", "press", "måste", "hinner"]
        let practicalMarkers: Set<String> = ["plan", "schema", "lista", "ordning", "struktur", "organisation", "detalj", "kalender", "tidplan"]
        if words.intersection(anxietyMarkers).count >= 2 && words.intersection(practicalMarkers).count >= 1 {
            hiddenEmotions["anxiety"] = 0.65
            cues.append("Anxiety words disguised as practical planning")
        }

        // Anger masked as humor
        let angerMarkers: Set<String> = ["arg", "förbannad", "ursinne", "rasande", "irriterad", "frustrerad", "drygt", "orättvist", "fel", "vidrig"]
        let humorMarkers: Set<String> = ["haha", "lol", "skämt", "roligt", "skojar", "bara", "kul", "skoj"]
        if words.intersection(angerMarkers).count >= 1 && words.intersection(humorMarkers).count >= 1 {
            hiddenEmotions["anger"] = 0.6
            cues.append("Anger words softened with humor markers")
        }

        // Determine primary emotion
        let primaryEmotion = hiddenEmotions.max { $0.value < $1.value }?.key ?? "neutral"
        let confidence = hiddenEmotions[primaryEmotion] ?? 0.1

        // Generate analysis
        let analysis: String
        switch primaryEmotion {
        case "frustration":
            analysis = "Talaren verkar frustrerad men döljer det bakom artiga fraser. Det finns en underliggande otålighet."
        case "excitement":
            analysis = "Talaren är upphetsad men försöker framstå som avslappnad. En casual 'förresten' döljer verklig entusiasm."
        case "sadness":
            analysis = "Bakom den neutrala beskrivningen finns en underliggande sorg. Talaren beskriver förlust genom sakliga ordval."
        case "anxiety":
            analysis = "Talaren döljer oro bakom praktisk planering. Detaljfokuset kan vara ett sätt att hantera osäkerhet."
        case "anger":
            analysis = "Talaren är arg men maskerar det med humor. Skämtet fungerar som en ventil för frustration."
        default:
            analysis = "Ingen tydlig känslomässig undertext upptäckt. Texten verkar vara vad den är."
        }

        return EmotionalSubtext(
            primaryEmotion: primaryEmotion,
            confidence: confidence,
            hiddenEmotions: hiddenEmotions,
            analysis: analysis,
            cues: cues
        )
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 129: Humor and Playfulness Detection
    // ═══════════════════════════════════════════════════════════

    struct HumorAnalysis: Sendable {
        let detectedHumor: Bool
        let humorType: String
        let confidence: Double
        let humorElements: [String]
        let swedishSpecificPatterns: [String]
    }

    /// Detect: jokes, puns, wordplay, irony, sarcasm, self-deprecating humor, absurdism,
    /// dry humor, Swedish-specific humor patterns.
    func detectHumorAndPlayfulness(text: String) -> HumorAnalysis {
        let lower = text.lowercased()
        var humorElements: [String] = []
        var swedishPatterns: [String] = []
        var confidence = 0.0

        // Laughter markers
        let laughterMarkers = Set(["haha", "lol", "hehe", "ahaha", "fniss", "skratt", "rofl", "😂", "🤣", "😄", "😅"])
        if lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { laughterMarkers.contains($0) }) {
            humorElements.append("skrattmarkörer")
            confidence += 0.3
        }

        // Puns and wordplay
        let punPatterns = Set(["ordvits", "skämt", "paj", "roligt", "kul", "lustigt", "komiskt", "absurt"])
        if lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { punPatterns.contains($0) }) {
            humorElements.append("ordvits/ skämt")
            confidence += 0.2
        }

        // Irony and sarcasm
        let ironyMarkers: Set<String> = ["så klart", "naturligtvis", "precis", "absolut", "typiskt", "typ", "tackar", "ja juste"]
        let negativeContext: Set<String> = ["dåligt", "fel", "problem", "krångel", "trasig", "krånglar", "seg", "dålig", "taskigt"]
        if lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { ironyMarkers.contains($0) }) &&
           lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { negativeContext.contains($0) }) {
            humorElements.append("ironi/sarkasm")
            confidence += 0.25
        }

        // Self-deprecating humor
        let selfDeprecating = Set(["jag är så", "som vanligt", "klassiskt mig", "typiskt jag", "igen", "alltid jag", "min tur"])
        if lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { selfDeprecating.contains($0) }) {
            humorElements.append("självironi")
            swedishPatterns.append("självironi — typiskt svenskt")
            confidence += 0.2
        }

        // Swedish dry humor (torr humor)
        let dryHumor: Set<String> = ["precis", "okej", "nåväl", "jaha", "jaså", "nämen", "okejdå", "aja baja", "typiskt"]
        if lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { dryHumor.contains($0) }) {
            humorElements.append("torr humor")
            swedishPatterns.append("Torr humor — klassiskt svensk underdrift")
            confidence += 0.15
        }

        // Absurdism
        let absurdMarkers: Set<String> = ["absurt", "konstigt", "konstig", "bisarrt", "underligt", "konstigt nog", "vemodigt"]
        if lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { absurdMarkers.contains($0) }) {
            humorElements.append("absurdism")
            confidence += 0.15
        }

        // Swedish-specific: "lagom" humor, understatement
        let swedishUnderstatement: Set<String> = ["ganska", "hyfsat", "någorlunda", "relativt", "måttligt", "lagom"]
        if lower.components(separatedBy: .whitespacesAndNewlines).contains(where: { swedishUnderstatement.contains($0) }) &&
           (lower.contains("roligt") || lower.contains("kul") || lower.contains("skoj")) {
            swedishPatterns.append("Underdrift — 'lagom' roligt")
            confidence += 0.1
        }

        confidence = min(1.0, confidence)

        let humorType: String
        if humorElements.isEmpty {
            humorType = "ingen humor upptäckt"
        } else if humorElements.contains("ironi/sarkasm") {
            humorType = "ironi/sarkasm"
        } else if humorElements.contains("självironi") {
            humorType = "självironi"
        } else if humorElements.contains("torr humor") {
            humorType = "svensk torr humor"
        } else if humorElements.contains("ordvits/ skämt") {
            humorType = "ordvits/skämt"
        } else {
            humorType = humorElements.joined(separator: ", ")
        }

        return HumorAnalysis(
            detectedHumor: confidence > 0.3,
            humorType: humorType,
            confidence: confidence,
            humorElements: humorElements,
            swedishSpecificPatterns: swedishPatterns
        )
    }
}
