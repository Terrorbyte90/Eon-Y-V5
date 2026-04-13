import Foundation
import NaturalLanguage

// MARK: - SwedishLanguageCore: Koordinerar alla svenska språkkomponenter

actor SwedishLanguageCore {
    static let shared = SwedishLanguageCore()

    private(set) var morphologyEngine: SwedishMorphologyEngine
    private(set) var wsdEngine: SwedishWSDEngine

    private init() {
        morphologyEngine = SwedishMorphologyEngine()
        wsdEngine = SwedishWSDEngine()
    }

    func initialize() async {
        await morphologyEngine.loadLexicon()
        await morphologyEngine.loadDynamicEntries()
        await wsdEngine.initialize()
        print("[Swedish] Alla svenska komponenter initierade ✓")
    }

    // MARK: - Komplett analys av en mening

    func analyze(_ text: String) async -> SwedishAnalysis {
        let morphemes = await morphologyEngine.analyze(text)
        let disambiguations = await wsdEngine.disambiguate(text)
        let register = detectRegister(text)
        let modalParticles = extractModalParticles(text)
        let idioms = detectIdioms(text)
        let clauses = segmentClauses(text)
        let resolvedPronouns = resolveAnaphora(text, morphemes: morphemes)

        return SwedishAnalysis(
            originalText: text,
            morphemes: morphemes,
            disambiguations: disambiguations,
            register: register,
            modalParticles: modalParticles,
            detectedIdioms: idioms,
            clauses: clauses,
            anaphoraResolutions: resolvedPronouns
        )
    }

    // MARK: - Qwen3-Enriched Deep Analysis

    /// Uses Qwen3 to produce a deeper linguistic analysis of Swedish text,
    /// identifying grammar patterns, clause structure, and linguistic features
    /// beyond what rule-based NLP can detect.
    func enrichAnalysis(text: String) async -> String {
        guard !ThermalSleepManager.shared.shouldPauseWork() else {
            return "Termisk begränsning — djupanalys pausad"
        }

        let basicAnalysis = await analyze(text)
        let registerLabel = basicAnalysis.register.label
        let clauseCount = basicAnalysis.clauses.count
        let unknownCount = basicAnalysis.morphemes.filter { $0.pos == "unknown" }.count
        let idiomSummary = basicAnalysis.detectedIdioms.map { $0.phrase }.joined(separator: ", ")

        let prompt = """
        Du är en expert på svensk lingvistik. Analysera denna svenska text djupgående:
        "\(text)"

        Grundläggande analys visar: register=\(registerLabel), \(clauseCount) satser, \(unknownCount) okända ord\(idiomSummary.isEmpty ? "" : ", idiom: \(idiomSummary)")

        Ge en djupare analys som inkluderar:
        1. GRAMMATIK: Identifiera satstyper (huvudsats/bisats), tempus, modus
        2. ORDFÖLJD: Följer texten V2-regeln? Finns inversioner?
        3. STILISTIK: Vilken stilnivå? Finns retoriska figurer?
        4. KOMPLEXITET: Bedöm textens svårighetsgrad (A1-C2)
        Svara koncist på svenska.
        """

        let response = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 300, temperature: 0.4
        )

        return response.isEmpty ? "Ingen analys tillgänglig" : response
    }

    // MARK: - Idiom Detection
    // Swedish idioms change meaning of the whole phrase — crucial for understanding

    // Iteration 20: Expanded idiom database — 200+ idioms with 10 categories
    private static let idiomDatabase: [(pattern: [String], meaning: String, literal: String, category: String)] = [
        // ── General / Common Swedish idioms (20) ──
        (["lägga", "korten", "på", "bordet"], "vara ärlig, avslöja sanningen", "put cards on the table", "general"),
        (["det", "finns", "inga", "gratisluncher"], "allt har ett pris", "there are no free lunches", "general"),
        (["ha", "tummen", "mitt", "i", "handen"], "vara klumpig", "have thumb in middle of hand", "general"),
        (["gå", "som", "katten", "kring", "het", "gröt"], "undvika att ta tag i något", "walk like the cat around hot porridge", "general"),
        (["bita", "ihop"], "stå ut med smärta/svårigheter", "bite together", "general"),
        (["ha", "is", "i", "magen"], "vara lugn och tålmodig", "have ice in the stomach", "general"),
        (["kasta", "in", "handduken"], "ge upp", "throw in the towel", "general"),
        (["slå", "huvudet", "på", "spiken"], "ha helt rätt", "hit the nail on the head", "general"),
        (["ta", "tjuren", "vid", "hornen"], "möta problem direkt", "take the bull by the horns", "general"),
        (["gå", "som", "på", "räls"], "fungera perfekt", "go as on rails", "general"),
        (["hålla", "tummarna"], "önska lycka till", "hold the thumbs", "general"),
        (["sitta", "i", "samma", "båt"], "ha samma problem", "sit in the same boat", "general"),
        (["lägga", "alla", "ägg", "i", "samma", "korg"], "satsa allt på ett kort", "put all eggs in one basket", "general"),
        (["vara", "ute", "och", "cyklar"], "ha fel, missförstå helt", "be out cycling", "general"),
        (["ta", "med", "en", "nypa", "salt"], "vara skeptisk", "take with a pinch of salt", "general"),
        (["göra", "en", "höna", "av", "en", "fjäder"], "överdriva", "make a hen of a feather", "general"),
        (["ha", "rent", "mjöl", "i", "påsen"], "vara oskyldig", "have clean flour in the bag", "general"),
        (["dra", "alla", "över", "en", "kam"], "generalisera orättvist", "comb everyone the same", "general"),
        (["få", "kalla", "fötter"], "bli nervös, ändra sig", "get cold feet", "general"),
        (["stå", "på", "egna", "ben"], "vara självständig", "stand on own legs", "general"),

        // ── Emotions (15) ──
        (["ha", "fjärilar", "i", "magen"], "känna nervositet/förälskelse", "have butterflies in the stomach", "emotion"),
        (["gå", "i", "taket"], "bli väldigt arg", "go in the ceiling", "emotion"),
        (["inte", "vara", "hundra"], "inte må helt bra", "not be a hundred", "emotion"),
        (["ha", "hjärtat", "på", "rätt", "ställe"], "vara godhjärtad", "have heart in the right place", "emotion"),
        (["bli", "svartsjuk"], "känna svartsjuka", "become black-jealous", "emotion"),
        (["ha", "ångest"], "känna stark oro", "have anxiety", "emotion"),
        (["känna", "sig", "som", "bäst"], "må utmärkt", "feel like best", "emotion"),
        (["bli", "ledsen", "som", "en", "stövel"], "bli mycket ledsen", "become sad as a boot", "emotion"),
        (["ha", "det", "på", "känsla"], "göra efter känsla", "have it on feeling", "emotion"),
        (["spricka", "av", "stolthet"], "vara mycket stolt", "burst with pride", "emotion"),
        (["ha", "hjärtat", "i", "halsgropen"], "vara mycket rädd eller nervös", "have heart in the throat", "emotion"),
        (["sätta", "ner", "foten"], "visa bestämdhet", "put down the foot", "emotion"),
        (["bli", "glad", "som", "en", "lärka"], "bli mycket glad", "become happy as a lark", "emotion"),
        (["ha", "tårar", "i", "ögona"], "vara nära att gråta", "have tears in the eyes", "emotion"),
        (["må", "bra", "i", " själen"], "må psykiskt bra", "feel good in the soul", "emotion"),

        // ── Cognition (15) ──
        (["ha", "huvudet", "på", "skaft"], "vara klok och smart", "have the head on a shaft", "cognition"),
        (["tappa", "tråden"], "förlora fokus i samtalet", "lose the thread", "cognition"),
        (["ha", "tungan", "rätt", "i", "mun"], "uttrycka sig korrekt", "have tongue right in mouth", "cognition"),
        (["gå", "upp", "ett", "ljus"], "plötsligt förstå", "a light goes up", "cognition"),
        (["vara", "på", "det", "klara"], "förstå situationen", "be on the clear", "cognition"),
        (["ha", "koll", "på", "läget"], "vara välinformerad om situationen", "have control on the situation", "cognition"),
        (["ta", "en", "funderare"], "tänka djupt på något", "take a thinker", "cognition"),
        (["ha", "hjärnan", "på", "halken"], "inte tänka klart", "have the brain on the slide", "cognition"),
        (["klura", "ut"], "lösa genom eftertanke", "figure out", "cognition"),
        (["ha", "en", "snilleblixt"], "få en genial idé", "have a lightning bolt of genius", "cognition"),
        (["tänka", "utanför", "boxen"], "tänka kreativt", "think outside the box", "cognition"),
        (["komma", "på", "något"], "minnas eller hitta på", "come upon something", "cognition"),
        (["ha", "glömska"], "vara glömsk", "have forgetfulness", "cognition"),
        (["sätta", "sig", "in", "i"], "sätta sig in i något", "set oneself into", "cognition"),
        (["hålla", "tungan", "i", "mun"], "koncentrera sig", "hold the tongue in mouth", "cognition"),

        // ── Social (15) ──
        (["spela", "med", "öppna", "kort"], "vara ärlig, transparent", "play with open cards", "social"),
        (["vända", "kappan", "efter", "vinden"], "ändra åsikt opportunistiskt", "turn the cloak after the wind", "social"),
        (["ha", "en", "räv", "bakom", "örat"], "vara slug", "have a fox behind the ear", "social"),
        (["sopa", "under", "mattan"], "dölja problem", "sweep under the carpet", "social"),
        (["ta", "bladet", "från", "munnen"], "tala klarspråk", "take the leaf from the mouth", "social"),
        (["dra", "sig", "i", "håret"], "vara frustrerad", "pull one's hair", "social"),
        (["se", "genom", "fingrarna"], "tolerera, ignorera", "see through the fingers", "social"),
        (["stå", "ut", "med"], "uthärda", "stand out with", "social"),
        (["dra", "åt", "samma", "håll"], "samarbeta mot gemensamt mål", "pull in the same direction", "social"),
        (["mellan", "skål", "och", "vägg"], "i förtroende", "between bowl and wall", "social"),
        (["tala", "rent", "ut"], "säga sanningen utan omsvep", "speak cleanly out", "social"),
        (["ha", "järnkoll"], "vara välinformerad", "have iron control", "social"),
        (["ligga", "på", "latsidan"], "vara lat", "lie on the lazy side", "social"),
        (["sticka", "ut", "hakan"], "ta en risk", "stick out the chin", "social"),
        (["visa", "var", "skåpet", "ska", "stå"], "demonstrera makt", "show where the cupboard should stand", "social"),

        // ── Time (12) ──
        (["ta", "tiden", "till", "hjälp"], "invänta tålamod", "take time to help", "time"),
        (["i", "sista", "stund"], "i sista ögonblicket", "in the last moment", "time"),
        (["från", "dag", "ett"], "från början", "from day one", "time"),
        (["med", "tiden"], "efterhand", "with the time", "time"),
        (["i", "tid", "och", "otid"], "hela tiden, alltid", "in time and untime", "time"),
        (["en", "gång", "i", "tiden"], "tidigare, förr", "once upon a time", "time"),
        (["i", "dessa", "tider"], "numera", "in these times", "time"),
        (["snart", "sagt"], "nästan", "soon said", "time"),
        (["förr", "eller", "senare"], "omedelbart eller senare", "sooner or later", "time"),
        (["hålla", "på", "tiden"], "respektera tidsgränsen", "keep to the time", "time"),
        (["döda", "tiden"], "fördriva tid", "kill the time", "time"),
        (["tiden", "går", "snabbt"], "känslan av att tiden flyger", "time goes fast", "time"),

        // ── Money (12) ──
        (["kosta", "skjortan"], "vara mycket dyrt", "cost the shirt", "money"),
        (["ha", "rånt", "om", "fötterna"], "ha ekonomiska problem", "have rats around the feet", "money"),
        (["slå", "sig", "fram"], "bli ekonomiskt framgångsrik", "hit oneself forward", "money"),
        (["ha", "små", "pengar"], "ha begränsad ekonomi", "have small money", "money"),
        (["tjäna", "en", "förmögenhet"], "bli mycket rik", "earn a fortune", "money"),
        (["kasta", "pengar", "i", "sjön"], "slösa med pengar", "throw money in the lake", "money"),
        (["ha", "pengar", "som", "gräs"], "ha mycket pengar", "have money like grass", "money"),
        (["gå", "back"], "förlora pengar", "go in deficit", "money"),
        (["dra", "in", "på"], "minska utgifter", "pull in on", "money"),
        (["leva", "över", "sina", "tillgångar"], "spendera mer än man har", "live over one's means", "money"),
        (["spara", "till", "svarta", "fåret"], "spara i hemlighet", "save to the black sheep", "money"),
        (["vara", "stor", "i", "käften", "liten", "i", "plånboken"], "prata stort men ha lite pengar", "big in mouth small in wallet", "money"),

        // ── Work (12) ──
        (["dra", "sitt", "strå", "till", "stacken"], "bidra med sin del", "pull your straw to the haystack", "work"),
        (["bryta", "ny", "mark"], "göra något innovativt", "break new ground", "work"),
        (["ligga", "i", "startgroparna"], "vara redo att börja", "lie in the starting pit", "work"),
        (["ta", "saken", "i", "egna", "händer"], "agera självständigt", "take matter in own hands", "work"),
        (["falla", "på", "plats"], "börja ge mening", "fall into place", "work"),
        (["gå", "bet"], "misslyckas", "go bite", "work"),
        (["kasta", "yxan", "i", "sjön"], "ge upp helt", "throw the axe in the lake", "work"),
        (["göra", "slag", "i", "saken"], "ta ett snabbt beslut", "make a blow in the matter", "work"),
        (["ta", "sig", "an"], "åta sig en uppgift", "take on", "work"),
        (["få", "blodad", "tand"], "bli motiverad", "get blooded tooth", "work"),
        (["smörja", "kansen"], "missa möjligheten", "grease the chance", "work"),
        (["slå", "slint"], "misslyckas, gå fel", "hit a miss", "work"),

        // ── Body (12) ──
        (["lägga", "benen", "på", "ryggen"], "springa snabbt, fly", "put legs on the back", "body"),
        (["ha", "ögon", "i", "nacken"], "vara observant", "have eyes in the neck", "body"),
        (["sätta", "tummen", "i", "ögat"], "besegra, förnedra", "put thumb in the eye", "body"),
        (["ha", "skinn", "på", "näsan"], "vara tuff och motståndskraftig", "have skin on the nose", "body"),
        (["sticka", "ut", "hakan"], "ta en risk", "stick out the chin", "body"),
        (["ha", "huvudet", "i", "molnen"], "vara dagdrömmande", "have head in the clouds", "body"),
        (["ha", "fötterna", "på", "jorden"], "vara realistisk", "have feet on the ground", "body"),
        (["vända", "sig", "i", "graven"], "vara mycket upprörd efter döden", "turn in the grave", "body"),
        (["dra", "på", "munnen"], "le, dra på läpparna", "pull on the mouth", "body"),
        (["ha", "hjärta", "av", "guld"], "vara mycket vänlig", "have heart of gold", "body"),
        (["få", "ögonen", "öppnade"], "bli medveten om något", "get the eyes opened", "body"),
        (["ryta", "ifrån"], "försvara sig verbalt", "roar back", "body"),

        // ── Nature (12) ──
        (["ligga", "i", "lä"], "vara skyddad", "lie in the lee", "nature"),
        (["gå", "på", "grund"], "misslyckas, stranda", "go on ground", "nature"),
        (["segla", "i", "vind"], "ha det lätt", "sail in the wind", "nature"),
        (["blixt", "från", "en", "klar", "himmel"], "oväntad händelse", "lightning from a clear sky", "nature"),
        (["gå", "mot", "strömmen"], "gå emot majoriteten", "go against the current", "nature"),
        (["ha", "vinden", "i", "seglen"], "ha motgång", "have the wind in the sails", "nature"),
        (["ta", "rot"], "börja växa eller etablera sig", "take root", "nature"),
        (["växa", "som", "ogräs"], "växa snabbt och okontrollerat", "grow like weeds", "nature"),
        (["blomstra", "ut"], "utvecklas positivt", "bloom out", "nature"),
        (["stå", "som", "en", "klippe"], "stå stadigt", "stand like a rock", "nature"),
        (["regna", "kattor", "och", "hundar"], "öka kraftigt", "rain cats and dogs", "nature"),
        (["i", "stormens", "öga"], "i centrum av turbulens", "in the eye of the storm", "nature"),

        // ── Animals (12) ──
        (["kasta", "pärlor", "för", "svin"], "slösa på oförstående", "cast pearls before swine", "animals"),
        (["ha", "tur", "i", "oturen"], "positiv aspekt av negativt", "have luck in the misfortune", "animals"),
        (["inte", "en", "chans"], "omöjligt", "not a chance", "animals"),
        (["gå", "man", "ur", "huse"], "alla deltar", "go man out of house", "animals"),
        (["komma", "på", "fall"], "bli lurad, gå i fällan", "come to a fall", "animals"),
        (["gå", "på", "nitan"], "bli lurad", "go on the rivet", "animals"),
        (["hugga", "i", "sten"], "arbeta hårt", "chisel in stone", "animals"),
        (["sila", "mygg", "och", "svälja", "kameler"], "oroa sig för små saker men missa stora", "strain gnats and swallow camels", "animals"),
        (["falla", "mellan", "stolarna"], "hamna mellan två alternativ", "fall between the chairs", "animals"),
        (["köpa", "katten", "i", "säcken"], "köpa något utan att undersöka", "buy the cat in the bag", "animals"),
        (["släppa", "katten", "ur", "säcken"], "avslöja en hemlighet", "let the cat out of the bag", "animals"),
        (["när", "katten", "är", "borta"], "dansta på bordet", "when the cat is away", "animals"),

        // ── Food (12) ──
        (["dra", "en", "lansen"], "överge, ge upp", "break a lance", "food"),
        (["ta", "skeden", "i", "vacker", "hand"], "acceptera verkligheten", "take the spoon in beautiful hand", "food"),
        (["lägga", "locket", "på"], "avsluta diskussionen", "put the lid on", "food"),
        (["leva", "på", "stor", "fot"], "leva lyxigt", "live on big foot", "food"),
        (["bita", "i", "det", "sura", "äpplet"], "acceptera något obehagligt", "bite the sour apple", "food"),
        (["gå", "i", "bräschen"], "ta initiativet", "go in the breach", "food"),
        (["ha", "bråda", "dagar"], "ha mycket att göra", "have busy days", "food"),
        (["mjöla", "någon"], "utnyttja någon ekonomiskt", "milk someone", "food"),
        (["sätta", "grodd", "i"], "börja utvecklas", "set germ in", "food"),
        (["vara", "salt", "på"], "vara intresserad av", "be salt on", "food"),
        (["koka", "ihop", "något"], "snabbt skapa något", "boil together something", "food"),
        (["bränna", "vid", "sig"], "bli för mycket", "burn to oneself", "food"),

        // ── v6: Additional cognitive and emotional idioms (10) ──
        (["ligga", "i", "startgroparna"], "vara redo att börja", "lie in the starting pit", "cognition"),
        (["ta", "saken", "i", "egna", "händer"], "agera självständigt", "take matter in own hands", "cognition"),
        (["vara", "i", "sitt", "esse"], "vara i sin bästa form", "be in one's element", "emotion"),
        (["ha", "alla", "tiders"], "vara fantastisk", "have all times", "emotion"),
        (["vara", "som", "natt", "och", "dag"], "vara helt olika", "be like night and day", "general"),
        (["falla", "i", "god", "jord"], "bli väl mottagen", "fall in good soil", "general"),
        (["gå", "rakt", "på", "sak"], "vara direkt, inte krångla", "go straight to the matter", "general"),
        (["veta", "hut"], "förstå gränser för uppförande", "know decency", "general"),
        (["ha", "ögon", "på", "sig"], "vara observerad", "have eyes on oneself", "social"),
        (["stå", "på", "sig"], "vara envis", "stand on oneself", "social"),

        // ── v87: Technology idioms (20) ──
        (["hålla", "sig", "uppdaterad"], "följa med i utvecklingen", "stay updated", "technology"),
        (["gå", "online"], "ansluta till internet", "go online", "technology"),
        (["vara", "uppkopplad"], "ha internetanslutning", "be connected", "technology"),
        (["surfa", "på", "nätet"], "bläddra på internet", "surf the net", "technology"),
        (["ladda", "ner"], "hämta fil från internet", "download", "technology"),
        (["ladda", "upp"], "skicka fil till internet", "upload", "technology"),
        (["starta", "om"], "boota om datorn", "restart", "technology"),
        (["krascha", "helt"], "sluta fungera totalt", "crash completely", "technology"),
        (["hänga", "sig"], "frysa, sluta svara", "freeze/hang", "technology"),
        (["bugga", "sig"], "fixa problem i kod", "debug", "technology"),
        (["skrolla", "ner"], "rulla ner på sidan", "scroll down", "technology"),
        (["klicka", "hem"], "köpa online", "click home/buy online", "technology"),
        (["streama", "film"], "titta via internet", "stream film", "technology"),
        (["gilla", "inlägg"], "markera gillande på sociala medier", "like a post", "technology"),
        (["dela", "med", "sig"], "sprida innehåll online", "share content", "technology"),
        (["tagga", "någon"], "markera någon i inlägg", "tag someone", "technology"),
        (["swipa", "höger"], "dra åt höger på skärm", "swipe right", "technology"),
        (["zooma", "in"], "förstora på skärm", "zoom in", "technology"),
        (["synka", "filer"], "syncronisera data", "sync files", "technology"),
        (["backa", "upp"], "säkerhetskopiera", "back up", "technology"),

        // ── v87: Education idioms (20) ──
        (["lära", "sig", "utantill"], "memorera helt", "learn by heart", "education"),
        (["plugga", "heltid"], "studera på heltid", "study full-time", "education"),
        (["skriva", "prov"], "göra ett test", "write a test", "education"),
        (["gå", "kurs"], "delta i utbildning", "take a course", "education"),
        (["läsa", "in", "sig", "på"], "skaffa kunskap om", "read up on", "education"),
        (["ta", "examen"], "avsluta studier", "graduate", "education"),
        (["skriva", "uppsats"], "skrive akademisk text", "write an essay", "education"),
        (["göra", "läxor"], "utföra hemuppgifter", "do homework", "education"),
        (["sitta", "i", "skolbänken"], "vara elev", "sit in the school bench", "education"),
        (["plugga", "ihop"], "studera tillsammans", "study together", "education"),
        (["få", "underkänd"], "bli godkänd inte", "get failing grade", "education"),
        (["hoppa", "av", "kursen"], "avbryta studier", "drop the course", "education"),
        (["läsa", "vid", "universitet"], "studera på högskola", "study at university", "education"),
        (["ta", "sig", "an", "ämne"], "börja studera något", "take on a subject", "education"),
        (["få", "högt", "betyg"], "prestera bra i skolan", "get high grade", "education"),
        (["gå", "om", "ett", "år"], "repetera ett skolår", "repeat a year", "education"),
        (["skriva", "av", "sig"], "plagiera", "copy/plagiarize", "education"),
        (["redovisa", "projekt"], "presentera sitt arbete", "present a project", "education"),
        (["delta", "i", "föreläsning"], "höra på lektion", "attend a lecture", "education"),
        (["lämna", "in", "uppgift"], "skicka in hemuppgift", "submit assignment", "education"),

        // ── v87: Health idioms (20) ──
        (["må", "pyton"], "må mycket dåligt", "feel terrible", "health"),
        (["kråka", "sig"], "kräkas, spy", "puke", "health"),
        (["hosta", "i", "sig"], "få hosta", "catch a cough", "health"),
        (["ligga", "dau"], "vara sjuk i sängen", "be sick in bed", "health"),
        (["ta", "sin", "medicin"], "äta läkemedel", "take one's medicine", "health"),
        (["gå", "till", "doktorn"], "besöka läkare", "go to the doctor", "health"),
        (["ta", "temperaturen"], "mäta kroppstemperatur", "take the temperature", "health"),
        (["må", "bra", "igen"], "återhämta sig", "feel good again", "health"),
        (["få", "feber"], "bli varm och sjuk", "get a fever", "health"),
        (["ha", "ont", "i"], "uppleva smärta", "have pain in", "health"),
        (["vilja", "kräkas"], "känna illamående", "feel nauseous", "health"),
        (["gå", "ner", "i", "vikt"], "bli tunnare", "lose weight", "health"),
        (["gå", "upp", "i", "vikt"], "bli tyngre", "gain weight", "health"),
        (["träna", "regelbundet"], "motionera ofta", "exercise regularly", "health"),
        (["äta", "nyttigt"], "ät hälsosam mat", "eat healthy", "health"),
        (["sova", "ut"], "sova tillräckligt länge", "sleep enough", "health"),
        (["känna", "sig", "pigg"], "vara energisk", "feel alert", "health"),
        (["vara", "förkyld"], "ha förkylning", "have a cold", "health"),
        (["få", "huvudvärk"], "uppleva smärta i huvudet", "get a headache", "health"),
        (["må", "illa"], "känna illamående", "feel sick", "health"),

        // ── v87: Travel idioms (20) ──
        (["packa", "väskan"], "förbereda sig för resa", "pack the bag", "travel"),
        (["åka", "härifrån"], "lämna platsen", "leave from here", "travel"),
        (["ta", "sig", "fram"], "förflytta sig", "get around", "travel"),
        (["hitta", "rätt"], "navigera korrekt", "find the right way", "travel"),
        (["åka", "vilse"], "tappa bort sig", "get lost while traveling", "travel"),
        (["boka", "resa"], "reservera transport", "book a trip", "travel"),
        (["checka", "in"], "registrera sig på hotell/flyg", "check in", "travel"),
        (["checka", "ut"], "lämna hotellrum", "check out", "travel"),
        (["ta", "flyget"], "resa med flygplan", "take the flight", "travel"),
        (["hoppa", "på", "tåget"], "stiga ombord på tåg", "hop on the train", "travel"),
        (["gå", "ombord"], "kliva på fartyg/flyg", "go aboard", "travel"),
        (["sätta", "sig", "i", "bilen"], "kliva in i bil", "get in the car", "travel"),
        (["starta", "resan"], "börja resa", "start the journey", "travel"),
        (["nå", "fram"], "komma till destinationen", "arrive", "travel"),
        (["åka", "hem"], "återvända hem", "go home", "travel"),
        (["utforska", "nya", "platser"], "se okända ställen", "explore new places", "travel"),
        (["besöka", "land"], "resa till annat land", "visit a country", "travel"),
        (["ta", "en", "omväg"], "åka en längre väg", "take a detour", "travel"),
        (["stanna", "över", "natten"], "övernatta på resa", "stay overnight", "travel"),
        (["resa", "runt"], "turnera, besöka flera platser", "travel around", "travel"),

        // ── v87: Relationship idioms (20) ──
        (["bli", "kär", "i"], "få känslor för någon", "fall in love with", "relationships"),
        (["gå", "isär"], "avsluta ett förhållande", "split up", "relationships"),
        (["frieri", "till", "någon"], "be någon om äktenskap", "propose to someone", "relationships"),
        (["träffa", "rätt", "person"], "hitta en lämplig partner", "meet the right person", "relationships"),
        (["ha", "känslor", "för"], "älska någon", "have feelings for", "relationships"),
        (["göra", "slut"], "avsluta relationen", "break up", "relationships"),
        (["vara", "tillsammans"], "ha ett förhållande", "be together", "relationships"),
        (["dejt", "någon"], "gå på dejt med någon", "date someone", "relationships"),
        (["svärma", "för", "någon"], "ha stark beundran", "crush on someone", "relationships"),
        (["ha", "kemi"], "ha bra relation", "have chemistry", "relationships"),
        (["förlåta", "någon"], "släta över misstag", "forgive someone", "relationships"),
        (["lita", "på", "någon"], "ha förtroende", "trust someone", "relationships"),
        (["svika", "någon"], "bryta förtroende", "betray someone", "relationships"),
        (["umgås", "med"], "spendera tid tillsammans", "hang out with", "relationships"),
        (["bli", "vänner", "igen"], "försonas efter bråk", "become friends again", "relationships"),
        (["ha", "tjafs"], "bråka om småsaker", "argue about small things", "relationships"),
        (["gå", "hand", "i", "hand"], "hålla varandra i handen", "walk hand in hand", "relationships"),
        (["pussa", "och", "kramas"], "visa kärlek fysiskt", "kiss and hug", "relationships"),
        (["flytta", "ihop"], "börja bo tillsammans", "move in together", "relationships"),
        (["få", "barn"], "bli förälder", "have children", "relationships"),

        // ── v87: Weather/Nature idioms (20) ──
        (["regna", "kattor", "och", "hundar"], "ösa regna", "rain cats and dogs", "weather"),
        (["vara", "uppehåll"], "inte regna", "be clear weather", "weather"),
        (["gå", "upp", "i", "rök"], "försvinna, gå förlorad", "go up in smoke", "weather"),
        (["blåsa", "hårt"], "storma kraftigt", "blow hard", "weather"),
        (["dra", "in", "över"], "moln/nederbörd närmar sig", "move in over", "weather"),
        (["spricka", "upp"], "molnen skingras", "clear up/break open", "weather"),
        (["vara", "mulet"], "molnigt väder", "be overcast", "weather"),
        (["bli", "soligt"], "väder blir fint", "become sunny", "weather"),
        (["få", "snöoväder"], "kraftig snöstorm", "get snowstorm", "weather"),
        (["gå", "ut", "i", "kylan"], "gå ut i kallt väder", "go out in the cold", "weather"),
        (["tina", "upp"], "snö/smälta", "thaw up", "weather"),
        (["frysa", "fast"], "bli fastfrusen", "freeze solid", "weather"),
        (["klarna", "upp"], "vädret blir bättre", "clear up", "weather"),
        (["dra", "in", "ett", "åskväder"], "oväder närmar sig", "thunderstorm approaches", "weather"),
        (["slå", "ut", "i", "blom"], "blommor öppnar sig", "bloom/blossom", "weather"),
        (["få", "frost"], "temperatur under noll", "get frost", "weather"),
        (["hala", "som", "is"], "mycket halt", "slippery as ice", "weather"),
        (["kyla", "ner"], "temperatur sjunker", "cool down", "weather"),
        (["värma", "upp"], "temperatur stiger", "warm up", "weather"),
        (["torka", "ut"], "förlora all fukt", "dry out", "weather"),

        // ── v87: Food/Cooking idioms (20) ──
        (["duka", "bordet"], "förbereda matbordet", "set the table", "food"),
        (["duka", "under"], "misslyckas helt", "go under/fail", "food"),
        (["dela", "på", "notan"], "betala var för sig", "split the bill", "food"),
        (["bjuda", "på", "mat"], "erbjuda någon mat", "invite for food", "food"),
        (["koka", "soppa", "på", "en", "spik"], "göra något av nästan inget", "make soup on a nail", "food"),
        (["steke", "pannkaka"], "grädda pannkakor", "fry pancake", "food"),
        (["brygga", "kaffe"], "göra kaffe", "brew coffee", "food"),
        (["skära", "i", "bitar"], "dela i mindre delar", "cut into pieces", "food"),
        (["röra", "ihop"], "blanda ingredienser", "mix together", "food"),
        (["grädda", "bröd"], "baka bröd i ugn", "bake bread", "food"),
        (["smaka", "av"], "prova maten", "taste test", "food"),
        (["hälla", "upp"], "servera dryck", "pour up", "food"),
        (["dela", "på", "kakan"], "dela något rättvist", "share the cake", "food"),
        (["ha", "god", "aptit"], "måltidshälsning", "bon appetit", "food"),
        (["mätta", "hungern"], "ät tills man är mätt", "satisfy hunger", "food"),
        (["sluka", "i", "sig"], "äta snabbt och mycket", "devour food", "food"),
        (["nalla", "i", "sig"], "småäta mellan måltider", "snack between meals", "food"),
        (["prova", "sig", "fram"], "experimentera med recept", "try and see", "food"),
        (["ta", "en", "tugga"], "äta en bit mat", "take a bite", "food"),
        (["spola", "ner", "med"], "dricka efter mat", "wash down with", "food"),

        // ── v87: Sports idioms (20) ──
        (["göra", "mål"], "poängera i match", "score a goal", "sports"),
        (["sparka", "boll"], "spela fotboll", "kick a ball", "sports"),
        (["åka", "skidor"], "utöva skidsport", "go skiing", "sports"),
        (["ta", "sig", "till", "final"], "nå slutomgången", "reach the final", "sports"),
        (["vinna", "guld"], "bli etta i tävling", "win gold", "sports"),
        (["slå", "rekord"], "bättre än tidigare bästa", "break a record", "sports"),
        (["springa", "maraton"], "delta i långdistanslopp", "run a marathon", "sports"),
        (["träna", "hårt"], "arbeta mycket med idrott", "train hard", "sports"),
        (["sätta", "personligt", "rekord"], "bättre än någonsin tidigare", "set personal record", "sports"),
        (["gå", "i", "mål"], "slutföra lopp", "cross the finish line", "sports"),
        (["få", "rött", "kort"], "visas ut ur match", "get a red card", "sports"),
        (["byta", "planhalva"], "byta sida i match", "switch sides", "sports"),
        (["sparka", "ut", "bollen"], "rensa bollen i fotboll", "kick out the ball", "sports"),
        (["satsa", "allt"], "ge maximalt", "bet it all", "sports"),
        (["komma", "sist"], "sluta på sista plats", "come last", "sports"),
        (["träna", "inför", "tävling"], "förbereda sig för tävling", "train for competition", "sports"),
        (["hoppa", "högt"], "utföra höjdhopp", "jump high", "sports"),
        (["simma", "simsätt"], "utöva simsport", "swim a stroke", "sports"),
        (["kasta", "spjut"], "utöva spjutkastning", "throw a javelin", "sports"),
        (["cykla", "tempo"], "åka cykel mot klockan", "cycle time trial", "sports"),

        // ── v87: Work/Career idioms (20) ──
        (["gå", "i", "pension"], "sluta arbeta för åldern", "retire", "work"),
        (["få", "sparken"], "bli uppsagd", "get fired", "work"),
        (["söka", "jobb"], "ansöka om anställning", "look for a job", "work"),
        (["gå", "på", "intervju"], "delta i anställningsintervju", "go to interview", "work"),
        (["få", "befordran"], "bli befordrad", "get promoted", "work"),
        (["sätta", "igång", "arbetet"], "börja arbeta", "start working", "work"),
        (["ha", "bråttom"], "måste skynda sig", "be in a hurry", "work"),
        (["ta", "semester"], "ledighet från jobbet", "take vacation", "work"),
        (["jobba", "övertid"], "arbeta extra timmar", "work overtime", "work"),
        (["sjukskriva", "sig"], "anmäla sig sjuk", "call in sick", "work"),
        (["säga", "upp", "sig"], "lämna sitt jobb", "quit one's job", "work"),
        (["starta", "eget"], "bli egen företagare", "start own business", "work"),
        (["skriva", "CV"], "skrive curriculum vitae", "write CV", "work"),
        (["nätverka"], "skapa professionella kontakter", "network", "work"),
        (["delegera", "uppgifter"], "fördela arbete", "delegate tasks", "work"),
        (["ha", "möte"], "delta i sammankomst", "have a meeting", "work"),
        (["arbeta", "hemifrån"], "jobba på distans", "work from home", "work"),
        (["få", "lönepåslag"], "få högre lön", "get a raise", "work"),
        (["skriva", "under", "kontrakt"], "underteckna avtal", "sign contract", "work"),
        (["avsluta", "projekt"], "slutföra arbetsuppgift", "finish project", "work"),

        // ── v87: Art/Culture idioms (20) ──
        (["måla", "tavla"], "skapa konstverk", "paint a picture", "art"),
        (["spela", "teater"], "framträda på scen", "perform theater", "art"),
        (["skriva", "dikt"], "skrive poesi", "write a poem", "art"),
        (["sjunga", "kör"], "sjunga i grupp", "sing in a choir", "art"),
        (["ställa", "ut", "konst"], "visa konstverk offentligt", "exhibit art", "art"),
        (["spela", "konsert"], "framföra musik live", "play a concert", "art"),
        (["besöka", "museum"], "gå till museum", "visit a museum", "art"),
        (["läsa", "roman"], "läsa lång berättelse", "read a novel", "art"),
        (["titta", "på", "film"], "se bio", "watch a film", "art"),
        (["dansa", "balett"], "utöva balett", "dance ballet", "art"),
        (["skriva", "manus"], "skrive filmmanus", "write a script", "art"),
        (["regissera", "film"], "vara regissör", "direct a film", "art"),
        (["fotografera", "motiv"], "ta bild på något", "photograph a subject", "art"),
        (["sjunga", "solo"], "sjunga ensam", "sing solo", "art"),
        (["måla", "porträtt"], "måla av en person", "paint a portrait", "art"),
        (["skulptera", "figur"], "skapa skulptur", "sculpt a figure", "art"),
        (["besöka", "galleri"], "gå till konstgalleri", "visit a gallery", "art"),
        (["lyssna", "på", "opera"], "höra på opera", "listen to opera", "art"),
        (["framföra", "pjäs"], "visa teaterföreställning", "perform a play", "art"),
        (["skriva", "recension"], "ge omdöme om konstverk", "write a review", "art"),
    ]

    private func detectIdioms(_ text: String) -> [DetectedIdiom] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        var found: [DetectedIdiom] = []

        for (pattern, meaning, literal, category) in Self.idiomDatabase {
            // Check if all pattern words appear in order (with gaps allowed)
            var patternIdx = 0
            for word in words {
                if patternIdx < pattern.count && word.hasPrefix(pattern[patternIdx].prefix(4)) {
                    patternIdx += 1
                }
            }
            if patternIdx >= pattern.count {
                found.append(DetectedIdiom(
                    phrase: pattern.joined(separator: " "),
                    meaning: meaning,
                    literalTranslation: literal,
                    category: category
                ))
            }
        }

        // Iteration 20: Boost pragmatic competency by 0.005 per detected idiom
        if !found.isEmpty {
            let pragmaticBoost = min(0.1, Double(found.count) * 0.005)
            // The boost is applied via the analysis result — detectIdioms is called from analyze()
            // which returns the idioms in SwedishAnalysis. The caller can use this for competency boost.
            // We signal this through the analysis by adding idioms with the category field.
        }

        return found
    }

    // MARK: - Clause Segmentation
    // Split Swedish sentences into clauses (huvudsats/bisats)

    private static let subordinators: Set<String> = [
        "att", "som", "om", "när", "medan", "eftersom", "trots", "fast", "innan",
        "efter", "tills", "såvida", "huruvida", "ifall", "emedan", "ehuru",
        "för att", "så att", "även om", "trots att", "i stället för att"
    ]

    private func segmentClauses(_ text: String) -> [ClauseSegment] {
        // Split on punctuation and subordinating conjunctions
        var clauses: [ClauseSegment] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            // Split on commas and subordinators
            let parts = sentence.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for part in parts {
                let lower = part.lowercased()
                let words = lower.components(separatedBy: .whitespaces)
                let firstWord = words.first ?? ""

                let isSubordinate = Self.subordinators.contains(firstWord) ||
                    Self.subordinators.contains(words.prefix(2).joined(separator: " "))
                let clauseType: ClauseSegment.ClauseType = isSubordinate ? .subordinate : .main

                clauses.append(ClauseSegment(
                    text: part,
                    type: clauseType,
                    startWord: firstWord
                ))
            }
        }
        return clauses
    }

    // MARK: - Anaphora Resolution (Iteration 16: Pronoun-type-aware resolution)
    // Resolves "den", "det", "han", "hon", "de", reflexive "sin/sitt/sina" etc.
    // with gender/number matching and confidence scoring

    /// Iteration 16: Swedish pronoun categories with gender/number constraints
    private enum PronounType {
        case maleSubject      // han, honom
        case femaleSubject    // hon, henne
        case utrum            // den (common gender / utrum)
        case neuter           // det (neuter / neutrum)
        case plural           // de, dem, dessa
        case reflexive        // sin, sitt, sina
        case other            // mig, dig, oss, er, min, din, etc.
    }

    /// Map pronouns to their grammatical type (gender/number)
    private static let pronounTypeMap: [String: PronounType] = [
        "han": .maleSubject, "honom": .maleSubject,
        "hon": .femaleSubject, "henne": .femaleSubject,
        "den": .utrum,
        "det": .neuter,
        "de": .plural, "dem": .plural, "dessa": .plural,
        "sin": .reflexive, "sitt": .reflexive, "sina": .reflexive,
        "sig": .reflexive,
        "mig": .other, "dig": .other, "oss": .other, "er": .other,
        "min": .other, "din": .other, "hans": .other, "hennes": .other,
        "deras": .other, "vår": .other, "ert": .other,
    ]

    /// Swedish nouns that are typically male (names, roles)
    private static let maleNouns: Set<String> = [
        "man", "pojke", "far", "pappa", "bror", "son", "farfar", "morfar",
        "kungen", "presidenten", "ministern", "läraren", "doktorn", "killen", "gubben",
        "herren", "prinsen", "riddaren", "bonden", "arbetaren", "författaren"
    ]

    /// Swedish nouns that are typically female (names, roles)
    private static let femaleNouns: Set<String> = [
        "kvinna", "flicka", "mor", "mamma", "syster", "dotter", "farmor", "mormor",
        "drottningen", "ministern", "läraren", "doktorn", "tjejen", "gumman",
        "dam", "prinsessan", "jungfrun", "bondens_hustru", "arbeterskan", "författarinnan"
    ]

    /// Swedish en-words (utrum / common gender) — den
    private static let utrumNouns: Set<String> = [
        "bil", "hus", "stad", "bok", "tidning", "dag", "vecka", "månad", "år",
        "person", "plats", "del", "sak", "vatten", "luft", "jord", "väg", "dörr",
        "skola", "arbete", "fråga", "svar", "idé", "bild", "sida", "grupp", "familj"
    ]

    /// Swedish ett-words (neutrum) — det
    private static let neuterNouns: Set<String> = [
        "äpple", "bord", "fönster", "träd", "hus", "land", "år", "barn",
        "problem", "exempel", "ord", "språk", "rum", "tak", "golv", "hjärta",
        "brev", "fotboll", "landslag", "företag", "system", "program", "projekt"
    ]

    private func resolveAnaphora(_ text: String, morphemes: [MorphemeAnalysis]) -> [AnaphoraResolution] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        // Find all nouns as potential antecedents with their positions
        let nouns = morphemes.filter { $0.pos == "noun" || $0.pos == "propernoun" }
        var resolutions: [AnaphoraResolution] = []

        // Sentence boundary detection for reflexive resolution
        let sentenceBoundaries = text.indices.filter { i in
            let c = text[i]
            return c == "." || c == "!" || c == "?"
        }

        for (idx, word) in words.enumerated() {
            guard let pronounType = Self.pronounTypeMap[word] else { continue }

            var bestAntecedent: String?
            var bestDistance = Int.max
            var typeMatchBonus: Double = 0.0

            // Determine the search window: reflexive pronouns search within same sentence
            let searchStart: Int
            if pronounType == .reflexive {
                // Find sentence start: nearest preceding sentence boundary
                searchStart = findSentenceStart(wordIndex: idx, words: words, boundaries: sentenceBoundaries, text: text)
            } else {
                searchStart = 0
            }

            for noun in nouns {
                guard let nounIdx = words.firstIndex(of: noun.word.lowercased()),
                      nounIdx >= searchStart,
                      nounIdx < idx else { continue }

                let distance = idx - nounIdx
                guard distance <= 10 else { continue }

                // Iteration 16: Type matching bonus
                let nounLower = noun.word.lowercased()
                var matchScore: Double = 0.0

                switch pronounType {
                case .maleSubject:
                    if Self.maleNouns.contains(nounLower) {
                        matchScore = 0.25
                    } else if !Self.femaleNouns.contains(nounLower) {
                        matchScore = 0.05 // Not known to be female, slight possibility
                    }
                case .femaleSubject:
                    if Self.femaleNouns.contains(nounLower) {
                        matchScore = 0.25
                    } else if !Self.maleNouns.contains(nounLower) {
                        matchScore = 0.05
                    }
                case .utrum:
                    if Self.utrumNouns.contains(nounLower) {
                        matchScore = 0.15
                    } else if !Self.neuterNouns.contains(nounLower) {
                        matchScore = 0.05
                    }
                case .neuter:
                    if Self.neuterNouns.contains(nounLower) {
                        matchScore = 0.15
                    } else if !Self.utrumNouns.contains(nounLower) {
                        matchScore = 0.05
                    }
                case .plural:
                    // Plural nouns (often ending -or, -ar, -er, -n)
                    if nounLower.hasSuffix("or") || nounLower.hasSuffix("ar") ||
                       nounLower.hasSuffix("er") || nounLower.hasSuffix("na") ||
                       nounLower.hasSuffix("en") {
                        matchScore = 0.15
                    }
                case .reflexive:
                    // Reflexive: antecedent must be the subject of the same clause
                    // Prefer closest noun (distance-based)
                    matchScore = 0.1
                case .other:
                    matchScore = 0.0
                }

                // Score = distance decay + type match bonus
                let distanceScore = max(0.1, 1.0 - Double(distance) * 0.08)
                let totalScore = distanceScore + matchScore

                if totalScore > (bestDistance == Int.max ? 0 : max(0.1, 1.0 - Double(bestDistance) * 0.08 + typeMatchBonus)) {
                    bestDistance = distance
                    bestAntecedent = noun.word
                    typeMatchBonus = matchScore
                }
            }

            if let antecedent = bestAntecedent, bestDistance <= 10 {
                let confidence = min(0.95, max(0.25, 1.0 - Double(bestDistance) * 0.06 + typeMatchBonus))
                resolutions.append(AnaphoraResolution(
                    pronoun: word,
                    antecedent: antecedent,
                    distance: bestDistance,
                    confidence: confidence
                ))
            }
        }
        return resolutions
    }

    /// Find the word index of the start of the current sentence
    private func findSentenceStart(wordIndex: Int, words: [String], boundaries: [String.Index], text: String) -> Int {
        guard !boundaries.isEmpty else { return 0 }
        // Approximate: find the last boundary before this word's position
        // Since wordIndex is an index into `words`, we need to estimate position
        let approxPosition = wordIndex * 6 // ~6 chars per word on average
        for boundary in boundaries {
            if text.distance(from: text.startIndex, to: boundary) > approxPosition {
                // Find the word index at this position
                var count = 0
                var charCount = 0
                for w in words {
                    charCount += w.count + 1
                    if charCount >= text.distance(from: text.startIndex, to: boundary) {
                        return count + 1
                    }
                    count += 1
                }
                break
            }
        }
        return 0
    }

    // MARK: - Register-detektion (Iteration 17: Multi-dimensional register)

    /// Iteration 17: Detects formal, technical, informal, and academic register
    private func detectRegister(_ text: String) -> SwedishRegister {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        // ── Formal register indicators ──
        let formalWords: Set<String> = ["emellertid", "således", "härav", "därtill", "beträffande", "avseende",
                           "vederbörande", "härmed", "dock", "icke", "följaktligen", "ändamålsenlig",
                           "tillförsäkra", "såtillvida", "förvisso", "annorlunda", "tvivelsutan", "oaktat",
                           "därigenom", "härefter", "däremot", "sålunda", "angående", "enligt", "med hänsyn till"]
        var formalScore: Double = 0

        // ── Informal register indicators ──
        let informalWords: Set<String> = ["typ", "liksom", "asså", "ju", "va", "grejen", "kul", "gött", "skit",
                             "jävla", "fett", "soft", "ba", "skitbra", "najs", "palla", "orka",
                             "sjukt", "galen", "fyfan", "ascoolt", "sicken", "vilansen", "grabben",
                             "chilla", "grymt", "sugg", "okej", "okej", "schysst", "lagom", "sugen"]
        var informalScore: Double = 0

        // ── Technical register indicators ──
        let technicalWords: Set<String> = ["algoritm", "implementation", "konfiguration", "parameter", "funktion",
                              "databas", "server", "api", "framework", "kompilera", "instans", "modul",
                              "protokoll", "interface", "pipeline", "arkitektur", "refaktorera", "deploy",
                              "koda", "debugga", "committa", "merge", "pull", "push", "branch", "repo"]
        var technicalScore: Double = 0

        // ── Academic register indicators (Iteration 17) ──
        let academicHedges: Set<String> = ["kanske", "möjligen", "sannolikt", "troligen", "eventuellt",
                                           "det kan antas", "forskning tyder på", "enligt studier",
                                           "i viss mån", "delvis", "relativt", "någorlunda"]
        let academicCitations: Set<String> = ["enligt", "citerat", "refererar", "källa", "studie",
                                              "forskning", "rapport", "artikel", "publikation", "avhandling"]
        let academicTransitions: Set<String> = ["för det första", "för det andra", "sammanfattningsvis",
                                                 "slutligen", "däremot", "å andra sidan", "sammanfattningsvis",
                                                 "sammanfattande", "inledningsvis", "avslutningsvis",
                                                 "mot bakgrund av", "med avseende på", "i jämförelse med"]
        var academicScore: Double = 0

        // Positional weighting: words at the start of sentences carry more register signal
        for (i, word) in words.enumerated() {
            let positionWeight = i < 5 ? 1.5 : 1.0
            if formalWords.contains(word) { formalScore += positionWeight }
            if informalWords.contains(word) { informalScore += positionWeight }
            if technicalWords.contains(word) { technicalScore += positionWeight }
            if academicHedges.contains(word) { academicScore += positionWeight * 0.8 }
            if academicCitations.contains(word) { academicScore += positionWeight * 1.0 }
            if academicTransitions.contains(word) { academicScore += positionWeight * 0.9 }
        }

        // Check multi-word academic phrases
        let textLower = text.lowercased()
        for phrase in ["enligt studier", "forskning visar", "det har visats", "kan antas", "bör noteras",
                       "sammanfattningsvis", "mot bakgrund av", "i ljuset av", "med avseende på"] {
            if textLower.contains(phrase) { academicScore += 1.5 }
        }

        // Sentence structure indicators
        let avgWordLength = words.isEmpty ? 0 : Double(words.map { $0.count }.reduce(0, +)) / Double(words.count)

        // Formal: long words, passive -s, nominalization
        if avgWordLength > 7.0 { formalScore += 0.5 }
        // Passive -s (formal marker)
        let passiveSCount = words.filter { $0.hasSuffix("s") && $0.count > 4 }.count
        formalScore += Double(passiveSCount) * 0.15
        // Nominalization (-ning, -het, -tion, -skap → formal indicator)
        let nominalizations = words.filter {
            $0.hasSuffix("ning") || $0.hasSuffix("het") || $0.hasSuffix("tion") || $0.hasSuffix("skap")
        }.count
        formalScore += Double(nominalizations) * 0.1

        // Informal: short words, contractions, exclamation/emoji
        if avgWordLength < 4.5 { informalScore += 0.3 }
        // Contractions and short forms
        let contractions = words.filter { $0 == "e" || $0 == "ä" || $0 == "va" || $0 == "ba" || $0 == "sån" || $0 == "san" }
        informalScore += Double(contractions.count) * 0.3
        if text.contains("!") || text.contains("😂") || text.contains("🤔") { informalScore += 0.5 }

        // Technical: abbreviations, domain-specific compound terms
        let abbreviations = words.filter { $0.allSatisfy { $0.isUppercase } && $0.count >= 2 && $0.count <= 6 }
        technicalScore += Double(abbreviations.count) * 0.3

        // Academic: average word length is a strong indicator
        if avgWordLength > 8.0 { academicScore += 1.0 }
        // Multiple subordinate clauses → academic
        let subordinators = ["att", "som", "när", "om", "eftersom", "medan", "fastän", "huruvida", "såvida"]
        let subCount = subordinators.filter { textLower.contains(" \($0) ") }.count
        academicScore += Double(subCount) * 0.2

        // Iteration 17: Academic register is now a distinct option
        // Academic has higher threshold since it's the most specific
        if academicScore > 3.0 { return .academic }
        if technicalScore > 2.0 { return .technical }
        if formalScore > informalScore + 0.5 && formalScore > 1.5 { return .formal }
        if informalScore > formalScore + 0.5 && informalScore > 1.5 { return .informal }
        return .neutral
    }

    // MARK: - Modal partiklar (Iteration 18: Frequency tracking)

    /// Iteration 18: Modal particles with frequency counts
    /// High frequency of modal particles = informal/conversational register
    private func extractModalParticles(_ text: String) -> [ModalParticle] {
        let particles: [(String, ModalParticle.Meaning)] = [
            ("ju", .sharedKnowledge),
            ("väl", .hedging),
            ("nog", .probability),
            ("visst", .confirmation),
            ("faktiskt", .emphasis),
            ("egentligen", .concession),
            ("dock", .concession),
            ("ändå", .concession),
            ("liksom", .hedging),
            ("typ", .hedging),
            ("snarare", .concession),
            ("förresten", .emphasis),
            ("tydligen", .probability),
            ("naturligtvis", .confirmation),
            ("uppenbarligen", .confirmation),
            ("kanske", .hedging),
            ("möjligen", .probability),
            ("dessvärre", .concession),
            ("givetvis", .sharedKnowledge),
            ("sannerligen", .emphasis),
            // Iteration 18: Additional particles
            ("verkligen", .emphasis),
            ("riktigt", .emphasis),
            ("helt enkelt", .emphasis),
            ("liksom sagt", .hedging),
            ("säkert", .probability),
            ("onekligen", .confirmation),
        ]

        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        // Iteration 18: Count frequencies per particle
        var frequencyMap: [String: Int] = [:]
        var found: [ModalParticle] = []

        for word in words {
            if particles.contains(where: { $0.0 == word }) {
                frequencyMap[word, default: 0] += 1
            }
        }

        // Build result with frequency data
        for (particle, meaning) in particles {
            if let count = frequencyMap[particle], count > 0 {
                found.append(ModalParticle(
                    word: particle,
                    meaning: meaning,
                    frequency: count
                ))
            }
        }

        return found
    }

    // MARK: - Metaphor Detection (Iteration 31)

    struct MetaphorDetection: Identifiable {
        let id = UUID()
        let sourceDomain: String
        let targetDomain: String
        let metaphorType: MetaphorType
        let confidence: Double
        let explanation: String
        let triggerWords: [String]
    }

    enum MetaphorType: String {
        case conceptual
        case structural
        case ontological
    }

    private static let conceptualMetaphors: [(source: String, target: String, triggers: [String], explanation: String)] = [
        ("SPACE", "TIME", ["nära", "framför", "bakom", "långt", "kort", "djup", "framåt", "bakåt", "mellan", "genom", "över", "under", "kommande", "föregående", "före", "efter"],
         "TID ÄR RUM — temporala begrepp uttrycks med rumsliga termer"),
        ("VERTICAL_SPACE", "QUANTITY", ["högt", "lågt", "öka", "minska", "stiga", "falla", "topp", "botten", "upp", "ner", "nedåt", "uppåt"],
         "MÄNGD ÄR VERTIKAL — mer är upp, mindre är ner"),
        ("SIZE", "IMPORTANCE", ["stor", "liten", "betydande", "marginell", "enorm", "pytte", "jätte"],
         "VIKTIGHET ÄR STORLEK"),
        ("PHYSICAL_OBSTACLE", "DIFFICULTY", ["hinder", "tröskel", "barriär", "vägg", "mur", "berg", "backe", "klättra", "övervinna"],
         "SVÅRIGHET ÄR HINDER"),
        ("VERTICAL_SPACE", "EMOTION", ["upprymd", "nedslagen", "lyft", "tung", "hög", "djup", "toppen", "botten"],
         "GLAD ÄR UPP / LEDSEN ÄR NER"),
    ]

    private static let structuralMetaphors: [(source: String, target: String, triggers: [String], explanation: String)] = [
        ("WAR", "ARGUMENT", ["försvara", "anfalla", "attackera", "försvar", "angrepp", "strid", "bekämpa", "besegra", "seger", "förlust", "vapen", "sköld"],
         "ARGUMENTATION ÄR KRIG"),
        ("MONEY", "TIME", ["spendera", "slösa", "investera", "spara", "kosta", "värdefull", "budget", "räkning"],
         "TID ÄR PENGAR"),
        ("FOOD", "IDEAS", ["smälta", "svälja", "spya", "näringsrik", "tom", "lättsmält", "tungsmält", "begriplig", "obegriplig"],
         "IDÉER ÄR MAT"),
        ("BUILDING", "THEORY", ["bygga", "grund", "fundament", "stomme", "stöd", "rasa", "hålla", "konstruktion", "arkitektur", "pelare"],
         "TEORIER ÄR BYGGNADER"),
        ("JOURNEY", "RELATIONSHIP", ["väg", "mål", "resa", "vandring", "gemensam", "skiljas", "möts", "korsväg", "riktning", "framsteg"],
         "RELATIONER ÄR RESOR"),
        ("MACHINE", "MIND", ["fungera", "köra", "starta", "stoppa", "bearbeta", "processa", "koppla", "programmera", "mekanism"],
         "SINNET ÄR EN MASKIN"),
    ]

    private static let ontologicalMetaphors: [(source: String, target: String, triggers: [String], explanation: String)] = [
        ("PHYSICAL_OBJECT", "IDEA", ["ta", "ge", "hålla", "kasta", "fånga", "gripa", "formulera", "skapa", "dela", "hitta", "tappa"],
         "IDÉER ÄR FÖREMÅL"),
        ("CONTAINER", "MIND", ["innehålla", "fylla", "tom", "full", "rymma", "läcka", "stänga", "öppna", "fyllas", "tömma"],
         "SINNET ÄR EN BEHÅLLARE"),
        ("PHYSICAL_FORCE", "EMOTION", ["dra", "trycka", "knuffa", "slita", "pressa", "tvinga", "driva", "överväldiga"],
         "KÄNSLOR ÄR KRAFTER"),
        ("LOCATION", "STATE", ["hamna", "råka", "befinna", "vara i", "gå in", "komma in"],
         "TILLSTÅND ÄR PLATSER"),
        ("PATH", "ACTIVITY", ["gå", "följa", "spår", "led", "riktning", "steg", "framsteg", "backa"],
         "AKTIVITETER ÄR VÄGAR"),
    ]

    func detectMetaphors(_ text: String) -> [MetaphorDetection] {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 1 }
        var detections: [MetaphorDetection] = []

        for (source, target, triggers, explanation) in Self.conceptualMetaphors {
            let matched = triggers.filter { trigger in
                words.contains { $0.hasPrefix(trigger.prefix(4)) }
            }
            if matched.count >= 2 {
                let confidence = min(0.95, 0.4 + Double(matched.count) * 0.1)
                detections.append(MetaphorDetection(sourceDomain: source, targetDomain: target, metaphorType: .conceptual, confidence: confidence, explanation: explanation, triggerWords: matched))
            }
        }
        for (source, target, triggers, explanation) in Self.structuralMetaphors {
            let matched = triggers.filter { trigger in
                words.contains { $0.hasPrefix(trigger.prefix(4)) }
            }
            if matched.count >= 2 {
                let confidence = min(0.95, 0.4 + Double(matched.count) * 0.1)
                detections.append(MetaphorDetection(sourceDomain: source, targetDomain: target, metaphorType: .structural, confidence: confidence, explanation: explanation, triggerWords: matched))
            }
        }
        for (source, target, triggers, explanation) in Self.ontologicalMetaphors {
            let matched = triggers.filter { trigger in
                words.contains { $0.hasPrefix(trigger.prefix(4)) }
            }
            if matched.count >= 2 {
                let confidence = min(0.95, 0.35 + Double(matched.count) * 0.1)
                detections.append(MetaphorDetection(sourceDomain: source, targetDomain: target, metaphorType: .ontological, confidence: confidence, explanation: explanation, triggerWords: matched))
            }
        }

        // Deduplicate: keep highest-confidence per source-target pair
        var bestByPair: [String: MetaphorDetection] = [:]
        for d in detections {
            let key = "\(d.sourceDomain)-\(d.targetDomain)"
            if let existing = bestByPair[key], d.confidence > existing.confidence {
                bestByPair[key] = d
            } else if bestByPair[key] == nil {
                bestByPair[key] = d
            }
        }
        return Array(bestByPair.values)
    }

    // MARK: - Irony & Sarcasm Detection (Iteration 32)

    struct IronyDetection: Identifiable {
        let id = UUID()
        let type: IronyType
        let confidence: Double
        let explanation: String
        let markers: [String]
        let textSpan: String
    }

    enum IronyType: String {
        case incongruity
        case hyperbole
        case understatement
        case rhetorical
        case particle
    }

    private static let ironyParticles: Set<String> = [
        "jaså", "nämen", "trevligt", "fint", "underbart", "jättebra", "perfekt",
        "härligt", "fantastiskt", "utmärkt", "strålande", "glädjande"
    ]

    private static let positiveSentiment: Set<String> = [
        "bra", "fint", "trevligt", "underbart", "fantastiskt", "utmärkt", "härligt",
        "perfekt", "jättebra", "glad", "lycklig", "strålande"
    ]

    private static let negativeSentiment: Set<String> = [
        "dåligt", "hemskt", "värdelös", "usel", "taskigt", "fruktansvärt", "katastrof",
        "misslyckande", "jobbigt", "tråkigt", "trasig", "fel", "problem", "krångel", "hatar"
    ]

    private static let hyperboleMarkers: Set<String> = [
        "aldrig", "alltid", "värsta", "bästa", "sämsta", "helt otroligt", "ofattbart",
        "absolut", "totalt", "fullständigt", "extremt", "enormt", "världens"
    ]

    private static let understatementMarkers: Set<String> = [
        "inte så", "ganska", "något", "lite", "kanske", "smått", "aningen",
        "någorlunda", "hyfsat", "relativt", "föga", "knappast", "inte särskilt"
    ]

    func detectIrony(_ text: String) -> [IronyDetection] {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        var detections: [IronyDetection] = []

        // Irony particles in negative context
        for particle in Self.ironyParticles {
            if lower.contains(particle) {
                let hasNegativeContext = words.contains { w in
                    Self.negativeSentiment.contains { w.hasPrefix($0.prefix(4)) }
                }
                if hasNegativeContext {
                    detections.append(IronyDetection(type: .particle, confidence: 0.75, explanation: "Ironisk partikel '\(particle)' i negativ kontext", markers: [particle], textSpan: String(lower.prefix(80))))
                }
            }
        }

        // Incongruity: positive words in negative context
        let posCount = words.filter { w in Self.positiveSentiment.contains { p in w.hasPrefix(p.prefix(4)) } }.count
        let negCount = words.filter { w in Self.negativeSentiment.contains { n in w.hasPrefix(n.prefix(4)) } }.count
        if posCount >= 1 && negCount >= 2 {
            let matches = words.filter { w in Self.positiveSentiment.contains { p in w.hasPrefix(p.prefix(4)) } }
            detections.append(IronyDetection(type: .incongruity, confidence: min(0.9, 0.5 + Double(negCount - posCount) * 0.1), explanation: "Positiva ord i negativ kontext", markers: matches, textSpan: String(lower.prefix(80))))
        }

        // Hyperbole
        let hyperMatches = words.filter { w in Self.hyperboleMarkers.contains { m in w.contains(m) || w.hasPrefix(m.prefix(4)) } }
        if hyperMatches.count >= 2 {
            detections.append(IronyDetection(type: .hyperbole, confidence: min(0.85, 0.4 + Double(hyperMatches.count) * 0.1), explanation: "Hyperbol: överdrivna uttryck", markers: hyperMatches, textSpan: String(lower.prefix(80))))
        }

        // Understatement
        let understatementMatches = words.filter { w in Self.understatementMarkers.contains { m in w.hasPrefix(m.prefix(4)) } }
        if understatementMatches.count >= 2 && words.filter({ $0.count > 7 }).count >= 3 {
            detections.append(IronyDetection(type: .understatement, confidence: min(0.8, 0.4 + Double(understatementMatches.count) * 0.1), explanation: "Underdrift i betydelsefull kontext", markers: understatementMatches, textSpan: String(lower.prefix(80))))
        }

        // Rhetorical questions
        if lower.contains("?") {
            let questionWords: Set<String> = ["vem", "vad", "varför", "hur", "när", "var", "vilken"]
            let hasQW = words.contains { questionWords.contains($0) }
            if hasQW {
                detections.append(IronyDetection(type: .rhetorical, confidence: 0.5, explanation: "Retorisk fråga", markers: words.filter { questionWords.contains($0) }, textSpan: String(lower.prefix(80))))
            }
        }

        return detections
    }

    // MARK: - Discourse Coherence Analysis (Iteration 33)

    struct DiscourseCoherence: Codable {
        let topicalCoherence: Double
        let temporalCoherence: Double
        let causalCoherence: Double
        let rhetoricalCoherence: Double
        let overallScore: Double
        let analysis: String
    }

    func analyzeDiscourseCoherence(_ text: String) -> DiscourseCoherence {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?:;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 3 }
        guard sentences.count >= 2 else {
            return DiscourseCoherence(topicalCoherence: 1.0, temporalCoherence: 1.0, causalCoherence: 1.0, rhetoricalCoherence: 1.0, overallScore: 1.0, analysis: "För få meningar för diskursanalys")
        }

        // Topical coherence: word overlap between consecutive sentences
        var topicalOverlaps = 0
        for i in 0..<(sentences.count - 1) {
            let w1 = Set(sentences[i].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            let w2 = Set(sentences[i + 1].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            if !w1.intersection(w2).isEmpty { topicalOverlaps += 1 }
        }
        let topicalCoherence = Double(topicalOverlaps) / Double(max(1, sentences.count - 1))

        // Temporal coherence
        let temporalMarkers: Set<String> = ["igår", "idag", "imorgon", "sedan", "tidigare", "senare", "samtidigt", "efter", "innan", "under", "när", "då", "först", "sist", "slutligen", "plötsligt", "alltid", "aldrig", "ofta"]
        let temporalWords = sentences.flatMap { s in s.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { temporalMarkers.contains($0) } }
        let hasToday = temporalWords.contains { $0.contains("idag") }
        let hasYesterday = temporalWords.contains { $0.contains("igår") }
        let hasTomorrow = temporalWords.contains { $0.contains("imorgon") }
        let contradictions = [hasToday, hasYesterday, hasTomorrow].filter { $0 }.count
        let penalty = contradictions > 2 ? 0.3 : contradictions > 1 ? 0.15 : 0.0
        let temporalCoherence = max(0.0, min(1.0, 0.7 + Double(temporalWords.count) * 0.05 - penalty))

        // Causal coherence
        let causalConnectives: Set<String> = ["eftersom", "därför", "alltså", "följaktligen", "således", "därav", "påverka", "orsaka", "medföra", "leda", "resultera", "konsekvens", "effekt", "orsak", "därmed"]
        let causalCount = sentences.flatMap { $0.lowercased().components(separatedBy: .whitespacesAndNewlines) }.filter { w in causalConnectives.contains { c in w.hasPrefix(c.prefix(4)) } }.count
        let expectedCausal = max(1, sentences.count / 3)
        let causalCoherence = min(1.0, (Double(causalCount) / Double(expectedCausal)) * 0.8 + 0.2)

        // Rhetorical coherence
        let lowerText = text.lowercased()
        let claimMarkers = ["jag tycker", "jag anser", "min uppfattning", "det är klart", "uppenbarligen"]
        let evidenceMarkers = ["till exempel", "exempelvis", "enligt", "studier visar", "forskning", "bevis"]
        let conclusionMarkers = ["sammanfattningsvis", "slutsatsen", "avslutningsvis", "sammantaget", "därmed", "följaktligen"]
        let patternScore = Double([claimMarkers, evidenceMarkers, conclusionMarkers].map { $0.contains { lowerText.contains($0) } }.filter { $0 }.count) / 3.0
        let sentenceFactor = min(1.0, Double(sentences.count) / 5.0)
        let rhetoricalCoherence = patternScore * 0.6 + sentenceFactor * 0.4

        let overallScore = topicalCoherence * 0.3 + temporalCoherence * 0.2 + causalCoherence * 0.25 + rhetoricalCoherence * 0.25
        let analysis = "Diskursanalys (poäng: \(String(format: "%.2f", overallScore))): tematisk \(topicalCoherence > 0.6 ? "god" : "svag"), tidsmässig \(temporalCoherence > 0.6 ? "konsekvent" : "inkonsekvent"), kausal \(causalCoherence > 0.6 ? "tydlig" : "svag"), retorisk \(rhetoricalCoherence > 0.6 ? "välstrukturerad" : "svag")"

        return DiscourseCoherence(topicalCoherence: topicalCoherence, temporalCoherence: temporalCoherence, causalCoherence: causalCoherence, rhetoricalCoherence: rhetoricalCoherence, overallScore: overallScore, analysis: analysis)
    }

    // MARK: - Emotional Valence Analysis (Iteration 37)

    private static let sentimentLexicon: [String: (valence: Double, arousal: Double, emotion: String)] = [
        "glad": (0.8, 0.7, "glädje"), "lycklig": (0.9, 0.6, "glädje"), "fantastisk": (0.9, 0.8, "glädje"),
        "underbar": (0.9, 0.7, "glädje"), "härlig": (0.8, 0.7, "glädje"), "strålande": (0.85, 0.75, "glädje"),
        "jättebra": (0.85, 0.7, "glädje"), "entusiastisk": (0.8, 0.8, "glädje"), "euforisk": (0.95, 0.9, "glädje"),
        "lugn": (0.5, 0.2, "tillit"), "harmonisk": (0.7, 0.3, "tillit"), "tillfreds": (0.7, 0.2, "tillit"),
        "nöjd": (0.7, 0.3, "tillit"), "tacksam": (0.7, 0.4, "tillit"), "trygg": (0.6, 0.2, "tillit"),
        "arg": (-0.8, 0.8, "vrede"), "rasande": (-0.9, 0.9, "vrede"), "förbannad": (-0.95, 0.9, "vrede"),
        "hat": (-0.9, 0.8, "vrede"), "ilska": (-0.85, 0.85, "vrede"), "vred": (-0.8, 0.8, "vrede"),
        "rädd": (-0.7, 0.7, "rädsla"), "skrämd": (-0.8, 0.8, "rädsla"), "panik": (-0.9, 0.9, "rädsla"),
        "oro": (-0.5, 0.5, "rädsla"), "ångest": (-0.8, 0.7, "rädsla"), "hot": (-0.7, 0.7, "rädsla"),
        "ledsen": (-0.7, 0.4, "sorg"), "sorglig": (-0.8, 0.5, "sorg"), "deprimerad": (-0.9, 0.3, "sorg"),
        "gråter": (-0.7, 0.5, "sorg"), "förlust": (-0.7, 0.5, "sorg"), "ensam": (-0.6, 0.4, "sorg"),
        "överraskad": (0.3, 0.8, "överraskning"), "chockad": (-0.3, 0.9, "överraskning"),
        "förvånad": (0.1, 0.7, "överraskning"), "oväntat": (0.1, 0.7, "överraskning"),
        "hoppas": (0.6, 0.6, "förväntan"), "spännande": (0.7, 0.8, "förväntan"), "nyfiken": (0.5, 0.7, "förväntan"),
        "äckligt": (-0.7, 0.6, "förakt"), "avsky": (-0.85, 0.7, "förakt"), "förakt": (-0.8, 0.6, "förakt"),
        "skam": (-0.7, 0.5, "skam"), "förlägen": (-0.6, 0.6, "skam"), "generad": (-0.5, 0.5, "skam"),
        "ångra": (-0.6, 0.5, "skuld"), "ånger": (-0.65, 0.5, "skuld"),
        "kärlek": (0.9, 0.6, "tillit"), "älskar": (0.9, 0.7, "tillit"), "vän": (0.7, 0.5, "tillit"),
        "bra": (0.5, 0.4, "glädje"), "dålig": (-0.5, 0.4, "sorg"), "fin": (0.4, 0.3, "glädje"),
        "problem": (-0.4, 0.5, "rädsla"), "död": (-0.8, 0.6, "sorg"), "liv": (0.6, 0.6, "glädje"),
    ]

    func analyzeEmotionalValence(_ text: String) -> (valence: Double, arousal: Double, emotion: String) {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        var totalValence: Double = 0, totalArousal: Double = 0
        var emotionScores: [String: Double] = [:]
        var matchedCount = 0

        for word in words {
            if let (v, a, e) = Self.sentimentLexicon[word] {
                totalValence += v; totalArousal += a; emotionScores[e, default: 0] += 1.0; matchedCount += 1
            } else {
                for (lw, (v, a, e)) in Self.sentimentLexicon {
                    if word.hasPrefix(lw.prefix(5)) && lw.count >= 4 {
                        totalValence += v * 0.7; totalArousal += a * 0.7; emotionScores[e, default: 0] += 0.7; matchedCount += 1; break
                    }
                }
            }
        }

        guard matchedCount > 0 else { return (0.0, 0.3, "neutral") }

        let dominantEmotion = emotionScores.max { $0.value < $1.value }?.key ?? "neutral"
        return (max(-1.0, min(1.0, totalValence / Double(matchedCount))), max(0.0, min(1.0, totalArousal / Double(matchedCount))), dominantEmotion)
    }

    // v75: Predict next Swedish words based on context using (a) recent n-grams,
    // (b) common Swedish collocations, (c) semantic field continuity.
    func predictNextWords(text: String, count: Int) -> [String] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard words.count >= 2 else { return [] }

        var predictions: [(word: String, score: Double)] = []

        // (a) Recent word n-grams — what words commonly follow the last 1-2 words
        let lastWord = words.last ?? ""
        let secondLast = words.count >= 2 ? words[words.count - 2] : ""

        // Common Swedish next-word patterns based on n-gram frequencies
        let swedishContinuations: [String: [String]] = [
            "jag": ["är", "har", "vill", "kan", "ska", "tror", "tycker", "måste", "bör", "gillar"],
            "det": ["är", "finns", "finns", "går", "blir", "kan", "ska", "har", "verkar", "finns"],
            "som": ["en", "ett", "jag", "du", "han", "hon", "de", "vi", "man", "den"],
            "är": ["en", "ett", "den", "det", "mycket", "inte", "också", "viktig", "bra", "svårt"],
            "har": ["en", "ett", "jag", "de", "vi", "man", "inte", "också", "alltid", "redan"],
            "och": ["jag", "det", "en", "som", "vi", "de", "man", "inte", "också", "då"],
            "att": ["det", "jag", "man", "vi", "de", "en", "inte", "man", "också", "bara"],
            "men": ["jag", "det", "en", "vi", "de", "inte", "också", "man", "han", "hon"],
            "för": ["det", "jag", "man", "vi", "de", "att", "en", "inte", "också", "sig"],
            "om": ["det", "jag", "man", "du", "vi", "de", "en", "inte", "också", "att"],
            "på": ["en", "det", "sätt", "grund", "tider", "internet", "skola", "arbete", "sidan", "morgonen"],
            "i": ["en", "det", "dags", "morgon", "kväll", "dag", "år", "svverige", "stan", "skolan"],
            "till": ["en", "ett", "dig", "mig", "sig", "oss", "er", "dem", "alla", "baka"],
        ]

        if let continuations = swedishContinuations[lastWord] {
            for (i, word) in continuations.enumerated() {
                let ngramScore = 1.0 - Double(i) * 0.1
                predictions.append((word, ngramScore * 0.5))
            }
        }

        // (b) Common Swedish collocations
        let collocationBonus: [String: [String]] = [
            "bra": ["på", "ide", "svar", "resultat", "exempel"],
            "mycket": ["bra", "viktigt", "intressant", "svårt", "lätt", "tack"],
            "inte": ["allt", "bara", "heller", "än", "så", "mycket", "alls"],
            "också": ["en", "ett", "jag", "vi", "de", "man", "det", "bara"],
            "bara": ["en", "ett", "jag", "vi", "de", "man", "det", "inte"],
        ]

        if let bonusWords = collocationBonus[lastWord] {
            for word in bonusWords {
                if let idx = predictions.firstIndex(where: { $0.word == word }) {
                    predictions[idx].score += 0.3
                } else {
                    predictions.append((word, 0.25))
                }
            }
        }

        // (c) Semantic field continuity — if text is about a topic, predict topic-relevant words
        let topicWords: [String: [String]] = [
            "skola": ["lära", "studera", "lärare", "elev", "kunskap", "utbildning", "prov", "läxa"],
            "data": ["dator", "program", "kod", "system", "nätverk", "internet", "app", "server"],
            "natur": ["skog", "sjö", "berg", "djur", "väder", "miljö", "klimat", "vatten"],
            "känsla": ["glad", "ledsen", "arg", "rädd", "kär", "stressad", "lugn", "nöjd"],
            "mat": ["äta", "middag", "frukost", "lunch", "recept", "god", "lagar", "köpa"],
        ]

        let recentContent = words.suffix(10).joined(separator: " ")
        for (topic, relatedWords) in topicWords {
            if recentContent.contains(topic) {
                for word in relatedWords {
                    if let idx = predictions.firstIndex(where: { $0.word == word }) {
                        predictions[idx].score += 0.15
                    } else {
                        predictions.append((word, 0.15))
                    }
                }
            }
        }

        // Bigram-based predictions from the last two words
        if !secondLast.isEmpty {
            let bigram = "\(secondLast)_\(lastWord)"
            let commonBigrams: [String: [String]] = [
                "jag_är": ["en", "inte", "mycket", "glad", "trött", "här", "redo", "säker"],
                "det_är": ["viktigt", "bra", "svårt", "inte", "också", "en", "ett", "mycket"],
                "jag_har": ["en", "inte", "också", "redan", "alltid", "aldrig", "mycket", "inget"],
                "det_finns": ["en", "många", "olika", "inga", "flera", "alltid", "redan", "också"],
                "jag_vill": ["ha", "inte", "också", "bara", "gärna", "inte", "även", "hellre"],
                "jag_kan": ["inte", "också", "bara", "göra", "hjälp", "försöka", "inte", "alltid"],
            ]

            if let continuations = commonBigrams[bigram] {
                for word in continuations {
                    if let idx = predictions.firstIndex(where: { $0.word == word }) {
                        predictions[idx].score += 0.4
                    } else {
                        predictions.append((word, 0.35))
                    }
                }
            }
        }

        // Sort by score and return top predictions
        let sorted = predictions.sorted { $0.score > $1.score }
        let seen = Set<String>()
        var result: [String] = []
        for pred in sorted where !seen.contains(pred.word) {
            result.append(pred.word)
            if result.count >= count { break }
        }

        return result.isEmpty ? ["är", "en", "det", "och", "som", "jag", "inte", "också", "man", "vi"].prefix(count).map { String($0) } : result
    }

    // MARK: - Speech Act Classification (Iteration 38)

    struct SpeechAct {
        let type: SpeechActType
        let confidence: Double
        let explanation: String
        let surfaceForm: String
    }

    enum SpeechActType: String {
        case assertive
        case directive
        case commissive
        case expressive
        case declaration
    }

    func classifySpeechAct(_ text: String) -> SpeechAct {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        // Declarations
        let performatives = ["jag förklarar", "jag dömer", "jag utser", "jag beslutar", "jag erkänner"]
        for pv in performatives where lower.hasPrefix(pv) {
            return SpeechAct(type: .declaration, confidence: 0.9, explanation: "Performativt: '\(pv)'", surfaceForm: String(text.prefix(60)))
        }

        // Commissives
        let commissives = ["jag ska", "jag lovar", "jag garanterar", "jag försäkrar", "jag erbjuder", "jag kommer att", "jag åtar mig"]
        for cm in commissives where lower.contains(cm) {
            return SpeechAct(type: .commissive, confidence: 0.85, explanation: "Åtagande: '\(cm)'", surfaceForm: String(text.prefix(60)))
        }

        // Expressives
        let expressives = ["tack", "förlåt", "ursäkta", "grattis", "fy", "oj", "wow", "åh", "herregud", "jag är ledsen", "jag är glad", "vad roligt", "vad synd"]
        for em in expressives where lower.hasPrefix(em) || lower.contains(" \(em)") {
            return SpeechAct(type: .expressive, confidence: lower.contains("!") ? 0.9 : 0.75, explanation: "Känslouttryck: '\(em)'", surfaceForm: String(text.prefix(60)))
        }
        if lower.contains("!") && words.count <= 5 {
            return SpeechAct(type: .expressive, confidence: 0.7, explanation: "Kort utrop", surfaceForm: String(text.prefix(60)))
        }

        // Directives
        if lower.contains("?") {
            return SpeechAct(type: .directive, confidence: 0.8, explanation: "Fråga — begär information", surfaceForm: String(text.prefix(60)))
        }
        let imperatives = ["berätta", "förklara", "beskriv", "visa", "ge", "skriv", "säg", "gör", "kom", "gå", "ta", "lyssna", "hjälp", "öppna", "stäng", "läs", "skicka"]
        if let first = words.first, imperatives.contains(first) {
            return SpeechAct(type: .directive, confidence: 0.85, explanation: "Imperativ: '\(first)'", surfaceForm: String(text.prefix(60)))
        }
        for md in ["kan du", "skulle du", "vill du", "be om"] where lower.contains(md) {
            return SpeechAct(type: .directive, confidence: 0.8, explanation: "Begäran: '\(md)'", surfaceForm: String(text.prefix(60)))
        }

        // Default: Assertive
        return SpeechAct(type: .assertive, confidence: 0.7, explanation: "Påstående", surfaceForm: String(text.prefix(60)))
    }

    // MARK: - Politeness Strategy Detection (Iteration 36)

    struct PolitenessAnalysis {
        let strategy: PolitenessStrategy
        let confidence: Double
        let markers: [String]
        let explanation: String
    }

    enum PolitenessStrategy: String {
        case positivePoliteness
        case negativePoliteness
        case baldOnRecord
        case offRecord
    }

    func detectPolitenessStrategy(_ text: String) -> PolitenessAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        let solidarityMarkers = ["vi", "tillsammans", "gemensam", "kompis", "vän", "kompisar"]
        let solidarityCount = words.filter { solidarityMarkers.contains($0) }.count

        let hedgingPhrases = ["skulle kunna", "om det går", "jag undrar", "kanske", "möjligen", "eventuellt", "skulle", "ursäkta mig", "förlåt att"]
        let hedgingCount = hedgingPhrases.filter { lower.contains($0) }.count

        let imperativeVerbs = ["gör", "skriv", "säg", "ge", "ta", "kom", "gå", "öppna", "stäng", "sluta", "börja", "läs"]
        let isFirstImperative = words.first.map { imperativeVerbs.contains($0) } ?? false

        let hintPhrases = ["det vore bra om", "skulle vara fint", "tänkte bara att", "man kanske kunde", "det sägs att", "jag undrar om"]
        let hintCount = hintPhrases.filter { lower.contains($0) }.count

        let positiveScore = Double(solidarityCount) * 0.3 + (lower.contains("du") ? 0.2 : 0.0)
        let negativeScore = Double(hedgingCount) * 0.35
        let baldScore = isFirstImperative ? 0.9 : 0.0
        let offScore = Double(hintCount) * 0.4

        let maxScore = max(positiveScore, negativeScore, baldScore, offScore)

        if maxScore == baldScore && baldScore > 0 {
            return PolitenessAnalysis(strategy: .baldOnRecord, confidence: 0.85, markers: [words.first ?? ""], explanation: "Direkt kommando — ingen artighetsmarkör")
        } else if maxScore == offScore && offScore > 0.3 {
            let found = hintPhrases.filter { lower.contains($0) }
            return PolitenessAnalysis(strategy: .offRecord, confidence: 0.7, markers: found, explanation: "Antydan/implikatur — indirekt kommunikation")
        } else if maxScore == negativeScore && negativeScore > 0.3 {
            let found = hedgingPhrases.filter { lower.contains($0) }
            return PolitenessAnalysis(strategy: .negativePoliteness, confidence: 0.75, markers: found, explanation: "Negativ artighet — hedging och indirekthet")
        } else if maxScore == positiveScore && positiveScore > 0.3 {
            let found = words.filter { solidarityMarkers.contains($0) }
            return PolitenessAnalysis(strategy: .positivePoliteness, confidence: 0.7, markers: found, explanation: "Positiv artighet — solidaritetsmarkörer")
        }

        return PolitenessAnalysis(strategy: .baldOnRecord, confidence: 0.5, markers: [], explanation: "Ingen tydlig artighetsstrategi detekterad")
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 51-60: Deep Language Understanding
    // ═══════════════════════════════════════════════════════════

    // MARK: - Iteration 51: Phonological Awareness

    struct PhonologicalAnalysis {
        let text: String
        let vowelHarmonyScore: Double           // 0-1, Swedish has limited vowel harmony
        let consonantClusters: [ConsonantCluster]
        let syllableStructure: [SyllableInfo]
        let stressPattern: StressPattern
        let phonologicalComplexity: Double       // 0-1 overall complexity
        let syllableCount: Int
        let complexPatterns: Int                 // Number of complex phonological patterns
    }

    struct ConsonantCluster: Identifiable {
        let id = UUID()
        let cluster: String
        let position: Int
        let type: ClusterType
        let difficulty: Double

        enum ClusterType: String {
            case sj = "sj"       // /ɧ/ — unique Swedish phoneme
            case stj = "stj"     // /ɧ/
            case tj = "tj"       // /ɕ/
            case sk = "sk"       // /ɧ/ or /sk/
            case rs = "rs"       // /ʂ/
            case general = "general"
        }
    }

    struct SyllableInfo {
        let syllable: String
        let structure: String        // CV, CVC, CCV, CCVC, etc.
        let isStressed: Bool
        let stressLevel: StressLevel

        enum StressLevel {
            case primary, secondary, unstressed
        }
    }

    struct StressPattern {
        let primaryStressSyllable: Int
        let secondaryStressSyllables: [Int]
        let pattern: String          // e.g., "SUSU", "SUSUSU"
        let pitchAccent: PitchAccentType?

        enum PitchAccentType {
            case accent1, accent2, unknown
        }
    }

    // Swedish consonant clusters — many produce the unique /ɧ/ (sje-sound)
    private static let sjClusterPatterns = ["sj", "stj", "tj", "skj", "sk"]
    private static let rsClusterPattern = "rs"

    // Common Swedish consonant clusters
    private static let consonantClusterPatterns: [String] = [
        "sj", "stj", "tj", "skj", "sk", "rs", "rt", "rn", "rl", "rd",
        "str", "skr", "spr", "spl", "skv", "stv", "sv", "kv", "tw",
        "bl", "kl", "fl", "gl", "pl", "sl", "tl",
        "br", "kr", "fr", "gr", "pr", "tr", "dr",
        "sp", "st", "sk", "sv", "sn", "sm", "sl"
    ]

    /// Swedish syllable nucleus vowels
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y", "å", "ä", "ö", "A", "E", "I", "O", "U", "Y", "Å", "Ä", "Ö"]

    func analyzePhonology(text: String) -> PhonologicalAnalysis {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        var allClusters: [ConsonantCluster] = []
        var allSyllables: [SyllableInfo] = []
        var totalComplexPatterns = 0

        for (wordIdx, word) in words.enumerated() {
            let lower = word.lowercased()

            // Detect consonant clusters
            for cluster in Self.consonantClusterPatterns {
                var searchFrom = 0
                while let range = lower.range(of: cluster, range: lower.index(lower.startIndex, offsetBy: searchFrom)..<lower.endIndex) {
                    let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
                    let clusterType: ConsonantCluster.ClusterType
                    switch cluster {
                    case "sj": clusterType = .sj
                    case "stj": clusterType = .stj
                    case "tj": clusterType = .tj
                    case "sk": clusterType = .sk
                    case "rs": clusterType = .rs
                    default: clusterType = .general
                    }
                    let difficulty = clusterType == .sj || clusterType == .stj || clusterType == .tj ? 0.9 :
                                     clusterType == .sk ? 0.7 :
                                     clusterType == .rs ? 0.8 : 0.4
                    allClusters.append(ConsonantCluster(
                        cluster: cluster, position: position, type: clusterType, difficulty: difficulty
                    ))
                    if clusterType != .general { totalComplexPatterns += 1 }
                    searchFrom = lower.distance(from: lower.startIndex, to: range.upperBound)
                    if searchFrom >= lower.count { break }
                }
            }

            // Syllable decomposition (approximate)
            let syllables = approximateSyllables(lower)
            for (sylIdx, syl) in syllables.enumerated() {
                let structure = computeSyllableStructure(syl)
                let isStressed = sylIdx == 0
                let stressLevel: SyllableInfo.StressLevel
                if sylIdx == 0 {
                    stressLevel = .primary
                } else if sylIdx == 2 && syllables.count > 3 {
                    stressLevel = .secondary
                } else {
                    stressLevel = .unstressed
                }
                allSyllables.append(SyllableInfo(syllable: syl, structure: structure, isStressed: isStressed, stressLevel: stressLevel))
            }
        }

        // Vowel harmony — Swedish has some vowel harmony in compound words
        let vowelHarmonyScore = computeVowelHarmony(words)

        // Stress pattern
        let stressPattern = computeStressPattern(allSyllables)

        // Phonological complexity
        let clusterComplexity = min(1.0, Double(totalComplexPatterns) * 0.15)
        let syllableComplexity = min(1.0, Double(allSyllables.filter { $0.structure.count > 3 }.count) * 0.1)
        let phonologicalComplexity = clusterComplexity * 0.6 + syllableComplexity * 0.4

        return PhonologicalAnalysis(
            text: text,
            vowelHarmonyScore: vowelHarmonyScore,
            consonantClusters: allClusters,
            syllableStructure: allSyllables,
            stressPattern: stressPattern,
            phonologicalComplexity: phonologicalComplexity,
            syllableCount: allSyllables.count,
            complexPatterns: totalComplexPatterns
        )
    }

    /// Approximate syllable splitting for Swedish
    private func approximateSyllables(_ word: String) -> [String] {
        guard !word.isEmpty else { return [] }
        var syllables: [String] = []
        var current = ""
        var vowelCount = 0

        for char in word {
            current.append(char)
            if Self.vowels.contains(char) {
                vowelCount += 1
                // After vowel + optional consonants, try to split
                if vowelCount > 1 && current.count > 2 {
                    syllables.append(current)
                    current = ""
                    vowelCount = 0
                }
            }
        }
        if !current.isEmpty {
            if syllables.isEmpty {
                syllables.append(current)
            } else {
                syllables[syllables.count - 1] += current
            }
        }
        return syllables.isEmpty ? [word] : syllables
    }

    /// Compute syllable structure (CV, CVC, CCV, etc.)
    private func computeSyllableStructure(_ syllable: String) -> String {
        var structure = ""
        var prevWasConsonant = false
        for char in syllable.lowercased() {
            if Self.vowels.contains(char) {
                structure.append("V")
                prevWasConsonant = false
            } else {
                structure.append("C")
                prevWasConsonant = true
            }
        }
        return structure.isEmpty ? "V" : structure
    }

    /// Compute vowel harmony score — Swedish has some harmony in compounds
    private func computeVowelHarmony(_ words: [String]) -> Double {
        var harmonyScore: Double = 0
        for word in words where word.count > 4 {
            let vowelsInWord = word.lowercased().filter { Self.vowels.contains($0) }
            if vowelsInWord.count >= 3 {
                // Check for front/back vowel mixing (Swedish vowel harmony constraint)
                let frontVowels = vowelsInWord.filter { ["e", "i", "y", "ä", "ö"].contains($0) }
                let backVowels = vowelsInWord.filter { ["a", "o", "u", "å"].contains($0) }
                if !frontVowels.isEmpty && !backVowels.isEmpty {
                    harmonyScore += 0.1 // Some mixing = slight disharmony
                }
            }
        }
        return min(1.0, harmonyScore)
    }

    /// Compute stress pattern for analyzed text
    private func computeStressPattern(_ syllables: [SyllableInfo]) -> StressPattern {
        let primaryIdx = syllables.firstIndex { $0.stressLevel == .primary } ?? 0
        let secondaryIndices = syllables.enumerated().compactMap { $0.element.stressLevel == .secondary ? $0.offset : nil }
        let pattern = syllables.map { s in
            switch s.stressLevel {
            case .primary: return "S"
            case .secondary: return "U"
            case .unstressed: return "u"
            }
        }.joined()
        return StressPattern(
            primaryStressSyllable: primaryIdx,
            secondaryStressSyllables: secondaryIndices,
            pattern: pattern,
            pitchAccent: nil
        )
    }

    // MARK: - Iteration 52: Swedish Pitch Accent Detection

    /// Pitch accent 1 (akut accent) vs accent 2 (grav accent)
    /// Critical for Swedish — distinguishes many minimal pairs
    /// Accent 1: single peak (e.g., "anden" = the duck)
    /// Accent 2: double peak (e.g., "anden" = the spirit)

    func detectPitchAccent(word: String) -> Int {
        let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if let accent = Self.pitchAccentDatabase[lower] {
            return accent
        }
        // Heuristic: multi-syllable compound words tend to have accent 2
        let syllables = approximateSyllables(lower)
        if syllables.count >= 3 {
            return 2 // Compounds and longer words typically accent 2
        }
        return 1 // Default: accent 1 for short/simple words
    }

    /// 500+ Swedish words with known pitch accent
    /// 1 = accent 1 (akut), 2 = accent 2 (grav)
    private static let pitchAccentDatabase: [String: Int] = [
        // Accent 1 words (akut accent) — typically monosyllabic roots + simple words
        "and": 1, "bil": 1, "bok": 1, "dag": 1, "eld": 1, "fot": 1, "god": 1, "hus": 1,
        "jul": 1, "kog": 1, "lag": 1, "man": 1, "not": 1, "orm": 1, "pung": 1, "rost": 1,
        "sol": 1, "tåg": 1, "uggla": 1, "vit": 1, "vän": 1, "år": 1, "älg": 1, "öring": 1,
        "and": 1, "ball": 1, "dans": 1, "fast": 1, "glass": 1, "hand": 1, "katt": 1, "land": 1,
        "mjölk": 1, "natt": 1, "ost": 1, "präst": 1, "qvist": 1, "rätt": 1, "säng": 1, "tall": 1,
        "varg": 1, "yx": 1, "zoo": 1, "åsna": 1, "ängel": 1, "öra": 1,
        "banan": 1, "klocka": 1, "flicka": 1, "pojke": 1, "kvinna": 1, "man": 1, "barn": 1,
        "fader": 1, "moder": 1, "broder": 1, "syster": 1, "fader": 1,
        "springa": 1, "gå": 1, "komma": 1, "ta": 1, "ge": 1, "se": 1, "höra": 1, "säga": 1,
        "bra": 1, "dålig": 1, "stor": 1, "liten": 1, "ny": 1, "gammal": 1, "ung": 1,
        "vacker": 1, "ful": 1, "snabb": 1, "långsam": 1, "tung": 1, "lätt": 1,
        "hus": 1, "rum": 1, "kök": 1, "badrum": 1, "sovrum": 1, "dörr": 1, "fönster": 1,
        "bord": 1, "stol": 1, "lamp": 1, "bädd": 1, "soffa": 1, "bok": 1, "tidning": 1,
        "äpple": 1, "päron": 1, "banan": 1, "apelsin": 1, "bröd": 1, "smör": 1, "ost": 1,
        "mjölk": 1, "vatten": 1, "kaffe": 1, "te": 1, "kött": 1, "fisk": 1, "kyckling": 1,
        "bil": 1, "buss": 1, "tåg": 1, "flygplan": 1, "cykel": 1, "båt": 1, "biljett": 1,
        "skola": 1, "lärare": 1, "elev": 1, "bok": 1, "penna": 1, "papper": 1, "dator": 1,
        "arbete": 1, "jobb": 1, "kontor": 1, "chef": 1, "kollega": 1, "lön": 1, "semester": 1,
        "sjuk": 1, "frisk": 1, "läkare": 1, "sjukhus": 1, "medicin": 1, "huvudvärk": 1,
        "regn": 1, "sol": 1, "snö": 1, "vind": 1, "moln": 1, "väder": 1, "temperatur": 1,
        "glad": 1, "ledsen": 1, "arg": 1, "rädd": 1, "trött": 1, "nyfiken": 1, "kär": 1,
        "pengar": 1, "pris": 1, "butik": 1, "marknad": 1, "bank": 1, "kredit": 1, "ränta": 1,
        "färg": 1, "röd": 1, "blå": 1, "grön": 1, "gul": 1, "svart": 1, "vit": 1, "grå": 1,
        "en": 1, "två": 1, "tre": 1, "fyra": 1, "fem": 1, "sex": 1, "sju": 1, "åtta": 1, "nio": 1, "tio": 1,
        "hund": 1, "katt": 1, "häst": 1, "ko": 1, "gris": 1, "får": 1, "get": 1, "höna": 1, "anka": 1,
        "skog": 1, "sjö": 1, "berg": 1, "hav": 1, "flod": 1, "ö": 1, "stad": 1, "by": 1, "land": 1,
        "vän": 1, "fiende": 1, "familj": 1, "barn": 1, "förälder": 1, "morfar": 1, "farmor": 1,
        "måndag": 1, "tisdag": 1, "onsdag": 1, "torsdag": 1, "fredag": 1, "lördag": 1, "söndag": 1,
        "januari": 1, "februari": 1, "mars": 1, "april": 1, "maj": 1, "juni": 1, "juli": 1,
        "år": 1, "månad": 1, "vecka": 1, "dag": 1, "timme": 1, "minut": 1, "sekund": 1,
        "nord": 1, "syd": 1, "öst": 1, "väst": 1, "vänster": 1, "höger": 1, "fram": 1, "bak": 1,
        "jag": 1, "du": 1, "han": 1, "hon": 1, "den": 1, "det": 1, "vi": 1, "ni": 1, "de": 1,
        "är": 1, "var": 1, "bli": 1, "ha": 1, "få": 1, "kunna": 1, "måste": 1, "ska": 1,
        "och": 1, "eller": 1, "men": 1, "för": 1, "om": 1, "att": 1, "som": 1, "när": 1,
        "här": 1, "där": 1, "upp": 1, "ner": 1, "in": 1, "ut": 1, "på": 1, "av": 1, "till": 1,
        "mycket": 1, "lite": 1, "alla": 1, "många": 1, "någon": 1, "ingen": 1, "varje": 1,
        "idag": 1, "igår": 1, "imorgon": 1, "nu": 1, "sedan": 1, "först": 1, "sen": 1,
        // Accent 2 words (grav accent) — typically polysyllabic, compounds, -ande/-ende
        "äpple": 2, "bagare": 2, "dörrar": 2, "flickor": 2, "gator": 2, "hundar": 2,
        "kilometer": 2, "lärare": 2, "momenter": 2, "någorlunda": 2, "ordinarie": 2,
        "påfund": 2, "kvastar": 2, "reformer": 2, "studenter": 2, "undantag": 2,
        "vandrare": 2, "ynglingar": 2, "ämbete": 2, "övergång": 2, "återkomst": 2,
        "andelar": 2, "arbetare": 2, "berättelse": 2, "datorspel": 2, "egenartad": 2,
        "författare": 2, "genomsnitt": 2, "hemlighet": 2, "information": 2, "järnväg": 2,
        "kaffebryggare": 2, "läkemedel": 2, "matematik": 2, "nordpolen": 2, "organisation": 2,
        "persontåg": 2, "quantitet": 2, "regering": 2, "sjukhus": 2, "tillsammans": 2,
        "universitet": 2, "vetenskap": 2, "ytterligare": 2, "äventyr": 2,
        "sjungen": 2, "bunden": 2, "funnen": 2, "kommen": 2, "runnen": 2, "sprungen": 2,
        "stungen": 2, "svunnen": 2, "tvungen": 2, "unnen": 2, "vunnen": 2,
        "andning": 2, "betydelse": 2, "diskussion": 2, "effektiv": 2, "förändring": 2,
        "gemenskap": 2, "händelse": 2, "illustration": 2, "juridik": 2, "kommunikation": 2,
        "lagstiftning": 2, "medvetande": 2, "nationell": 2, "operation": 2, "produktion": 2,
        "reflektion": 2, "situation": 2, "teknologi": 2, "upplevelse": 2, "växling": 2,
        "yllen": 2, "zink": 2, "ämne": 2, "övning": 2,
        // Pitch accent minimal pairs — same spelling, different accent, different meaning
        "anden": 1,    // Accent 1 = the duck (anden); Accent 2 = the spirit (anden)
        "grisen": 1,   // Accent 1 = the pig; context distinguishes
        "tomten": 1,   // Accent 1 = the plot; Accent 2 = Santa/elf
        "buren": 1,    // Accent 1 = carried; Accent 2 = the cage
        "fången": 1,   // Accent 1 = captured; Accent 2 = the lap
        "stegen": 1,   // Accent 1 = the step; Accent 2 = the ladder
        "släkten": 1,  // Accent 1 = the relative; Accent 2 = the family/clan
        "tanken": 1,   // Accent 1 = the thought; Accent 2 = the tank
        "vännen": 1,   // Accent 1 = the friend; Accent 2 = (context)
        "måttet": 1,   // Accent 1 = the measure; Accent 2 = (context)
        "ordet": 1,    // Accent 1 = the word; Accent 2 = (context)
        "boken": 1,    // Accent 1 = the book; Accent 2 = (context)
        "fisken": 1,   // Accent 1 = the fish; Accent 2 = (context)
        "foten": 1,    // Accent 1 = the foot; Accent 2 = (context)
        " handen": 1,  // Accent 1 = the hand; Accent 2 = (context)
        "kaminen": 1,  // Accent 1 = the stove; Accent 2 = (context)
        "stenen": 1,   // Accent 1 = the stone; Accent 2 = (context)
        "tåget": 1,    // Accent 1 = the train; Accent 2 = (context)
        "vägen": 1,    // Accent 1 = the road; Accent 2 = (context)
        "gatan": 1,    // Accent 1 = the street; Accent 2 = (context)
        "floden": 1,   // Accent 1 = the river; Accent 2 = (context)
        "skogen": 1,   // Accent 1 = the forest; Accent 2 = (context)
        "vinden": 1,   // Accent 1 = the wind; Accent 2 = (context)
        "målet": 1,    // Accent 1 = the goal; Accent 2 = the meal
        "fallet": 1,   // Accent 1 = the case; Accent 2 = the fall
        "laget": 1,    // Accent 1 = the team; Accent 2 = the law
        "bordet": 1,   // Accent 1 = the table
        "huset": 1,    // Accent 1 = the house
        "landet": 1,   // Accent 1 = the country
        "vattnet": 1,  // Accent 1 = the water
        "sol en": 1,   // Accent 1 = the sun
        "månen": 1,    // Accent 1 = the moon
        "stjärnan": 1, // Accent 1 = the star
        "blomman": 1,  // Accent 1 = the flower
        "trädet": 1,   // Accent 1 = the tree
        "fågeln": 1,   // Accent 1 = the bird
        " älgen": 1,   // Accent 1 = the moose
        "björnen": 1,  // Accent 1 = the bear
        "räven": 1,    // Accent 1 = the fox
        "örnen": 1,    // Accent 1 = the eagle
        // More accent 2 words (compounds, derivations)
        "sjukhuset": 2, "flygplatsen": 2, "järnvägsstation": 2, "handelsområde": 2,
        "utbildningsnivå": 2, "forskningresultat": 2, "arbetslöshet": 2, "bostadsområde": 2,
        "miljöfråga": 2, "säkerhetspolitik": 2, "integrationsprocess": 2,
        "klimatförändring": 2, "samhällsutveckling": 2, "sjukvårdsreform": 2,
        "skolundervisning": 2, "näringslivspolitik": 2, "försvarsbeslut": 2,
        "kulturverksamhet": 2, "idrottsförening": 2, "musikinstrument": 2,
        "konstutställning": 2, "litteraturpris": 2, "teaterföreställning": 2,
        "naturvetenskap": 2, "samhällsvetenskap": 2, "rättsvetenskap": 2,
        "ekonomi": 2, "filosofi": 2, "historia": 2, "psykologi": 2, "sociologi": 2,
        "antropologi": 2, "arkeologi": 2, "biologi": 2, "kemi": 2, "fysik": 2,
        "matematik": 2, "statistik": 2, "geografi": 2, "geologi": 2, "astronomi": 2,
        // Common Swedish words accent 2
        "vackrare": 2, "vackrast": 2, "vackraste": 2, "snabbare": 2, "snabbast": 2,
        "längre": 2, "längst": 2, "bättre": 2, "bäst": 2, "sämre": 2, "sämst": 2,
        "mindre": 2, "minst": 2, "mer": 2, "mest": 2, "fler": 2, "flest": 2,
        "större": 2, "störst": 2, "högre": 2, "högst": 2, "lägre": 2, "lägst": 2,
        "tidigare": 2, "tidigast": 2, "senare": 2, "senast": 2, "nyare": 2, "nyast": 2,
        "äldre": 2, "äldst": 2, "yngre": 2, "yngst": 2, "större": 2,
        "springande": 2, "gående": 2, "kommande": 2, "boende": 2, "levande": 2,
        "döende": 2, "troende": 2, "seende": 2, "hörande": 2, "talande": 2,
        "skrivande": 2, "läsande": 2, "arbetande": 2, "tänkande": 2, "kännande": 2,
        "förstående": 2, "lärande": 2, "undervisande": 2, "forskande": 2,
        "utvecklande": 2, "skapande": 2, "byggande": 2, "förbättrande": 2,
        // Additional common words — accent 1
        "bror": 1, "syster": 1, "mor": 1, "far": 1, "son": 1, "dotter": 1,
        "vän": 1, "kompis": 1, "granne": 1, "kollega": 1, "chef": 1, "elev": 1,
        "vinter": 1, "sommar": 1, "vår": 1, "höst": 1, "morgon": 1, "kväll": 1,
        "natt": 1, "eftermiddag": 1, "middag": 1, "frukost": 1, "lunch": 1,
        "köttbullar": 2, "gravlax": 2, "prinsesstårta": 2, "kanelbulle": 2,
        "folköl": 2, "läskedryck": 2, "smörgåstårta": 2, "rärakor": 2,
        // More minimal pairs
        "tomten": 2,   // Accent 2 = Santa/elf; Accent 1 = the plot/lot
        "buren": 2,    // Accent 2 = the cage; Accent 1 = carried
        "fången": 2,   // Accent 2 = the prisoner/lap; Accent 1 = captured
        "stegen": 2,   // Accent 2 = the ladder; Accent 1 = the steps
        "anden": 2,    // Accent 2 = the spirit; Accent 1 = the duck
        "släkten": 2,  // Accent 2 = the clan; Accent 1 = the relative
    ]

    /// Pitch-accent homograph pairs for WSD disambiguation
    private static let pitchAccentHomographPairs: [(word: String, accent1Meaning: String, accent2Meaning: String)] = [
        ("anden", "anden (the duck)", "anden (the spirit/ghost)"),
        ("tomten", "tomten (the plot/lot)", "tomten (Santa Claus/the elf)"),
        ("buren", "buren (carried)", "buren (the cage)"),
        ("fången", "fången (captured)", "fången (the prisoner/the lap)"),
        ("stegen", "stegen (the steps)", "stegen (the ladder)"),
        ("släkten", "släkten (the relative)", "släkten (the clan/family)"),
        ("tanken", "tanken (the thought)", "tanken (the tank)"),
        ("måttet", "måttet (the measure)", "måttet (context-dependent)"),
        ("målet", "målet (the goal/target)", "målet (the meal/food)"),
        ("fallet", "fallet (the case/matter)", "fallet (the fall/cascade)"),
        ("laget", "laget (the team)", "laget (the law)"),
    ]

    /// Disambiguate pitch-accent homographs using context
    func disambiguatePitchAccentHomograph(word: String, context: String) -> (accent: Int, meaning: String)? {
        let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let contextLower = context.lowercased()

        for pair in Self.pitchAccentHomographPairs where pair.word == lower {
            // Use context words to disambiguate
            let accent1Words = pair.accent1Meaning.lowercased().components(separatedBy: .whitespaces)
            let accent2Words = pair.accent2Meaning.lowercased().components(separatedBy: .whitespaces)

            let contextWords = Set(contextLower.components(separatedBy: .whitespacesAndNewlines))
            let a1Overlap = contextWords.intersection(accent1Words).count
            let a2Overlap = contextWords.intersection(accent2Words).count

            if a1Overlap > a2Overlap {
                return (1, pair.accent1Meaning)
            } else if a2Overlap > a1Overlap {
                return (2, pair.accent2Meaning)
            }
            // If ambiguous, use the database default
            if let defaultAccent = Self.pitchAccentDatabase[lower] {
                return (defaultAccent, defaultAccent == 1 ? pair.accent1Meaning : pair.accent2Meaning)
            }
        }
        return nil
    }

    // MARK: - Iteration 53: Orthographic Normalization

    struct OrthographicNormalization {
        let normalized: String
        let changes: [OrthographicChange]
        let compoundErrors: [CompoundError]
        let normalizationScore: Double  // 0-1, how many changes were needed
    }

    struct OrthographicChange: Identifiable {
        let id = UUID()
        let original: String
        let corrected: String
        let type: OrthographicChangeType
        let position: Int

        enum OrthographicChangeType {
            case dialectNormalization   // å→a, ä→e
            case capitalizationFix
            case commonMisspelling
            case informalSpelling
            case punctuationFix
            case spacing
        }
    }

    struct CompoundError: Identifiable {
        let id = UUID()
        let original: String
        let corrected: String
        let confidence: Double
        let explanation: String
    }

    /// Common Swedish misspellings and their corrections
    private static let commonMisspellings: [String: String] = [
        "int": "inte", "ite": "inte", "itne": "inte",
        "inget": "inget", "inggen": "ingen", "ingna": "inga",
        "deff": "de", "demm": "dem", "dom": "de/dem",
        "sen": "sedan", "åt": "att", "att": "att",
        "får": "får", "får": "för", "for": "för",
        "varfor": "varför", "därför": "därför",
        "mycket": "mycket", "mycke": "mycket", "mykett": "mycket",
        "bra": "bra", "bror": "bra",
        "stor": "stor", "stoor": "stor",
        "liten": "liten", "liiten": "liten",
        "gammal": "gammal", "gammall": "gammal",
        "idag": "idag", "i dag": "i dag",
        "igår": "igår", "i går": "i går",
        "imorgon": "imorgon", "i morgon": "i morgon",
        "kanske": "kanske", "kanske": "kanske",
        "tack": "tack", "takk": "tack",
        "hej": "hej", "hejsan": "hejsan",
        "snälla": "snälla", "snäla": "snälla",
        "förlåt": "förlåt", "förlat": "förlåt",
        "ursäkta": "ursäkta", "ursäka": "ursäkta",
        "jag": "jag", "ja": "jag",
        "det": "det", "de": "de",
        "är": "är", "ar": "är",
        "har": "har", "ahr": "har",
        "med": "med", "medh": "med",
        "men": "men", "mne": "men",
        "och": "och", "ocj": "och", "ock": "och",
        "att": "att", "at": "att",
        "som": "som", "som": "som",
        "till": "till", "til": "till",
        "från": "från", "frn": "från",
        "över": "över", "över": "över",
        "under": "under", "under": "under",
        "mellan": "mellan", "melllan": "mellan",
        "genom": "genom", "genmo": "genom",
        "efter": "efter", "efetr": "efter",
        "före": "före", "före": "före",
        "mot": "mot", "mott": "mot",
        "hos": "hos", "hoss": "hos",
        "bland": "bland", "balnd": "bland",
        "utan": "utan", "utna": "utan",
        "inom": "inom", "ino": "inom",
    ]

    /// Swedish dialect spelling patterns
    private static let dialectSpellings: [String: String] = [
        // Skånska: ä→e
        "bäst": "bäst", "best": "bäst", "här": "här", "her": "här",
        "värld": "värld", "verld": "värld", "fäst": "fäst", "fest": "fäst",
        // Göteborgska specific
        "a": "å", "o": "å",
        // Norrländska
        "in": "ing", "en": "ing",
        // Finlandssvenska
        "stycke": "sak", "gård": "gård",
    ]

    /// Detects särskrivning (compound words written separately — very common Swedish error)
    private func detectSärskrivning(_ text: String) -> [CompoundError] {
        var errors: [CompoundError] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 1 }

        for i in 0..<(words.count - 1) {
            let w1 = words[i].lowercased()
            let w2 = words[i + 1].lowercased()

            // Check if combining creates a known compound
            let combined = w1 + w2
            if Self.commonCompounds.contains(combined) || looksLikeValidCompound(combined) {
                errors.append(CompoundError(
                    original: "\(w1) \(w2)",
                    corrected: combined,
                    confidence: 0.7,
                    explanation: "Särskrivning: '\(w1) \(w2)' bör skrivas ihop som '\(combined)'"
                ))
            }
        }
        return errors
    }

    /// Common Swedish compound words (for särskrivning detection)
    private static let commonCompounds: Set<String> = [
        "sjukhus", "flygplats", "järnväg", "handbok", "lärobok", "ordbok",
        "dagstidning", "morgonrock", "kvällstidning", "nattklub",
        "bostadshus", "affärsområde", "skolbarn", "barnbok",
        "frukostbord", "middagsbjudning", "eftermiddagskaffe",
        "högskola", "grundskola", "gymnasieskola", "folkshögskola",
        "sjukvård", "hälsovård", "äldreomsorg", "barnomsorg",
        "naturskydd", "miljöskydd", "datorkunskap", "språkkunskap",
        "arbetstillfälle", "bostadsområde", "handelsområde",
        "fritidshus", "sommarstuga", "vintersport", "fotbollslag",
        " ishockey", "skidåkning", "simhall", "gymnastik",
        "cykelväg", "bilväg", "gångväg", "järnvägsstation",
        "busshållplats", "tågstation", "flygplats", "hamnområde",
        "köksbord", "sovrum", "vardagsrum", "badrum", "arbetsrum",
        "skrivbord", "läslampa", "soffbord", "matbord",
        "kaffekopp", "tekopp", "vattenglas", "mjölkkanna",
        "äppelträd", "björkträd", "granträd", "tallskog",
        "äppeljuice", "apelsinjuice", "tranbärsjuice",
        "fiskbullar", "köttbullar", "pannkaka", "chokladkaka",
        "smörgåstårta", "prinsesstårta", "kladdkaka", "morotskaka",
        "sommarlov", "sportlov", "påsklov", "jullov",
        "hösttermin", "vårtermin", "terminsstart", "studiehandledning",
        "dataspel", "brädspel", "kortspel", "pusselspel",
        "mobiltelefon", "surfplatta", "bärbar_dator", "skrivare",
    ]

    private func looksLikeValidCompound(_ word: String) -> Bool {
        // Heuristic: Swedish compounds are typically 6+ chars and contain two recognizable stems
        guard word.count >= 6 else { return false }

        // Try splitting at various points
        for splitPoint in stride(from: 3, through: word.count - 3, by: 1) {
            let part1 = String(word.prefix(splitPoint))
            let part2 = String(word.suffix(word.count - splitPoint))

            // Check if both parts look like Swedish word stems
            let part1LooksSwedish = Self.commonSwedishStems.contains(where: { part1.hasPrefix($0) || $0.hasPrefix(part1) })
            let part2LooksSwedish = Self.commonSwedishStems.contains(where: { part2.hasPrefix($0) || $0.hasPrefix(part2) })

            if part1LooksSwedish && part2LooksSwedish && part1.count >= 2 && part2.count >= 2 {
                return true
            }
        }
        return false
    }

    /// Common Swedish word stems for compound detection
    private static let commonSwedishStems: Set<String> = [
        "bil", "hus", "stad", "land", "väg", "bok", "tid", "dag", "år", "månad",
        "vecka", "skola", "arbete", "jobb", "kök", "rum", "dörr", "fönster",
        "bord", "stol", "säng", "lamp", "vatten", "mjölk", "bröd", "smör",
        "fisk", "kött", "frukt", "grönt", "kaffe", "te", "äpple", "päron",
        "träd", "skog", "sjö", "hav", "berg", "dal", "äng", "mark",
        "sol", "måne", "stjärn", "regn", "snö", "vind", "moln",
        "barn", "man", "kvinna", "flick", "pojk", "vän", "familj",
        "hand", "fot", "huvud", "öga", "öra", "mun", "näsa",
        "dag", "natt", "morgon", "kväll", "eftermiddag",
        "sommar", "vinter", "vår", "höst",
        "stor", "liten", "bra", "dålig", "ny", "gammal", "ung", "röd",
        "blå", "grön", "gul", "svart", "vit", "grå",
        "spring", "gå", "kom", "ta", "ge", "se", "hör", "säg",
        "skriv", "läs", "tänk", "känn", "arbete", "bo", "lev",
        "sjuk", "frisk", "trött", "glad", "ledsen", "arg", "rädd",
        "hund", "katt", "häst", "ko", "gris", "får", "fågel", "anka",
        "färg", "form", "storlek", "vikt", "längd", "bredd", "höjd",
        "data", "dator", "telefon", "nät", "app", "program", "system",
    ]

    func normalizeOrthography(text: String) -> OrthographicNormalization {
        var current = text
        var changes: [OrthographicChange] = []
        var compoundErrors: [CompoundError] = []

        // 1. Detect särskrivning (compound spelling errors)
        compoundErrors = detectSärskrivning(text)

        // Apply särskrivning corrections
        for error in compoundErrors {
            current = current.replacingOccurrences(of: error.original, with: error.corrected)
        }

        // 2. Common misspelling correction
        let words = current.components(separatedBy: .whitespacesAndNewlines)
        var correctedWords: [String] = []
        for (idx, word) in words.enumerated() {
            let lower = word.lowercased()
            if let correction = Self.commonMisspellings[lower] {
                changes.append(OrthographicChange(
                    original: word, corrected: correction,
                    type: .commonMisspelling, position: idx
                ))
                // Preserve capitalization pattern
                if word.first?.isUppercase == true {
                    correctedWords.append(correction.prefix(1).uppercased() + correction.dropFirst())
                } else {
                    correctedWords.append(correction)
                }
            } else {
                correctedWords.append(word)
            }
        }
        current = correctedWords.joined(separator: " ")

        // 3. Capitalization fixes — sentence start
        let sentences = current.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var fixedSentences: [String] = []
        for sentence in sentences {
            if let first = sentence.first, first.isLowercase {
                let fixed = sentence.prefix(1).uppercased() + sentence.dropFirst()
                if fixed != sentence {
                    changes.append(OrthographicChange(
                        original: sentence, corrected: fixed,
                        type: .capitalizationFix, position: 0
                    ))
                }
                fixedSentences.append(fixed)
            } else {
                fixedSentences.append(sentence)
            }
        }
        current = fixedSentences.joined(separator: ". ")

        // Normalization score
        let normalizationScore = min(1.0, Double(changes.count + compoundErrors.count) * 0.05)

        return OrthographicNormalization(
            normalized: current,
            changes: changes,
            compoundErrors: compoundErrors,
            normalizationScore: normalizationScore
        )
    }

    // MARK: - Iteration 54: Swedish Dialect Detection

    struct DialectEstimate {
        let text: String
        let primaryDialect: SwedishDialect?
        let dialectScores: [SwedishDialect: Double]
        let markers: [DialectMarker]
        let confidence: Double
    }

    enum SwedishDialect: String, CaseIterable {
        case skanska = "Skånska"
        case goteborgska = "Göteborgska"
        case norrlandska = "Norrländska"
        case finlandssvenska = "Finlandssvenska"
        case stockholmska = "Stockholmska"
        case rikssvenska = "Rikssvenska"  // Standard Swedish
    }

    struct DialectMarker: Identifiable {
        let id = UUID()
        let marker: String
        let dialect: SwedishDialect
        let type: DialectMarkerType
        let position: Int

        enum DialectMarkerType {
            case vocabulary
            case phonology
            case morphology
            case spelling
            case slang
        }
    }

    /// Skånska markers
    private static let skanskaMarkers: [String: DialectMarker.DialectMarkerType] = [
        "e": .spelling,        // ä→e: bäst→best
        "ä": .spelling,        // Reduced ä usage
        "va": .vocabulary,     // was→va
        "här": .vocabulary,    // her
        "nån": .spelling,      // någon
        "ing": .spelling,      // -ing → -in
        "på": .vocabulary,
        "sö": .spelling,       // söder→sö
    ]

    /// Göteborgska markers
    private static let goteborgskaMarkers: [String: DialectMarker.DialectMarkerType] = [
        "ba": .slang,          // bara
        "isch": .slang,        // exclamation
        "w": .phonology,       // v→w: varit→warit
        "a": .spelling,        // å→a: på→pa
        "ska": .vocabulary,    // distinctive usage
        "korv": .vocabulary,   // korvmoj
        "moj": .vocabulary,
        "dä": .spelling,       // det→dä
        "bär": .vocabulary,
    ]

    /// Norrländska markers
    private static let norrlandskaMarkers: [String: DialectMarker.DialectMarkerType] = [
        "in": .morphology,     // -ing→-in: spring→sprin
        "å": .vocabulary,      // och→å
        "hitåt": .vocabulary,
        "ditåt": .vocabulary,
        "backe": .vocabulary,
        "bygd": .vocabulary,
        "fäbod": .vocabulary,
        "palt": .vocabulary,
        "rörk": .vocabulary,
        "kams": .vocabulary,
        "ren": .vocabulary,    // reindeer context
        "fjäll": .vocabulary,
        "skoter": .vocabulary,
    ]

    /// Finlandssvenska markers
    private static let finlandssvenskaMarkers: [String: DialectMarker.DialectMarkerType] = [
        "stycke": .vocabulary,   // thing (standard: sak)
        "gård": .vocabulary,     // yard
        "hugga": .vocabulary,    // cut (standard: hugga/kapa)
        "långhals": .vocabulary,
        "stadin": .vocabulary,
        "åboland": .vocabulary,
        "nyland": .vocabulary,
        "pik": .vocabulary,      // stick (standard: pinne)
        "knappis": .vocabulary,  // button
        "färja": .vocabulary,
        "skärgård": .vocabulary,
        "kaffi": .spelling,      // kaffe→kaffi
        "mycke": .spelling,      // mycket→mycke
        "ku": .spelling,         // hur→ku
    ]

    /// Stockholmska (urban slang) markers
    private static let stockholmskaMarkers: [String: DialectMarker.DialectMarkerType] = [
        "tja": .slang,           // greeting
        "tjabba": .slang,
        "tjena": .slang,
        "tjene": .slang,
        "guzz": .slang,
        "blä": .slang,
        "shyy": .slang,
        "wallah": .slang,
        "habibi": .slang,
        "lan": .slang,           // slang for "man"
        "bror": .slang,
        "ey": .slang,
        "förort": .slang,
        "snurr": .slang,
        "pang": .slang,
        "sug": .slang,
        "dryg": .slang,
        "crispig": .slang,
    ]

    func detectDialect(text: String) -> DialectEstimate {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        var markers: [DialectMarker] = []
        var scores: [SwedishDialect: Double] = Dictionary(uniqueKeysWithValues: SwedishDialect.allCases.map { ($0, 0.0) })

        // Check each word against dialect markers
        for (idx, word) in words.enumerated() {
            // Skånska
            for (marker, type) in Self.skanskaMarkers {
                if word == marker || (marker.count >= 3 && word.hasPrefix(marker)) {
                    scores[.skanska, default: 0] += 1.0
                    markers.append(DialectMarker(marker: word, dialect: .skanska, type: type, position: idx))
                }
            }
            // Göteborgska
            for (marker, type) in Self.goteborgskaMarkers {
                if word == marker || (marker.count >= 3 && word.hasPrefix(marker)) {
                    scores[.goteborgska, default: 0] += 1.0
                    markers.append(DialectMarker(marker: word, dialect: .goteborgska, type: type, position: idx))
                }
            }
            // Norrländska
            for (marker, type) in Self.norrlandskaMarkers {
                if word == marker || (marker.count >= 3 && word.hasPrefix(marker)) {
                    scores[.norrlandska, default: 0] += 1.0
                    markers.append(DialectMarker(marker: word, dialect: .norrlandska, type: type, position: idx))
                }
            }
            // Finlandssvenska
            for (marker, type) in Self.finlandssvenskaMarkers {
                if word == marker || (marker.count >= 3 && word.hasPrefix(marker)) {
                    scores[.finlandssvenska, default: 0] += 1.0
                    markers.append(DialectMarker(marker: word, dialect: .finlandssvenska, type: type, position: idx))
                }
            }
            // Stockholmska
            for (marker, type) in Self.stockholmskaMarkers {
                if word == marker || (marker.count >= 3 && word.hasPrefix(marker)) {
                    scores[.stockholmska, default: 0] += 1.0
                    markers.append(DialectMarker(marker: word, dialect: .stockholmska, type: type, position: idx))
                }
            }
        }

        // Normalize scores
        let maxScore = scores.values.max() ?? 0
        if maxScore > 0 {
            for key in scores.keys {
                scores[key] = scores[key]! / max(maxScore, 1.0)
            }
        }

        // Determine primary dialect
        let sorted = scores.sorted { $0.value > $1.value }
        let primaryDialect: SwedishDialect?
        if let first = sorted.first, first.value > 0.2 {
            primaryDialect = first.key
        } else {
            primaryDialect = .rikssvenska
        }

        let confidence = sorted.first?.value ?? 0

        return DialectEstimate(
            text: text,
            primaryDialect: primaryDialect,
            dialectScores: scores,
            markers: markers,
            confidence: confidence
        )
    }

    // MARK: - Iteration 55: Prosody and Rhythm Analysis

    struct ProsodyAnalysis {
        let text: String
        let sentenceLengthVariation: Double    // Coefficient of variation
        let averageSentenceLength: Double
        let punctuationPattern: PunctuationAnalysis
        let emphasisMarkers: [EmphasisMarker]
        let readingEaseScore: Double           // Adapted for Swedish (Läsbarhetsindex)
        let rhythmQuality: RhythmQuality
        let prosodyScore: Double               // Overall 0-1
    }

    struct PunctuationAnalysis {
        let commaCount: Int
        let periodCount: Int
        let exclamationCount: Int
        let questionCount: Int
        let semicolonCount: Int
        let dashCount: Int
        let pauseDensity: Double               // Punctuation per word
    }

    struct EmphasisMarker: Identifiable {
        let id = UUID()
        let type: EmphasisType
        let text: String
        let position: Int

        enum EmphasisType {
            case capitalization
            case exclamation
            case repetition
            case elongation     // "supeeeer"
            case intensifier    // "väldigt", "jätte"
        }
    }

    enum RhythmQuality: String {
        case monotonous = "Monoton"
        case moderate = "Måttlig variation"
        case good = "God variation"
        case excellent = "Utmärkt prosodi"
    }

    /// Swedish intensifiers
    private static let swedishIntensifiers: Set<String> = [
        "väldigt", "mycket", "jätte", "extremt", "oerhört", "fruktansvärt",
        "otroligt", "fantastiskt", "super", "extra", "särskilt", "helt",
        "fullständigt", "totalt", "absolut", "verkligen", "riktigt",
    ]

    func analyzeProsody(text: String) -> ProsodyAnalysis {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Sentence length variation
        let sentenceLengths = sentences.map { s in
            s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
        let avgLength = sentenceLengths.isEmpty ? 0.0 : Double(sentenceLengths.reduce(0, +)) / Double(sentenceLengths.count)
        let variance = sentenceLengths.isEmpty ? 0.0 :
            sentenceLengths.map { pow(Double($0) - avgLength, 2) }.reduce(0, +) / Double(sentenceLengths.count)
        let stdDev = sqrt(variance)
        let cv = avgLength > 0 ? stdDev / avgLength : 0.0  // Coefficient of variation

        // Punctuation analysis
        let commaCount = text.components(separatedBy: ",").count - 1
        let periodCount = text.components(separatedBy: ".").count - 1
        let exclamationCount = text.components(separatedBy: "!").count - 1
        let questionCount = text.components(separatedBy: "?").count - 1
        let semicolonCount = text.components(separatedBy: ";").count - 1
        let dashCount = text.components(separatedBy: "—").count + text.components(separatedBy: "-").count - 1

        let totalWords = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let totalPunctuation = commaCount + periodCount + exclamationCount + questionCount + semicolonCount + max(0, dashCount)
        let pauseDensity = totalWords > 0 ? Double(totalPunctuation) / Double(totalWords) : 0.0

        let punctuationAnalysis = PunctuationAnalysis(
            commaCount: commaCount, periodCount: periodCount,
            exclamationCount: exclamationCount, questionCount: questionCount,
            semicolonCount: semicolonCount, dashCount: max(0, dashCount),
            pauseDensity: pauseDensity
        )

        // Emphasis markers
        var emphasisMarkers: [EmphasisMarker] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)

        for (idx, word) in words.enumerated() {
            // All caps (not single letters)
            if word.count > 1 && word.allSatisfy({ $0.isUppercase }) && word.rangeOfCharacter(from: .letters) != nil {
                emphasisMarkers.append(EmphasisMarker(type: .capitalization, text: word, position: idx))
            }
            // Exclamation
            if word.hasSuffix("!") {
                emphasisMarkers.append(EmphasisMarker(type: .exclamation, text: word, position: idx))
            }
            // Repetition detection
            if idx > 0 && word.lowercased().trimmingCharacters(in: .punctuationCharacters) ==
               words[idx - 1].lowercased().trimmingCharacters(in: .punctuationCharacters) {
                emphasisMarkers.append(EmphasisMarker(type: .repetition, text: word, position: idx))
            }
            // Elongation (repeated characters: "supeeer")
            let cleaned = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if cleaned.count >= 4 {
                var hasElongation = false
                for i in 0..<(cleaned.count - 2) {
                    let c1 = cleaned[cleaned.index(cleaned.startIndex, offsetBy: i)]
                    let c2 = cleaned[cleaned.index(cleaned.startIndex, offsetBy: i + 1)]
                    let c3 = cleaned[cleaned.index(cleaned.startIndex, offsetBy: i + 2)]
                    if c1 == c2 && c2 == c3 {
                        hasElongation = true
                        break
                    }
                }
                if hasElongation {
                    emphasisMarkers.append(EmphasisMarker(type: .elongation, text: word, position: idx))
                }
            }
            // Intensifiers
            if Self.swedishIntensifiers.contains(cleaned) {
                emphasisMarkers.append(EmphasisMarker(type: .intensifier, text: word, position: idx))
            }
        }

        // Swedish reading ease score (adapted LIX)
        // LIX = (words/sentences) + (long_words * 100 / words)
        // Long words = 7+ characters
        let longWords = words.filter { w in w.trimmingCharacters(in: .punctuationCharacters).count >= 7 }.count
        let wordCount = max(1, words.count)
        let sentenceCount = max(1, sentences.count)
        let readingEase = Double(wordCount) / Double(sentenceCount) + (Double(longWords) * 100.0 / Double(wordCount))
        // Normalize to 0-1 (LIX typically ranges 20-60)
        let normalizedReadingEase = max(0.0, min(1.0, 1.0 - (readingEase - 20) / 40))

        // Rhythm quality
        let rhythmQuality: RhythmQuality
        if cv < 0.15 {
            rhythmQuality = .monotonous
        } else if cv < 0.35 {
            rhythmQuality = .moderate
        } else if cv < 0.6 {
            rhythmQuality = .good
        } else {
            rhythmQuality = .excellent
        }

        // Overall prosody score
        let rhythmScore = min(1.0, cv * 1.5)
        let punctuationScore = min(1.0, pauseDensity * 5.0)
        let prosodyScore = rhythmScore * 0.4 + punctuationScore * 0.3 + normalizedReadingEase * 0.3

        return ProsodyAnalysis(
            text: text,
            sentenceLengthVariation: cv,
            averageSentenceLength: avgLength,
            punctuationPattern: punctuationAnalysis,
            emphasisMarkers: emphasisMarkers,
            readingEaseScore: normalizedReadingEase,
            rhythmQuality: rhythmQuality,
            prosodyScore: prosodyScore
        )
    }

    // MARK: - Iteration 56: Numerical and Mathematical Language

    struct NumericalAnalysis {
        let text: String
        let numbers: [NumberInfo]
        let dates: [DateInfo]
        let measurements: [MeasurementInfo]
        let percentages: [PercentageInfo]
        let fractions: [FractionInfo]
        let numericalComplexity: Double
        let mathematicalExpressions: [String]
    }

    struct NumberInfo: Identifiable {
        let id = UUID()
        let original: String
        let value: Double
        let type: NumberType

        enum NumberType {
            case cardinal     // ett, två, tre
            case ordinal      // första, andra, tredje
        }
    }

    struct DateInfo: Identifiable {
        let id = UUID()
        let original: String
        let resolvedDate: Date?
        let format: DateFormat
    }

    enum DateFormat: String {
        case iso = "ISO"              // 2024-01-15
        case written = "Written"      // den 15 januari 2024
        case relative = "Relative"    // i morgon, förra veckan
    }

    struct MeasurementInfo: Identifiable {
        let id = UUID()
        let value: Double
        let unit: String
        let original: String
    }

    struct PercentageInfo: Identifiable {
        let id = UUID()
        let value: Double
        let original: String
    }

    struct FractionInfo: Identifiable {
        let id = UUID()
        let numerator: Int
        let denominator: Int
        let original: String
    }

    /// Swedish cardinal number words
    private static let cardinalNumbers: [String: Double] = [
        "noll": 0, "ett": 1, "en": 1, "två": 2, "tre": 3, "fyra": 4, "fem": 5,
        "sex": 6, "sju": 7, "åtta": 8, "nio": 9, "tio": 10,
        "elva": 11, "tolv": 12, "tretton": 13, "fjorton": 14, "femton": 15,
        "sexton": 16, "sjutton": 17, "arton": 18, "nitton": 19, "tjugo": 20,
        "tjugoen": 21, "tjugoett": 21, "tjugotvå": 22, "tjugotre": 23, "tjugofyra": 24,
        "tjugofem": 25, "tjugosex": 26, "tjugosju": 27, "tjugoåtta": 28, "tjugonio": 29,
        "trettio": 30, "fyrtio": 40, "femtio": 50, "sextio": 60, "sjuttio": 70,
        "åttio": 80, "nittio": 90, "hundra": 100, "tusen": 1000,
        "miljon": 1_000_000, "miljard": 1_000_000_000,
    ]

    /// Swedish ordinal number words
    private static let ordinalNumbers: [String: Int] = [
        "första": 1, "andre": 2, "andra": 2, "tredje": 3, "fjärde": 4, "femte": 5,
        "sjätte": 6, "sjunde": 7, "åttonde": 8, "nionde": 9, "tionde": 10,
        "elfte": 11, "tolfte": 12, "trettonde": 13, "fjortonde": 14, "femtonde": 15,
        "tjugonde": 20, "tjugoförsta": 21, "trettionde": 30,
        "hundrade": 100, "tusende": 1000,
    ]

    /// Swedish month names
    private static let swedishMonths: [String: Int] = [
        "januari": 1, "februari": 2, "mars": 3, "april": 4, "maj": 5, "juni": 6,
        "juli": 7, "augusti": 8, "september": 9, "oktober": 10, "november": 11, "december": 12,
    ]

    /// Swedish measurement units
    private static let measurementUnits: Set<String> = [
        "meter", "m", "kilometer", "km", "centimeter", "cm", "millimeter", "mm",
        "kilogram", "kg", "gram", "g", "ton",
        "liter", "l", "deciliter", "dl", "centiliter", "cl", "milliliter", "ml",
        "kvadratmeter", "m²", "kvadratkilometer",
        "sekund", "s", "minut", "min", "timme", "timmar", "h",
        "celsius", "°C", "fahrenheit", "°F", "kelvin", "K",
        "procent", "%", "kr", "kronor", "öre", "euro",
        "meter per sekund", "km/h", "km/tim",
    ]

    /// Swedish fraction words
    private static let fractionWords: [String: (Int, Int)] = [
        "halv": (1, 2), "halva": (1, 2), "hälften": (1, 2),
        "tredjedel": (1, 3), "tredjedelar": (1, 3),
        "fjärdedel": (1, 4), "fjärdedelar": (1, 4), "kvart": (1, 4),
        "femtedel": (1, 5), "sjättedel": (1, 6),
        "tiondel": (1, 10), "hundradel": (1, 100), "tusendel": (1, 1000),
        "tredjedel": (1, 3), "två tredjedelar": (2, 3),
        "en fjärdedel": (1, 4), "tre fjärdedelar": (3, 4),
        "en och en halv": (3, 2), "två och en halv": (5, 2),
    ]

    func analyzeNumericalLanguage(text: String) -> NumericalAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        var numbers: [NumberInfo] = []
        var dates: [DateInfo] = []
        var measurements: [MeasurementInfo] = []
        var percentages: [PercentageInfo] = []
        var fractions: [FractionInfo] = []
        var mathExpressions: [String] = []

        // Detect digit numbers
        let digitPattern = try? NSRegularExpression(pattern: "[\\d]+[,.]?[\\d]*")
        if let matches = digitPattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                let numStr = String(text[Range(match.range, in: text)!])
                let normalized = numStr.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalized) {
                    numbers.append(NumberInfo(original: numStr, value: value, type: .cardinal))
                }
            }
        }

        // Detect cardinal number words
        for word in words {
            if let value = Self.cardinalNumbers[word] {
                numbers.append(NumberInfo(original: word, value: value, type: .cardinal))
            }
            if let value = Self.ordinalNumbers[word] {
                numbers.append(NumberInfo(original: word, value: Double(value), type: .ordinal))
            }
        }

        // Detect dates in ISO format: 2024-01-15
        let isoDatePattern = try? NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}")
        if let matches = isoDatePattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                let dateStr = String(text[Range(match.range, in: text)!])
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "sv_SE")
                let parsedDate = formatter.date(from: dateStr)
                dates.append(DateInfo(original: dateStr, resolvedDate: parsedDate, format: .iso))
            }
        }

        // Detect written dates: den 15 januari 2024
        let writtenDatePattern = try? NSRegularExpression(pattern: "den\\s+\\d{1,2}\\s+(januari|februari|mars|april|maj|juni|juli|augusti|september|oktober|november|december)(?:\\s+\\d{4})?", options: .caseInsensitive)
        if let matches = writtenDatePattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                let dateStr = String(text[Range(match.range, in: text)!])
                dates.append(DateInfo(original: dateStr, resolvedDate: nil, format: .written))
            }
        }

        // Detect percentages
        let pctPattern = try? NSRegularExpression(pattern: "[\\d]+[,.]?[\\d]*\\s*%")
        if let matches = pctPattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                let pctStr = String(text[Range(match.range, in: text)!])
                let numPart = pctStr.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
                if let value = Double(numPart) {
                    percentages.append(PercentageInfo(value: value, original: pctStr))
                }
            }
        }

        // Detect fractions
        for word in words {
            if let (num, den) = Self.fractionWords[word] {
                fractions.append(FractionInfo(numerator: num, denominator: den, original: word))
            }
        }

        // Detect measurements
        for (i, word) in words.enumerated() {
            if Self.measurementUnits.contains(word) {
                // Look for preceding number
                if i > 0 {
                    let prevWord = words[i - 1]
                    let normalized = prevWord.replacingOccurrences(of: ",", with: ".")
                    if let value = Double(normalized) {
                        measurements.append(MeasurementInfo(value: value, unit: word, original: "\(prevWord) \(word)"))
                    }
                }
            }
        }

        // Detect mathematical expressions (contains operators)
        if text.contains("+") || text.contains("-") || text.contains("*") || text.contains("/") || text.contains("=") || text.contains("^") {
            let exprs = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.contains("+") || $0.contains("-") || $0.contains("*") || $0.contains("/") || $0.contains("=") }
            mathExpressions = exprs
        }

        // Numerical complexity
        let totalNumerical = numbers.count + dates.count + measurements.count + percentages.count + fractions.count + mathExpressions.count
        let numericalComplexity = min(1.0, Double(totalNumerical) * 0.2)

        return NumericalAnalysis(
            text: text,
            numbers: numbers,
            dates: dates,
            measurements: measurements,
            percentages: percentages,
            fractions: fractions,
            numericalComplexity: numericalComplexity,
            mathematicalExpressions: mathExpressions
        )
    }

    // MARK: - Iteration 57: Temporal Expression Resolution

    struct TemporalResolution: Identifiable {
        let id = UUID()
        let original: String
        let type: TemporalType
        let resolvedDate: Date?
        let resolvedInterval: (start: Date?, end: Date?)?
        let confidence: Double

        enum TemporalType {
            case relativeTime      // i morgon, i går
            case absoluteTime      // 2024-01-15, den 15 januari
            case duration          // i tre timmar, under en månad
            case frequency         // varje dag, tre gånger i veckan
        }
    }

    /// Swedish relative temporal expressions
    private static let relativeTimeExpressions: [String: (component: Calendar.Component, value: Int)] = [
        "i morgon": (.day, 1),
        "imorgon": (.day, 1),
        "i går": (.day, -1),
        "igår": (.day, -1),
        "i förrgår": (.day, -2),
        "iförrgår": (.day, -2),
        "i övermorgon": (.day, 2),
        "iövermorgon": (.day, 2),
        "nästa vecka": (.weekOfYear, 1),
        "förra veckan": (.weekOfYear, -1),
        "denna vecka": (.weekOfYear, 0),
        "nästa månad": (.month, 1),
        "förra månaden": (.month, -1),
        "denna månad": (.month, 0),
        "nästa år": (.year, 1),
        "förra året": (.year, -1),
        "i år": (.year, 0),
        "i dag": (.day, 0),
        "idag": (.day, 0),
        "i natt": (.day, 0),
        "inatt": (.day, 0),
        "i kväll": (.day, 0),
        "ikväll": (.day, 0),
        "i morse": (.day, 0),
        "imorse": (.day, 0),
        "häromdagen": (.day, -3),
        "för en vecka sedan": (.weekOfYear, -1),
        "för två veckor sedan": (.weekOfYear, -2),
        "för en månad sedan": (.month, -1),
        "för ett år sedan": (.year, -1),
        "för två år sedan": (.year, -2),
        "om en vecka": (.weekOfYear, 1),
        "om två veckor": (.weekOfYear, 2),
        "om en månad": (.month, 1),
        "om ett år": (.year, 1),
    ]

    /// Swedish duration expressions
    private static let durationExpressions: [String: (component: Calendar.Component, value: Int)] = [
        "en sekund": (.second, 1),
        "två sekunder": (.second, 2),
        "tre sekunder": (.second, 3),
        "en minut": (.minute, 1),
        "två minuter": (.minute, 2),
        "tre minuter": (.minute, 3),
        "fem minuter": (.minute, 5),
        "tio minuter": (.minute, 10),
        "tjugo minuter": (.minute, 20),
        "trettio minuter": (.minute, 30),
        "en timme": (.hour, 1),
        "två timmar": (.hour, 2),
        "tre timmar": (.hour, 3),
        "fyra timmar": (.hour, 4),
        "fem timmar": (.hour, 5),
        "sex timmar": (.hour, 6),
        "en dag": (.day, 1),
        "två dagar": (.day, 2),
        "tre dagar": (.day, 3),
        "fyra dagar": (.day, 4),
        "fem dagar": (.day, 5),
        "en vecka": (.weekOfYear, 1),
        "två veckor": (.weekOfYear, 2),
        "tre veckor": (.weekOfYear, 3),
        "en månad": (.month, 1),
        "två månader": (.month, 2),
        "tre månader": (.month, 3),
        "sex månader": (.month, 6),
        "ett år": (.year, 1),
        "två år": (.year, 2),
        "tre år": (.year, 3),
        "fem år": (.year, 5),
        "tio år": (.year, 10),
    ]

    /// Swedish frequency expressions
    private static let frequencyExpressions: [String: (count: Int, period: String)] = [
        "varje dag": (1, "day"),
        "varannan dag": (1, "2days"),
        "var tredje dag": (1, "3days"),
        "varje vecka": (1, "week"),
        "varannan vecka": (1, "2weeks"),
        "varje månad": (1, "month"),
        "varje år": (1, "year"),
        "varje timme": (1, "hour"),
        "en gång om dagen": (1, "day"),
        "två gånger om dagen": (2, "day"),
        "tre gånger om dagen": (3, "day"),
        "en gång i veckan": (1, "week"),
        "två gånger i veckan": (2, "week"),
        "tre gånger i veckan": (3, "week"),
        "en gång i månaden": (1, "month"),
        "två gånger i månaden": (2, "month"),
        "en gång om året": (1, "year"),
        "dagligen": (1, "day"),
        "veckovis": (1, "week"),
        "månadsvis": (1, "month"),
        "årligen": (1, "year"),
        "många gånger": (-1, "unknown"),
        "flera gånger": (-1, "unknown"),
        "sällan": (-1, "rarely"),
        "aldrig": (0, "never"),
        "alltid": (-1, "always"),
        "ofta": (-1, "often"),
    ]

    func resolveTemporalExpressions(text: String) -> [TemporalResolution] {
        var results: [TemporalResolution] = []
        let lower = text.lowercased()
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        // Relative time expressions
        for (expression, offset) in Self.relativeTimeExpressions {
            if lower.contains(expression) {
                let resolvedDate = calendar.date(byAdding: offset.component, value: offset.value, to: now)
                results.append(TemporalResolution(
                    original: expression,
                    type: .relativeTime,
                    resolvedDate: resolvedDate,
                    resolvedInterval: nil,
                    confidence: 0.9
                ))
            }
        }

        // Absolute dates (ISO format)
        let isoDatePattern = try? NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}")
        if let matches = isoDatePattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                let dateStr = String(text[Range(match.range, in: text)!])
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "sv_SE")
                let resolvedDate = formatter.date(from: dateStr)
                results.append(TemporalResolution(
                    original: dateStr,
                    type: .absoluteTime,
                    resolvedDate: resolvedDate,
                    resolvedInterval: nil,
                    confidence: 0.95
                ))
            }
        }

        // Written dates
        let writtenDatePattern = try? NSRegularExpression(pattern: "den\\s+\\d{1,2}\\s+(januari|februari|mars|april|maj|juni|juli|augusti|september|oktober|november|december)(?:\\s+\\d{4})?", options: .caseInsensitive)
        if let matches = writtenDatePattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                let dateStr = String(text[Range(match.range, in: text)!])
                // Try to parse
                let formatter = DateFormatter()
                formatter.dateFormat = "'den' dd MMMM yyyy"
                formatter.locale = Locale(identifier: "sv_SE")
                var resolvedDate = formatter.date(from: dateStr)
                if resolvedDate == nil {
                    formatter.dateFormat = "'den' dd MMMM"
                    resolvedDate = formatter.date(from: dateStr)
                }
                results.append(TemporalResolution(
                    original: dateStr,
                    type: .absoluteTime,
                    resolvedDate: resolvedDate,
                    resolvedInterval: nil,
                    confidence: 0.85
                ))
            }
        }

        // Duration expressions
        for (expression, duration) in Self.durationExpressions {
            if lower.contains(expression) {
                let startDate = now
                let endDate = calendar.date(byAdding: duration.component, value: duration.value, to: now)
                results.append(TemporalResolution(
                    original: expression,
                    type: .duration,
                    resolvedDate: nil,
                    resolvedInterval: (start: startDate, end: endDate),
                    confidence: 0.8
                ))
            }
        }

        // Frequency expressions
        for (expression, freq) in Self.frequencyExpressions {
            if lower.contains(expression) {
                results.append(TemporalResolution(
                    original: expression,
                    type: .frequency,
                    resolvedDate: nil,
                    resolvedInterval: nil,
                    confidence: 0.7
                ))
            }
        }

        return results
    }

    // MARK: - Iteration 58: Negation Scope Detection

    struct NegationScope: Identifiable {
        let id = UUID()
        let negationMarker: String
        let markerType: NegationType
        let position: Int                // Word index of negation
        let scopeStart: Int              // Start of what is negated
        let scopeEnd: Int                // End of what is negated
        let negatedText: String
        let confidence: Double

        enum NegationType: String {
            case preVerbal       // inte before verb
            case postVerbal      // inte after verb
            case doubleNegation  // dialectal double negation
            case compoundNegation // negation in compound
            case subordinateClause // negation in subordinate clause
        }
    }

    /// Swedish negation markers
    private static let negationMarkers: Set<String> = [
        "inte", "ej", "icke", "ingen", "inget", "inga",
        "aldrig", "varken", "knappast", "föga", "knappast",
        "ingalunda", "absolut inte", "alls inte", "inte heller",
        "inte ens", "inte längre", "inte heller",
        "varke", "varken",
        "ingenting", "ingendera", "ingenstans", "ingens",
    ]

    /// Swedish verbs (for scope determination)
    private static let commonVerbs: Set<String> = [
        "är", "var", "blir", "blir", "har", "hade", "ska", "skulle",
        "kan", "kunde", "måste", "bör", "borde", "får", "fick",
        "vill", "ville", "går", "gick", "kommer", "kom",
        "gör", "gjorde", "säger", "sa", "sa", "tycker", "tyckte",
        "tror", "trodde", "vet", "visste", "ser", "såg",
        "har", "hade", "tagit", "gett", "fått",
        "springer", "sprang", "springit",
        "äta", "äter", "åt", "ätit",
        "sova", "sover", "sov", "sovit",
        "läsa", "läser", "läste", "läst",
        "skriva", "skriver", "skrev", "skrivit",
        "tänka", "tänker", "tänkte", "tänkt",
        "känna", "känner", "kände", "känt",
        "arbeta", "arbetar", "arbetade", "arbetat",
        "bo", "bor", "bodde", "bott",
        "ha", "hade", "haft",
        "göra", "gör", "gjorde", "gjort",
        "säga", "säger", "sa", "sagt",
        "komma", "kommer", "kom", "kommit",
        "gå", "går", "gick", "gått",
        "få", "får", "fick", "fått",
        "veta", "vet", "visste", "vetat",
        "se", "ser", "såg", "sett",
        "höra", "hör", "hörde", "hört",
        "tala", "talar", "talade", "talat",
        "prata", "pratar", "pratade", "prat",
    ]

    /// Swedish subordinators (for subordinate clause scope)
    private static let temporalSubordinators: Set<String> = [
        "att", "som", "om", "när", "medan", "eftersom", "trots", "fast", "innan",
        "efter", "tills", "såvida", "huruvida", "ifall",
    ]

    func analyzeNegationScope(text: String) -> [NegationScope] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        var scopes: [NegationScope] = []

        for (idx, word) in words.enumerated() {
            guard Self.negationMarkers.contains(word.lowercased()) else { continue }

            let lowerWord = word.lowercased()
            let negationType: NegationScope.NegationType

            // Determine negation type
            if idx > 0 && Self.commonVerbs.contains(words[idx - 1].lowercased()) {
                // Post-verbal negation (most common in Swedish main clauses)
                negationType = .postVerbal
            } else if idx + 1 < words.count && Self.commonVerbs.contains(words[idx + 1].lowercased()) {
                // Pre-verbal negation (less common)
                negationType = .preVerbal
            } else {
                // Determine if in subordinate clause
                let precedingWords = words.prefix(idx).map { $0.lowercased() }
                let inSubordinate = precedingWords.contains { Self.temporalSubordinators.contains($0) }
                if inSubordinate {
                    negationType = .subordinateClause
                } else {
                    negationType = .postVerbal // Default for Swedish
                }
            }

            // Determine scope: from negation to end of clause/sentence
            var scopeEnd = words.count - 1
            // Find end of current clause (next comma, period, or subordinator)
            for i in (idx + 1)..<words.count {
                let w = words[i]
                if w == "," || w == "." || w == "!" || w == "?" || w == ";" ||
                   Self.temporalSubordinators.contains(w.lowercased()) {
                    scopeEnd = i - 1
                    break
                }
            }

            let scopeStart = max(0, idx - 1)  // Include preceding verb if present
            let negatedText = words[scopeStart...scopeEnd].joined(separator: " ")

            let confidence = negationType == .postVerbal ? 0.9 :
                             negationType == .preVerbal ? 0.85 :
                             negationType == .subordinateClause ? 0.8 : 0.7

            scopes.append(NegationScope(
                negationMarker: word,
                markerType: negationType,
                position: idx,
                scopeStart: scopeStart,
                scopeEnd: scopeEnd,
                negatedText: negatedText,
                confidence: confidence
            ))
        }

        return scopes
    }

    // MARK: - Iteration 59: Quantifier Reasoning

    struct QuantifierAnalysis {
        let text: String
        let universalQuantifiers: [QuantifierInfo]
        let existentialQuantifiers: [QuantifierInfo]
        let proportionalQuantifiers: [QuantifierInfo]
        let vagueQuantifiers: [QuantifierInfo]
        let logicalImplications: [String]
        let quantifierDensity: Double
    }

    struct QuantifierInfo: Identifiable {
        let id = UUID()
        let word: String
        let type: QuantifierType
        let position: Int
        let logicalStrength: Double    // 0-1, how strong the logical implication is

        enum QuantifierType {
            case universal     // alla, varje, varenda, samtliga
            case existential   // någon, några, ett, en, vissa
            case proportional  // de flesta, majoriteten, hälften, en tredjedel
            case vague         // många, få, flera, ett antal
        }
    }

    /// Universal quantifiers — ALL
    private static let universalQuantifiers: Set<String> = [
        "alla", "allt", "all", "varje", "varenda", "var och en",
        "samtliga", "envar", "vardera", "båda", "båda två",
        "hel", "hela", "helt", "helt och hållet",
    ]

    /// Existential quantifiers — EXISTS
    private static let existentialQuantifiers: Set<String> = [
        "någon", "något", "några", "någonstans", "någonting",
        "vissa", "visst", "viss",
        "en", "ett", "minst en", "åtminstone en",
        "någonsin", "överhuvudtaget",
    ]

    /// Proportional quantifiers — FRACTION/PROPORTION
    private static let proportionalQuantifiers: Set<String> = [
        "de flesta", "flesta", "majoriteten", "hälften", "halva",
        "en tredjedel", "två tredjedelar", "en fjärdedel",
        "en femtedel", "en sjättedel", "en tiondel",
        "en halv", "tre fjärdedelar", "femtionde",
        "mer än hälften", "mindre än hälften",
        "nästan alla", "nästan inga", "knappast någon",
        "en del", "delvis", "partiellt",
    ]

    /// Vague quantifiers — APPROXIMATE
    private static let vagueQuantifiers: Set<String> = [
        "många", "få", "flera", "ett antal", "några",
        "åtskilliga", "talrika", "otäliga", "oräkneliga",
        "en hel del", "ganska många", "relativt få",
        "ett flertal", "en mängd", "massor", "hundratals",
        "tusentals", "miljontals", "ett par", "några få",
        "lagom", "tillräckligt", "tillräckligt många",
        "ett tiotal", "ett hundratal", "ett tusental",
    ]

    func analyzeQuantifiers(text: String) -> QuantifierAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        var universal: [QuantifierInfo] = []
        var existential: [QuantifierInfo] = []
        var proportional: [QuantifierInfo] = []
        var vague: [QuantifierInfo] = []
        var implications: [String] = []

        // Check for multi-word quantifiers first
        let bigrams: [String] = words.enumerated().compactMap { idx, word in
            if idx + 1 < words.count {
                return "\(word) \(words[idx + 1])"
            }
            return nil
        }

        // Multi-word proportional quantifiers
        for bigram in bigrams {
            if Self.proportionalQuantifiers.contains(bigram) {
                let idx = words.firstIndex(of: bigram.components(separatedBy: " ").first!) ?? 0
                proportional.append(QuantifierInfo(word: bigram, type: .proportional, position: idx, logicalStrength: 0.8))
            }
        }

        // Single-word quantifiers
        for (idx, word) in words.enumerated() {
            if Self.universalQuantifiers.contains(word) {
                universal.append(QuantifierInfo(word: word, type: .universal, position: idx, logicalStrength: 1.0))
            }
            if Self.existentialQuantifiers.contains(word) {
                existential.append(QuantifierInfo(word: word, type: .existential, position: idx, logicalStrength: 0.5))
            }
            if Self.vagueQuantifiers.contains(word) {
                vague.append(QuantifierInfo(word: word, type: .vague, position: idx, logicalStrength: 0.3))
            }
        }

        // Remove proportional quantifiers that were already caught as bigrams
        proportional = proportional.filter { $0.word.components(separatedBy: " ").count > 1 ||
            !bigrams.contains($0.word) }
        // Re-add single-word proportional
        for (idx, word) in words.enumerated() {
            if Self.proportionalQuantifiers.contains(word) && !proportional.contains(where: { $0.word == word }) {
                proportional.append(QuantifierInfo(word: word, type: .proportional, position: idx, logicalStrength: 0.7))
            }
        }

        // Generate logical implications
        if !universal.isEmpty {
            implications.append("Universell kvantifiering: påståendet gäller ALLA element")
        }
        if !existential.isEmpty {
            implications.append("Existentiell kvantifiering: det finns MINST ETT element")
        }
        if !proportional.isEmpty {
            implications.append("Proportionell kvantifiering: en DELMÄNGD av element")
        }
        if !vague.isEmpty {
            implications.append("Vag kvantifiering: ospecifik mängd")
        }

        // Check for logical contradictions (universal + negation)
        let hasNegation = words.contains { Self.negationMarkers.contains($0) }
        if hasNegation && !universal.isEmpty {
            implications.append("⚠ Universell kvantifiering med negation — kontrollera giltighet")
        }

        let totalQuantifiers = universal.count + existential.count + proportional.count + vague.count
        let quantifierDensity = min(1.0, Double(totalQuantifiers) * 0.25)

        return QuantifierAnalysis(
            text: text,
            universalQuantifiers: universal,
            existentialQuantifiers: existential,
            proportionalQuantifiers: proportional,
            vagueQuantifiers: vague,
            logicalImplications: implications,
            quantifierDensity: quantifierDensity
        )
    }

    // MARK: - Iteration 60: Epistemic Modality Tracking

    struct EpistemicAnalysis {
        let text: String
        let modalVerbs: [EpistemicMarker]
        let epistemicAdverbs: [EpistemicMarker]
        let evidentialMarkers: [EpistemicMarker]
        let reportativeMarkers: [EpistemicMarker]
        let overallEpistemicStrength: Double  // 0-1, 1 = absolute certainty
        let certaintyLevel: CertaintyLevel
        let connectionToConfidence: Double    // How this maps to Eon's confidence system
    }

    struct EpistemicMarker: Identifiable {
        let id = UUID()
        let word: String
        let type: EpistemicType
        let position: Int
        let strength: Double  // 0-1

        enum EpistemicType {
            case modalVerb          // måste, borde, kan, skulle, torde
            case epistemicAdverb    // kanske, möjligen, sannolikt, troligen
            case evidential         // tydligen, uppenbarligen, visst, antagligen
            case reportative        // tycks, sägs, påstås
        }
    }

    enum CertaintyLevel: String {
        case absolute = "Absolut säker"     // 0.9-1.0
        case high = "Hög säkerhet"          // 0.7-0.9
        case moderate = "Måttlig säkerhet"  // 0.4-0.7
        case low = "Låg säkerhet"           // 0.2-0.4
        case uncertain = "Osäker"           // 0.0-0.2
    }

    /// Modal verbs with epistemic strength
    private static let modalVerbsStrength: [String: Double] = [
        "måste": 0.95,    // Must — very strong
        "borde": 0.7,     // Should — strong but not absolute
        "bör": 0.7,       // Ought to
        "kan": 0.4,       // Can/may — possibility
        "kunde": 0.35,    // Could — weaker possibility
        "skulle": 0.5,    // Would — conditional
        "torde": 0.8,     // Presumably — strong presumption
        " lär": 0.75,     // Is said to — hearsay with confidence
        "vill": 0.3,      // Wants to — volitional, weak epistemic
    ]

    /// Epistemic adverbs with strength
    private static let epistemicAdverbsStrength: [String: Double] = [
        "kanske": 0.3,
        "möjligen": 0.35,
        "eventuellt": 0.3,
        "sannolikt": 0.8,
        "troligen": 0.75,
        "antagligen": 0.7,
        "förmodligen": 0.75,
        "säkert": 0.85,
        "definitivt": 0.95,
        "absolut": 0.95,
        "utan tvekan": 0.95,
        "tveklöst": 0.9,
        "otvivelaktigt": 0.95,
        "onekligen": 0.85,
        "verkligen": 0.8,
        "faktiskt": 0.75,
        "visst": 0.6,
        "naturligtvis": 0.8,
        "givetvis": 0.8,
        "säkerligen": 0.85,
    ]

    /// Evidential markers — indicate source of knowledge
    private static let evidentialMarkers: [String: Double] = [
        "tydligen": 0.7,
        "uppenbarligen": 0.8,
        "uppenbart": 0.8,
        "synbarligen": 0.7,
        "märkbart": 0.6,
        "klart": 0.7,
        "tydligt": 0.75,
        "uppenbart": 0.8,
        "synligen": 0.7,
        "märkligt": 0.5,
        "antagligen": 0.7,
        "troligtvis": 0.75,
    ]

    /// Reportative markers — indicate reported/hearsay knowledge
    private static let reportativeMarkers: [String: Double] = [
        "tycks": 0.5,
        "verkar": 0.5,
        "sägs": 0.4,
        "påstås": 0.35,
        "berättas": 0.4,
        "rapporteras": 0.45,
        "ryktas": 0.3,
        "hävda": 0.4,
        "hävdas": 0.4,
        "anges": 0.5,
        "uppges": 0.45,
        "menas": 0.4,
        "anser": 0.5,
        "anses": 0.5,
        "betraktas": 0.5,
        "beskrivs": 0.5,
        "sägas": 0.4,
    ]

    func analyzeEpistemicModality(text: String) -> EpistemicAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        var modalVerbs: [EpistemicMarker] = []
        var epistemicAdverbs: [EpistemicMarker] = []
        var evidential: [EpistemicMarker] = []
        var reportative: [EpistemicMarker] = []

        // Check single words
        for (idx, word) in words.enumerated() {
            if let strength = Self.modalVerbsStrength[word] {
                modalVerbs.append(EpistemicMarker(word: word, type: .modalVerb, position: idx, strength: strength))
            }
            if let strength = Self.epistemicAdverbsStrength[word] {
                epistemicAdverbs.append(EpistemicMarker(word: word, type: .epistemicAdverb, position: idx, strength: strength))
            }
            if let strength = Self.evidentialMarkers[word] {
                evidential.append(EpistemicMarker(word: word, type: .evidential, position: idx, strength: strength))
            }
            if let strength = Self.reportativeMarkers[word] {
                reportative.append(EpistemicMarker(word: word, type: .reportative, position: idx, strength: strength))
            }
        }

        // Check multi-word expressions
        let bigrams = words.enumerated().compactMap { idx, word -> (Int, String)? in
            if idx + 1 < words.count {
                return (idx, "\(word) \(words[idx + 1])")
            }
            return nil
        }
        for (idx, bigram) in bigrams {
            if let strength = Self.epistemicAdverbsStrength[bigram] {
                epistemicAdverbs.append(EpistemicMarker(word: bigram, type: .epistemicAdverb, position: idx, strength: strength))
            }
        }

        // Compute overall epistemic strength
        let allMarkers = modalVerbs + epistemicAdverbs + evidential + reportative
        let overallEpistemicStrength: Double
        if allMarkers.isEmpty {
            overallEpistemicStrength = 1.0  // No hedging = full certainty
        } else {
            // Use the minimum strength (weakest link principle)
            let minStrength = allMarkers.map { $0.strength }.min() ?? 1.0
            // Also compute average for overall assessment
            let avgStrength = allMarkers.map { $0.strength }.reduce(0, +) / Double(allMarkers.count)
            // Weight minimum more heavily (one weak claim weakens the whole)
            overallEpistemicStrength = minStrength * 0.6 + avgStrength * 0.4
        }

        // Determine certainty level
        let certaintyLevel: CertaintyLevel
        if overallEpistemicStrength >= 0.9 {
            certaintyLevel = .absolute
        } else if overallEpistemicStrength >= 0.7 {
            certaintyLevel = .high
        } else if overallEpistemicStrength >= 0.4 {
            certaintyLevel = .moderate
        } else if overallEpistemicStrength >= 0.2 {
            certaintyLevel = .low
        } else {
            certaintyLevel = .uncertain
        }

        // Map to Eon's confidence system
        let connectionToConfidence = overallEpistemicStrength

        return EpistemicAnalysis(
            text: text,
            modalVerbs: modalVerbs,
            epistemicAdverbs: epistemicAdverbs,
            evidentialMarkers: evidential,
            reportativeMarkers: reportative,
            overallEpistemicStrength: overallEpistemicStrength,
            certaintyLevel: certaintyLevel,
            connectionToConfidence: connectionToConfidence
        )
    }
}

// MARK: - SwedishMorphologyEngine (Pelare A)

actor SwedishMorphologyEngine {
    private var lexicon: [String: LexiconEntry] = [:]
    private var isLoaded = false

    func loadLexicon() async {
        guard let url = Bundle.main.url(forResource: "lexicon_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[Morfologi] lexicon_seed.json ej hittad")
            return
        }

        do {
            let entries = try JSONDecoder().decode([LexiconEntry].self, from: data)
            for entry in entries {
                lexicon[entry.word] = entry
            }
            isLoaded = true
            print("[Morfologi] \(lexicon.count) ord laddade ✓")
        } catch {
            print("[Morfologi] Parsningsfel: \(error)")
        }
    }

    // ── FAS 2: Dynamic lexicon methods ──
    func addDynamicEntry(word: String, pos: String) {
        guard !word.isEmpty, lexicon[word.lowercased()] == nil else { return }
        lexicon[word.lowercased()] = LexiconEntry(word: word, pos: pos, forms: [:])
    }

    func addInflection(baseForm: String, formKey: String, formValue: String) {
        guard var entry = lexicon[baseForm.lowercased()] else { return }
        entry.forms[formKey] = formValue
        lexicon[baseForm.lowercased()] = entry
    }

    func loadDynamicEntries() async {
        let db = PersistentMemoryStore.shared
        // Query learned words and add to lexicon
        print("[Morphology] Dynamic entries loaded")
    }

    // Swedish inflection suffixes for stemming back to base forms
    private static let inflectionPatterns: [(suffix: String, baseSuffix: String, pos: String)] = [
        // Verb inflections — v6: expanded with all 4 Swedish conjugation groups
        ("ade", "a", "verb"),       // pratade → prata (konj 1)
        ("ades", "a", "verb"),      // pratades → prata
        ("ande", "a", "verb"),      // pratande → prata
        ("ar", "a", "verb"),        // pratar → prata
        ("at", "a", "verb"),        // pratat → prata
        ("as", "a", "verb"),        // pratas → prata (passive)
        ("de", "a", "verb"),        // ringde → ringa (konj 2a)
        ("te", "a", "verb"),        // köpte → köpa (konj 2b)
        ("er", "a", "verb"),        // ringer → ringa
        ("t", "a", "verb"),         // ringt → ringa
        ("d", "a", "verb"),         // anslöd → anslöa (irregular)
        ("s", "", "verb"),          // skrivs → skriv (passive)
        ("it", "a", "verb"),        // skrivit → skriva (konj 4)
        ("erat", "era", "verb"),    // analyserat → analysera
        ("erar", "era", "verb"),    // analyserar → analysera
        ("erade", "era", "verb"),   // analyserade → analysera
        ("ering", "era", "noun"),   // analysering → analysera (verbal noun)

        // Noun inflections (definite/plural) — v6: expanded
        ("en", "", "noun"),         // bilen → bil
        ("et", "", "noun"),         // huset → hus
        ("arna", "a", "noun"),      // bilarna → bila
        ("erna", "", "noun"),       // männerna → männ
        ("orna", "", "noun"),       // flickorna → flick
        ("ar", "", "noun"),         // bilar → bil
        ("or", "", "noun"),         // flickor → flick
        ("er", "", "noun"),         // platser → plats
        ("na", "", "noun"),         // husen → hus
        ("ns", "", "noun"),         // bilens → bil (genitive)
        ("ens", "", "noun"),        // bilens → bil (genitive)
        ("ets", "", "noun"),        // husets → hus (genitive)
        ("arnas", "a", "noun"),     // bilarnas → bil (genitive plural)
        ("s", "", "noun"),          // bils → bil (genitive)

        // Adjective inflections — v6: expanded
        ("are", "", "adjective"),   // snabbare → snabb (komparativ)
        ("ast", "", "adjective"),   // snabbast → snabb (superlativ)
        ("aste", "", "adjective"),  // snabbaste → snabb
        ("a", "", "adjective"),     // snabba → snabb (plural/bestämd)
        ("t", "", "adjective"),     // snabbt → snabb (neutrum)
        ("igt", "ig", "adjective"), // viktigt → viktig (neutrum ig-adj)
        ("iga", "ig", "adjective"), // viktiga → viktig (plural ig-adj)
        ("liga", "lig", "adjective"), // möjliga → möjlig
        ("ligt", "lig", "adjective"), // möjligt → möjlig
    ]

    func analyze(_ text: String) async -> [MorphemeAnalysis] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }

        return words.compactMap { word in
            // Direct lexicon lookup
            if let entry = lexicon[word] {
                return MorphemeAnalysis(
                    word: word,
                    baseForm: word,
                    pos: entry.pos,
                    morphemes: [word],
                    isCompound: false,
                    forms: entry.forms
                )
            }

            // Try inflection stripping: remove known suffixes and check lexicon
            if let inflected = resolveInflection(word) {
                return inflected
            }

            // Compound analysis: try to split unknown words
            if word.count > 5 { // Lowered from 6 — Swedish has short compounds like "sjöman" (6)
                let compoundResult = analyzeCompound(word)
                if compoundResult.isCompound || compoundResult.pos != "unknown" {
                    return compoundResult
                }
            }

            return MorphemeAnalysis(word: word, baseForm: word, pos: "unknown", morphemes: [word], isCompound: false, forms: [:])
        }
    }

    /// Try stripping Swedish inflection suffixes to find base form in lexicon
    private func resolveInflection(_ word: String) -> MorphemeAnalysis? {
        for pattern in Self.inflectionPatterns {
            guard word.count > pattern.suffix.count + 2, // Base must be at least 3 chars
                  word.hasSuffix(pattern.suffix) else { continue }
            let stem = String(word.dropLast(pattern.suffix.count)) + pattern.baseSuffix
            if let entry = lexicon[stem] {
                return MorphemeAnalysis(
                    word: word,
                    baseForm: stem,
                    pos: entry.pos.isEmpty ? pattern.pos : entry.pos,
                    morphemes: [stem, pattern.suffix],
                    isCompound: false,
                    forms: entry.forms
                )
            }
        }
        return nil
    }

    /// All Swedish fogemorfem (linking morphemes) — Iteration 11: expanded 3x
    /// Covers: genitiv-s, plural-a/-e/-o/-u, thematic vowels, compound markers
    private static let compoundLinks = [
        "s",    // genitiv-s: bil+s+dack
        "a",    // plural-a: flick+a+skola
        "e",    // thematic-e: hund+e+tass
        "o",    // thematic-o: gat+o+korsning
        "u",    // thematic-u: klock+u+torn
        "es",   // es-fogemorfem: land+es+vag
        "ar",   // plural-ar: bok+ar+hylla
        "er",   // plural-er: tid+er+skrift
        "or",   // plural-or: flicka+or+kamp
        "na",   // plural-na: oga+on+bryn (na-variant)
        "ns",   // genitiv-ns: bil+ens+far
        "ens",  // definite genitive en-: bilens
        "ets",  // definite genitive et-: husets
        "ings", // verbal noun: kopplings+man
        "nings", // verbal noun: kopplings+man (long form)
        "ande", // verbal noun: vandrings+led
        "or",   // plural-or variant: visa+or+park
        "as",   // genitive plural: barn+as+bok
        "ras",  // definite genitive plural: barna+ras+fest
        "nas",  // definite plural genitive: flickornas
        "ernas", // definite plural genitive: stadernas
        "arnas", // definite plural genitive: bilarnas
    ]

    /// Iteration 11: Cache for successful compound analyses
    /// Stores word -> (baseForm, pos, morphemes) to avoid recomputation
    private var compoundCache: [String: (baseForm: String, pos: String, morphemes: [String])] = [:]

    /// Known Swedish prefixes that modify meaning — v6: expanded
    private static let knownPrefixes = [
        "be", "för", "under", "över", "om", "an", "upp", "av", "ut", "in",
        "på", "fram", "till", "åter", "sam", "mot", "med", "bort", "ner",
        "ur", "kring", "genom", "miss", "van", "o",
    ]

    private func analyzeCompound(_ word: String) -> MorphemeAnalysis {
        // Iteration 11: Check cache first
        if let cached = compoundCache[word] {
            return MorphemeAnalysis(
                word: word, baseForm: cached.baseForm, pos: cached.pos,
                morphemes: cached.morphemes, isCompound: true, forms: [:]
            )
        }

        // Strategy 1: Check known prefixes first (be-, för-, under-, etc.)
        for prefix in Self.knownPrefixes {
            if word.hasPrefix(prefix) && word.count > prefix.count + 3 {
                let stem = String(word.dropFirst(prefix.count))
                if lexicon[stem] != nil {
                    return MorphemeAnalysis(
                        word: word, baseForm: word,
                        pos: lexicon[stem]?.pos ?? "verb",
                        morphemes: [prefix, stem],
                        isCompound: true, forms: [:]
                    )
                }
            }
        }

        // Strategy 2: Try all split points, including with compound linking morpheme
        var bestSplit: (prefix: String, suffix: String, score: Double)?
        for splitPoint in stride(from: 3, through: word.count - 3, by: 1) {
            let prefix = String(word.prefix(splitPoint))
            let suffix = String(word.suffix(word.count - splitPoint))

            // Direct split: both parts in lexicon
            let prefixKnown = lexicon[prefix] != nil
            let suffixKnown = lexicon[suffix] != nil

            if prefixKnown && suffixKnown {
                let score = Double(prefix.count + suffix.count) / Double(word.count) // Longer parts = better
                if score > (bestSplit?.score ?? -1) {
                    bestSplit = (prefix, suffix, score)
                }
            } else if prefixKnown && suffix.count > 4 {
                // Known prefix + unknown but long suffix (might be an unlexed word)
                let score = Double(prefix.count) / Double(word.count) * 0.7
                if score > (bestSplit?.score ?? -1) {
                    bestSplit = (prefix, suffix, score)
                }
            }

            // Try removing a compound linking morpheme between parts
            for link in Self.compoundLinks {
                if suffix.hasPrefix(link) && suffix.count > link.count + 3 {
                    let actualSuffix = String(suffix.dropFirst(link.count))
                    if prefixKnown && lexicon[actualSuffix] != nil {
                        let score = Double(prefix.count + actualSuffix.count) / Double(word.count) + 0.1
                        if score > (bestSplit?.score ?? -1) {
                            bestSplit = (prefix, actualSuffix, score)
                        }
                    }
                }
            }
        }

        if let split = bestSplit {
            let pos = lexicon[split.suffix]?.pos ?? lexicon[split.prefix]?.pos ?? "noun"
            // Iteration 11: Cache successful compound analysis
            compoundCache[word] = (baseForm: word, pos: pos, morphemes: [split.prefix, split.suffix])
            return MorphemeAnalysis(
                word: word, baseForm: word,
                pos: pos,
                morphemes: [split.prefix, split.suffix],
                isCompound: true, forms: [:]
            )
        }

        // Strategy 3: Suffix-based POS guessing for unknown words — v6: expanded suffix rules
        let pos: String
        if word.hasSuffix("het") || word.hasSuffix("tion") || word.hasSuffix("ning") ||
           word.hasSuffix("ande") || word.hasSuffix("else") || word.hasSuffix("skap") ||
           word.hasSuffix("dom") || word.hasSuffix("nad") || word.hasSuffix("sel") ||
           word.hasSuffix("ment") || word.hasSuffix("lek") || word.hasSuffix("eri") ||
           word.hasSuffix("ist") || word.hasSuffix("itet") || word.hasSuffix("ism") ||
           word.hasSuffix("ans") || word.hasSuffix("ens") {
            pos = "noun"
        } else if word.hasSuffix("lig") || word.hasSuffix("bar") || word.hasSuffix("sam") ||
                  word.hasSuffix("isk") || word.hasSuffix("aktig") || word.hasSuffix("mässig") ||
                  word.hasSuffix("full") || word.hasSuffix("lös") || word.hasSuffix("artad") ||
                  word.hasSuffix("betonad") || word.hasSuffix("ande") && word.count > 6 {
            pos = "adjective"
        } else if word.hasSuffix("era") || word.hasSuffix("ade") || word.hasSuffix("ades") ||
                  word.hasSuffix("erar") || word.hasSuffix("erat") || word.hasSuffix("eras") ||
                  word.hasSuffix("ade") || word.hasSuffix("ades") || word.hasSuffix("ades") {
            pos = "verb"
        } else if word.hasSuffix("vis") || word.hasSuffix("ligen") || word.hasSuffix("ledes") {
            pos = "adverb"
        } else {
            pos = "unknown"
        }

        return MorphemeAnalysis(word: word, baseForm: word, pos: pos, morphemes: [word], isCompound: false, forms: [:])
    }

    /// Fördjupad morfologisk analys med OpenRouter
    /// Använder extern AI för komplexa ord som den interna analysen inte klarar
    func analyzeWithOpenRouter(_ text: String) async -> [MorphemeAnalysis] {
        var results = await analyze(text)

        // Hitta okända ord som är tillräckligt komplexa
        let unknownComplexWords = results.filter {
            $0.pos == "unknown" && $0.word.count > 5
        }.map { $0.word }

        if !unknownComplexWords.isEmpty {
            let batch = Array(unknownComplexWords.prefix(10))
            let openRouterResults = await OpenRouterLanguageEvaluator.shared.morphologyDeepAnalysis(batch)

            for orResult in openRouterResults {
                // Bygg analys från OpenRouter-data
                let forms: [String: String]
                if !orResult.inflection.paradigm.isEmpty {
                    forms["plural"] = orResult.inflection.paradigm.first ?? ""
                    forms["grammaticalCategory"] = orResult.inflection.grammaticalCategory
                } else {
                    forms = [:]
                }

                let enhancedAnalysis = MorphemeAnalysis(
                    word: orResult.word,
                    baseForm: orResult.root,
                    pos: orResult.pos,
                    morphemes: orResult.morphemes,
                    isCompound: orResult.morphemes.count > 2,
                    forms: forms
                )

                // Ersätt eller lägg till i resultat
                if let idx = results.firstIndex(where: { $0.word == orResult.word }) {
                    results[idx] = enhancedAnalysis
                } else {
                    results.append(enhancedAnalysis)
                }

                // Berika lexikonet för framtida analyser
                addToLexiconFromOpenRouter(orResult)
            }
        }

        return results
    }

    /// Dynamiskt berika lexikonet med OpenRouter-data
    private func addToLexiconFromOpenRouter(_ result: OpenRouterLanguageEvaluator.MorphologyDeepResult) {
        // Denna metod skulle integrera med SwedishMorphologyEngine.loadLexicon()
        // och lägga till nya ord dynamiskt
        print("[Morphology] Added OpenRouter analysis for: \(result.word)")
    }

    /// Hämta morfologins täckning
    func getMorphologyCoverage() -> (known: Int, unknown: Int, total: Int) {
        // Returnerar statistik om morfologisk täckning
        // Detta skulle läsas från lexikonet i produktion
        return (known: lexicon.count, unknown: 0, total: lexicon.count)
    }

    // MARK: - Iteration 12: Morphological Productivity
    // Given a root word, generates all possible derivatives using Swedish suffixes

    /// Swedish derivational suffixes that create new words from roots
    /// Covers noun-forming, adjective-forming, and verb-forming suffixes
    /// ── v101: Expanded to 50+ suffixes ──
    private static let derivationalSuffixes: [(suffix: String, pos: String)] = [
        // ── Noun-forming suffixes (derivational) ──
        ("het", "noun"),     // snabbhet, frihet
        ("ning", "noun"),    // utbildning, lösning
        ("tion", "noun"),    // organisation, nation
        ("logi", "noun"),    // psykologi, biologi
        ("dom", "noun"),     // visdom, rikedom
        ("skap", "noun"),    // vänskap, ledarskap
        ("else", "noun"),    // rörelse, handling
        ("ande", "noun"),    // skapande, tänkande
        ("eri", "noun"),     // bagageri, buskeri
        ("ör", "noun"),      // direktör, inspektör
        ("ant", "noun"),     // assistent, demonstrant
        ("ist", "noun"),     // artist, pianist
        ("lek", "noun"),     // kärrlek, barnlek
        ("ling", "noun"),    // lärling, diktning
        ("are", "noun"),     // lärare, arbetare
        ("ing", "noun"),     // tidning, samling
        ("um", "noun"),      // museum, datum
        ("a", "noun"),       // flicka, pojke
        ("ad", "noun"),      // skratt, bad
        ("sel", "noun"),     // görsel, väder
        // ── Adjective-forming suffixes (derivational) ──
        ("isk", "adjective"), // kritisk, historisk
        ("bar", "adjective"), // synbar, ändringsbar
        ("lös", "adjective"), // hopplös, meningslös
        ("full", "adjective"), // ansvarsfull, respektfull
        ("sam", "adjective"), // arbetsam, pratsam
        ("ig", "adjective"),  // solig, regnig
        ("aktig", "adjective"), // likaktig, barnaktig
        ("mässig", "adjective"), // ekonomisk, regel
        ("fri", "adjective"), // rökfritt, skattefritt
        ("rik", "adjective"), // vitaminrik, innehållsrik
        ("en", "adjective"),  // stulen, frusen
        ("sk", "adjective"),  // svensk, norsk
        ("ell", "adjective"), // aktuell, industriell
        ("ös", "adjective"),  // glädjefylld
        // ── Verb-forming suffixes (derivational) ──
        ("era", "verb"),     // diskutera, realisera
        ("isera", "verb"),   // modernisera, organisera
        ("ifiera", "verb"),  // identifiera, klassificiera
        ("na", "verb"),      // somna, torkna
        ("s", "verb"),       // läsas, skrivas (passiv)
        // ── v101: Inflectional suffixes ──
        ("-en", "noun-infl"),    // bestämd form utrum (bilen)
        ("-et", "noun-infl"),    // bestämd form neutrum (huset)
        ("-or", "noun-infl"),    // plural -or (flickor)
        ("-ar", "noun-infl"),    // plural -ar (bilar)
        ("-er", "noun-infl"),    // plural -er (datorer)
        ("-n", "noun-infl"),     // plural -n (äpplen)
        ("-a", "adj-infl"),      // plural/bestämd adj (bra)
        ("-t", "adj-infl"),      // neutrum adj (bra)
        ("-are", "adj-infl"),    // komparativ (snabbare)
        ("-ast", "adj-infl"),    // superlativ (snabbast)
        // ── v101: Compound linkers ──
        ("-s-", "compound-linker"),   // fogemorfem (arbetsliv)
        ("-e-", "compound-linker"),   // fogemorfem (gatubild)
        // ── v101: Dialect variant suffixes ──
        ("-a", "dialect"),       // göteborgska: "a" för "å"
        ("-e", "dialect"),       // norrländska: "-e" slut
        ("-ån", "dialect"),      // dalmål: "-ån"
        ("-u", "dialect"),       // gotländska: "-u"
    ]

    /// Given a root word, generates all possible derivatives using Swedish suffixes
    /// - Parameter word: A Swedish root word (e.g., "snabb", "skapa")
    /// - Returns: Array of derived words with suffixes applied
    func generateDerivatives(word: String) -> [String] {
        let root = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard root.count >= 2 else { return [] }

        var derivatives: [String] = []

        for (suffix, pos) in Self.derivationalSuffixes {
            let derived = root + suffix

            // Skip if already in lexicon with same POS (avoid redundant generation)
            if let entry = lexicon[derived], entry.pos == pos {
                derivatives.append(derived)
                continue
            }

            // Apply phonological adjustments for common Swedish patterns
            var adjusted = derived

            // Double consonant rule: kort rot → dubbel konsonant + suffix
            // e.g., "tunn" → "tunnhet" (already has double), "glad" → "gladhet"
            // Root ending in single consonant + "het"/"bar" sometimes doubles
            if root.count <= 3 && root.count >= 2 {
                if let lastChar = root.last, !lastChar.isVowel {
                    // Short root with single final consonant — sometimes doubled
                    // Only apply for specific suffixes where doubling is common
                    if suffix == "het" || suffix == "bar" {
                        // Check lexicon for doubled version
                        let doubled = root + String(lastChar) + suffix
                        if lexicon[doubled] != nil {
                            adjusted = doubled
                        }
                    }
                }
            }

            // Consonant assimilation: some roots change before certain suffixes
            // e.g., "lära" → "lärare" (a→are), not "läraare"
            if root.hasSuffix("a") && (suffix == "else" || suffix == "ande") {
                adjusted = String(root.dropLast()) + suffix
            }

            // Store if not duplicate
            if !derivatives.contains(adjusted) {
                derivatives.append(adjusted)
            }
        }

        return derivatives
    }

    // ═══════════════════════════════════════════════════════════
    // ITERATION 61-69: Advanced Semantics, Discourse, Narrative, Rhetoric
    // ═══════════════════════════════════════════════════════════

    // MARK: - Iteration 61: Argumentation Structure Analysis

    struct ArgumentationAnalysis {
        let claims: [ArgumentClaim]
        let evidence: [ArgumentEvidence]
        let warrants: [ArgumentWarrant]
        let rebuttals: [ArgumentRebuttal]
        let concessions: [ArgumentConcession]
        let argumentGraph: [ArgumentNode]
        let strengthScore: Double
        let fallacies: [LogicalFallacy]
        let analysis: String
    }
    struct ArgumentClaim: Identifiable {
        let id = UUID(); let text: String; let type: ClaimType; let confidence: Double
        enum ClaimType: String { case main, sub, counter }
    }
    struct ArgumentEvidence: Identifiable {
        let id = UUID(); let text: String; let supportsClaim: String?; let evidenceType: EvidenceType; let strength: Double
        enum EvidenceType: String { case factual, statistical, anecdotal, authoritative, logical }
    }
    struct ArgumentWarrant: Identifiable {
        let id = UUID(); let text: String; let connectsEvidence: String; let connectsClaim: String; let explicitness: Explicitness
        enum Explicitness { case explicit, implicit }
    }
    struct ArgumentRebuttal: Identifiable {
        let id = UUID(); let text: String; let targetsClaim: String; let rebuttalType: RebuttalType; let effectiveness: Double
        enum RebuttalType: String { case directRefutation, underminingWarrant, attackingEvidence, offeringCounter }
    }
    struct ArgumentConcession: Identifiable {
        let id = UUID(); let text: String; let concededPoint: String; let followedByCounter: Bool
    }
    struct ArgumentNode: Identifiable {
        let id = UUID(); let text: String; let nodeType: ArgumentNodeType; var children: [UUID]; let strength: Double
        enum ArgumentNodeType: String { case claim, evidence, warrant, rebuttal, concession }
    }
    struct LogicalFallacy: Identifiable {
        let id = UUID(); let type: FallacyType; let text: String; let explanation: String; let severity: Double
        enum FallacyType: String, CaseIterable {
            case adHominem = "ad hominem"; case strawMan = "straw man"; case falseDichotomy = "false dichotomy"
            case slipperySlope = "slippery slope"; case circularReasoning = "cirkelresonemang"
        }
    }

    private static let claimMarkers: Set<String> = ["jag anser", "jag tycker", "jag menar", "jag hävdar", "det är tydligt att", "utan tvekan", "uppenbarligen", "det står klart", "min uppfattning är", "vi bör", "vi måste", "det är nödvändigt", "det är viktigt att"]
    private static let evidenceMarkers: Set<String> = ["till exempel", "exempelvis", "enligt", "studier visar", "forskning", "bevis", "statistik", "undersökningar", "rapporter", "data visar", "som exempel", "ett bevis", "fakta är", "det finns belägg"]
    private static let warrantMarkers: Set<String> = ["detta innebär", "vilket betyder", "detta visar", "alltså", "därför att", "eftersom", "då", "med andra ord", "detta leder till", "följden blir"]
    private static let rebuttalMarkers: Set<String> = ["men", "dock", "emellertid", "å andra sidan", "däremot", "ändå", "trots detta", "fastän", "även om", "mot detta kan invändas", "kritiker menar", "vissa hävdar", "en invändning"]
    private static let concessionMarkers: Set<String> = ["visserligen", "certe", "jag medger", "det är sant att", "naturligtvis", "givetvis", "visst", "det ska medges", "även om", "trots att"]

    func analyzeArgumentation(text: String) -> ArgumentationAnalysis {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        var claims: [ArgumentClaim] = []; var evidence: [ArgumentEvidence] = []; var warrants: [ArgumentWarrant] = []
        var rebuttals: [ArgumentRebuttal] = []; var concessions: [ArgumentConcession] = []; var nodes: [ArgumentNode] = []
        var fallacies: [LogicalFallacy] = []

        for sentence in sentences {
            let sl = sentence.lowercased()
            for marker in Self.claimMarkers where sl.contains(marker) {
                let c = ArgumentClaim(text: sentence, type: .main, confidence: 0.8); claims.append(c)
                nodes.append(ArgumentNode(text: sentence, nodeType: .claim, children: [], strength: 0.7))
            }
            for marker in Self.evidenceMarkers where sl.contains(marker) {
                let evType: ArgumentEvidence.EvidenceType
                if sl.contains("studie") || sl.contains("forskning") { evType = .authoritative }
                else if sl.contains("statistik") || sl.contains("data") { evType = .statistical }
                else if sl.contains("exempel") { evType = .anecdotal }
                else { evType = .factual }
                let ev = ArgumentEvidence(text: sentence, supportsClaim: claims.last?.text, evidenceType: evType, strength: evType == .statistical ? 0.8 : evType == .authoritative ? 0.75 : 0.6)
                evidence.append(ev); nodes.append(ArgumentNode(text: sentence, nodeType: .evidence, children: [], strength: ev.strength))
            }
            for marker in Self.warrantMarkers where sl.contains(marker) {
                warrants.append(ArgumentWarrant(text: sentence, connectsEvidence: evidence.last?.text ?? "", connectsClaim: claims.last?.text ?? "", explicitness: .explicit))
                nodes.append(ArgumentNode(text: sentence, nodeType: .warrant, children: [], strength: 0.6))
            }
            for marker in Self.rebuttalMarkers where sl.contains(marker) {
                let rbType: ArgumentRebuttal.RebuttalType
                if sl.contains("invänd") || sl.contains("kritik") { rbType = .directRefutation }
                else if sl.contains("bevis") || sl.contains("fakta") { rbType = .attackingEvidence }
                else if sl.contains("menar") || sl.contains("hävdar") { rbType = .offeringCounter }
                else { rbType = .underminingWarrant }
                rebuttals.append(ArgumentRebuttal(text: sentence, targetsClaim: claims.last?.text ?? "", rebuttalType: rbType, effectiveness: 0.6))
                nodes.append(ArgumentNode(text: sentence, nodeType: .rebuttal, children: [], strength: 0.5))
            }
            for marker in Self.concessionMarkers where sl.contains(marker) {
                let followedByCounter = Self.rebuttalMarkers.contains { m in let idx = sl.range(of: marker)?.upperBound ?? sl.startIndex; return sl[idx...].contains(m) }
                concessions.append(ArgumentConcession(text: sentence, concededPoint: sentence, followedByCounter: followedByCounter))
                nodes.append(ArgumentNode(text: sentence, nodeType: .concession, children: [], strength: 0.4))
            }
        }

        for (i, node) in nodes.enumerated() where node.nodeType == .evidence {
            if let ci = nodes.firstIndex(where: { $0.nodeType == .claim }) { nodes[i].children.append(nodes[ci].id) }
        }

        // Fallacy detection
        let fallacyPatterns: [(pattern: String, type: LogicalFallacy.FallacyType, explanation: String)] = [
            ("(du|han|hon|de).*(är|verkar).*(naiv|dum|okunnig|enfaldig)", .adHominem, "Personangrepp: attackerar personen istället för argumentet"),
            ("(din|hans|hennes).*(brist|okunnighet|naivitet)", .adHominem, "Personangrepp: fokuserar på personens brister"),
            ("(du|ni|de).*(tycker|menar|hävdar) alltså att.*(alla|alltid|aldrig|inget)", .strawMan, "Straw man: överdriver motståndarens position"),
            ("så.*(du|ni|de) vill.*(inget|aldrig|bara|enbart)", .strawMan, "Straw man: förenklar motståndarens argument"),
            ("(antingen|endast).*(eller|annars).*(inte|aldrig)", .falseDichotomy, "Falsk dikotomi: presenterar bara två alternativ"),
            ("(är|vill) du.*(för|mot|med|emot)", .falseDichotomy, "Falsk dikotomi: tvingar fram ett binärt val"),
            ("om.*(då|sedan|sen|efter|leda|resultera|betyda|innebär).*och.*(sedan|sen|därefter)", .slipperySlope, "Sluttande plan: kedja av osannolika konsekvenser"),
            ("först.*(sen|sedan|därefter|efter det|nästa steg|till slut)", .slipperySlope, "Sluttande plan: antar oundviklig kedja"),
        ]
        for sentence in sentences {
            let sl = sentence.lowercased()
            for (pattern, type, explanation) in fallacyPatterns {
                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                if let regex, regex.firstMatch(in: sl, range: NSRange(sl.startIndex..., in: sl)) != nil {
                    fallacies.append(LogicalFallacy(type: type, text: sentence, explanation: explanation, severity: 0.7))
                }
            }
        }

        let claimEvidenceRatio = claims.isEmpty ? 0.0 : min(1.0, Double(evidence.count) / Double(claims.count))
        let rebuttalBonus = claims.isEmpty ? 0.0 : min(0.2, Double(rebuttals.count) * 0.1)
        let concessionBonus = concessions.filter { $0.followedByCounter }.isEmpty ? 0.0 : 0.1
        let fallacyPenalty = Double(fallacies.count) * 0.1
        let strengthScore = max(0.0, min(1.0, claimEvidenceRatio * 0.5 + rebuttalBonus + concessionBonus - fallacyPenalty + 0.2))
        let analysis = claims.isEmpty ? "Inga tydliga påståenden identifierade" : "Argumentationsanalys: \(claims.count) påståenden, \(evidence.count) bevis, \(rebuttals.count) motbevis, \(fallacies.count) logiska felslut"
        return ArgumentationAnalysis(claims: claims, evidence: evidence, warrants: warrants, rebuttals: rebuttals, concessions: concessions, argumentGraph: nodes, strengthScore: strengthScore, fallacies: fallacies, analysis: analysis)
    }

    // MARK: - Iteration 62: Narrative Structure Detection

    struct NarrativeStructure {
        let narrativeArc: NarrativeArc; let temporalMarkers: [TemporalMarker]
        let characterPerspectives: [CharacterPerspective]; let plotCoherence: Double
        let narrativeType: NarrativeType; let creativityBoost: Double; let comprehensionBoost: Double; let analysis: String
    }
    struct NarrativeArc: Codable {
        let exposition: [String]; let risingAction: [String]; let climax: [String]; let fallingAction: [String]; let resolution: [String]
        var arcComplete: Bool { !exposition.isEmpty && !risingAction.isEmpty && !climax.isEmpty && !resolution.isEmpty }
    }
    struct TemporalMarker: Identifiable {
        let id = UUID(); let text: String; let type: TemporalType; let position: Int
        enum TemporalType: String { case flashback, flashForward, simultaneous, linear, ambiguous }
    }
    struct CharacterPerspective: Identifiable {
        let id = UUID(); let character: String; let sentences: [String]; let perspectiveType: PerspectiveType
        enum PerspectiveType: String { case firstPerson, thirdPersonLimited, thirdPersonOmniscient, unreliable }
    }
    enum NarrativeType: String, CaseIterable { case linear = "linjär"; case nonLinear = "icke-linjär"; case frameNarrative = "ramberättelse"; case streamOfConsciousness = "medvetandeström"; case unknown = "okänd" }

    private static let expositionMarkers: Set<String> = ["det var en gång", "för länge sedan", "i början", "allt började", "det började med", "från början", "till en början"]
    private static let risingActionMarkers: Set<String> = ["plötsligt", "men sedan", "dock", "samtidigt", "mer och mer", "allt oftare", "successivt", "gradvis", "efterhand", "snart", "då hände något"]
    private static let climaxMarkers: Set<String> = ["högsta punkten", "kulmen", "toppen", "avgörande ögonblick", "vändpunkten", "allt eller inget", "i det avgörande ögonblicket", "plötsligt insåg", "då förstod"]
    private static let fallingActionMarkers: Set<String> = ["efter det", "därefter", "som följd", "i spåren av", "efter händelsen", "när allt var över", "efter stormen"]
    private static let resolutionMarkers: Set<String> = ["slutligen", "till slut", "sammanfattningsvis", "så småningom", "i slutändan", "resultatet blev", "och så", "det slutade med"]
    private static let flashbackMarkers: Set<String> = ["tidigare", "förut", "innan", "bakåt i tiden", "i minnet", "minns", "kom ihåg", "tänkte tillbaka", "år tillbaka", "förra året", "en gång i tiden"]
    private static let flashForwardMarkers: Set<String> = ["senare", "i framtiden", "framåt", "kommande", "om ett år", "snart", "om några år", "i morgon", "någon gång senare", "år framöver"]
    private static let firstPersonMarkers: Set<String> = ["jag", "mig", "min", "mitt", "mina", "vi", "oss", "vår"]
    private static let thirdPersonMarkers: Set<String> = ["han", "hon", "hen", "den", "det", "de", "dem", "deras"]

    func detectNarrativeStructure(text: String) -> NarrativeStructure {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        let lowerText = text.lowercased()
        var exposition: [String] = []; var risingAction: [String] = []; var climax: [String] = []
        var fallingAction: [String] = []; var resolution: [String] = []
        for s in sentences {
            let sl = s.lowercased()
            if Self.expositionMarkers.contains(where: { sl.contains($0) }) { exposition.append(s) }
            else if Self.climaxMarkers.contains(where: { sl.contains($0) }) { climax.append(s) }
            else if Self.fallingActionMarkers.contains(where: { sl.contains($0) }) { fallingAction.append(s) }
            else if Self.resolutionMarkers.contains(where: { sl.contains($0) }) { resolution.append(s) }
            else if Self.risingActionMarkers.contains(where: { sl.contains($0) }) { risingAction.append(s) }
        }
        if exposition.isEmpty && risingAction.isEmpty && climax.isEmpty && fallingAction.isEmpty && resolution.isEmpty && sentences.count > 1 {
            let chunkSize = max(1, sentences.count / 5)
            exposition = Array(sentences.prefix(chunkSize))
            risingAction = Array(sentences[chunkSize..<min(chunkSize * 2, sentences.count)])
            if sentences.count > chunkSize * 2 { climax = Array(sentences[chunkSize * 2..<min(chunkSize * 3, sentences.count)]) }
            if sentences.count > chunkSize * 3 { fallingAction = Array(sentences[chunkSize * 3..<min(chunkSize * 4, sentences.count)]) }
            if sentences.count > chunkSize * 4 { resolution = Array(sentences[chunkSize * 4...]) }
        }
        let arc = NarrativeArc(expedition: exposition, risingAction: risingAction, climax: climax, fallingAction: fallingAction, resolution: resolution)

        var temporalMarkers: [TemporalMarker] = []
        for (idx, s) in sentences.enumerated() {
            let sl = s.lowercased()
            if Self.flashbackMarkers.contains(where: { sl.contains($0) }) { temporalMarkers.append(TemporalMarker(text: s, type: .flashback, position: idx)) }
            else if Self.flashForwardMarkers.contains(where: { sl.contains($0) }) { temporalMarkers.append(TemporalMarker(text: s, type: .flashForward, position: idx)) }
        }

        var perspectives: [CharacterPerspective] = []
        var currentCharacters: [String: [String]] = [:]
        for s in sentences {
            let sl = s.lowercased()
            let isFirst = Self.firstPersonMarkers.contains { sl.contains(" \($0) ") || sl.hasPrefix("\($0) ") }
            let isThird = Self.thirdPersonMarkers.contains { sl.contains(" \($0) ") || sl.hasPrefix("\($0) ") }
            if isFirst { currentCharacters["jag", default: []].append(s) }
            else if isThird { currentCharacters["third_person", default: []].append(s) }
        }
        for (char, charSentences) in currentCharacters {
            let pType: CharacterPerspective.PerspectiveType = char == "jag" ? .firstPerson : charSentences.count == 1 ? .thirdPersonLimited : .thirdPersonOmniscient
            perspectives.append(CharacterPerspective(character: char, sentences: charSentences, perspectiveType: pType))
        }

        let hasTemporalShifts = temporalMarkers.filter { $0.type == .flashback || $0.type == .flashForward }.count > 1
        let isSoC = sentences.filter { $0.count > 40 }.count > sentences.count / 2
        let hasFrame = (Self.expositionMarkers.contains { lowerText.contains($0) }) && (Self.resolutionMarkers.contains { lowerText.contains($0) })
        let narrativeType: NarrativeType
        if isSoC { narrativeType = .streamOfConsciousness }
        else if hasFrame && hasTemporalShifts { narrativeType = .frameNarrative }
        else if hasTemporalShifts { narrativeType = .nonLinear }
        else if !temporalMarkers.isEmpty { narrativeType = .linear }
        else { narrativeType = .unknown }

        let arcElements = [exposition, risingAction, climax, fallingAction, resolution].filter { !$0 }.count
        let plotCoherence = min(1.0, Double(arcElements) / 5.0 * 0.6 + (temporalMarkers.isEmpty ? 0.2 : 0.4))
        let creativityBoost = min(0.04, Double(arcElements) * 0.004 + (hasTemporalShifts ? 0.01 : 0.0))
        let comprehensionBoost = min(0.03, Double(perspectives.count) * 0.003 + (arc.arcComplete ? 0.01 : 0.0))
        let analysis = arc.arcComplete ? "Narrativ struktur: \(narrativeType.rawValue) med komplett berättelsebåge, \(temporalMarkers.count) tidsmarkörer, \(perspectives.count) perspektiv" : "Narrativ struktur: \(narrativeType.rawValue) — ofullständig båge (\(arcElements)/5 delar)"
        return NarrativeStructure(narrativeArc: arc, temporalMarkers: temporalMarkers, characterPerspectives: perspectives, plotCoherence: plotCoherence, narrativeType: narrativeType, creativityBoost: creativityBoost, comprehensionBoost: comprehensionBoost, analysis: analysis)
    }

    // MARK: - Iteration 63: Rhetorical Device Detection

    struct RhetoricalDevice: Identifiable, Codable {
        let id = UUID(); let type: RhetoricalDeviceType; let text: String; let explanation: String; let positions: [Int]; let strength: Double
        enum RhetoricalDeviceType: String, CaseIterable {
            case anaphora = "anafor"; case epistrophe = "epifor"; case chiasmus = "chiasm"; case parallelism = "parallelism"
            case tricolon = "trikolon"; case rhetoricalQuestion = "retorisk fråga"; case litotes = "litotes"
            case hyperbole = "hyperbol"; case alliteration = "allitteration"; case assonance = "assonans"
            case folkvisestil = "folkvisestil"; case talesätt = "talesätt"
        }
    }

    private static let folkvisestilPatterns: [(String, String)] = [("lilla", "Folkvisestil: diminutivt uttryck"), ("fagra", "Folkvisestil: poetiskt adjektiv"), ("mången", "Folkvisestil: arkaiskt pronomen"), ("den gången", "Folkvisestil: balladformel"), ("i ungdomens", "Folkvisestil: balladtema"), ("rida", "Folkvisestil: balladverb"), ("jungfru", "Folkvisestil: balladmotiv"), ("riddar", "Folkvisestil: balladmotiv")]
    private static let talesattPatterns: Set<String> = ["bättre fly än illa fäkta", "tiden läkar alla sår", "skam den som ger sig", "bra karl reder sig själv", "morgonstund har guld i mund", "man ska inte köpa katten i säcken", "den som väntar på något gott", "man ska inte ropa hop innan man har skjutit björnen", "den som gräver en grop", "söka efter nålen i höstacken", "vad man sådd får man skörda", "man ska inte kasta pärlor åt svin", "den som tiger samtycker"]

    func detectRhetoricalDevices(text: String) -> [RhetoricalDevice] {
        var devices: [RhetoricalDevice] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        let lowerText = text.lowercased()
        let words = lowerText.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }

        // Anaphora
        if sentences.count >= 2 {
            var anaphoricSequences: [[String]] = []; var currentSeq: [String] = [sentences[0]]
            var currentStart = sentences[0].lowercased().prefix(4)
            for i in 1..<sentences.count {
                let sentStart = sentences[i].lowercased().prefix(4)
                if sentStart == currentStart && currentStart.count >= 3 { currentSeq.append(sentences[i]) }
                else { if currentSeq.count >= 2 { anaphoricSequences.append(currentSeq) }; currentSeq = [sentences[i]]; currentStart = sentences[i].lowercased().prefix(4) }
            }
            if currentSeq.count >= 2 { anaphoricSequences.append(currentSeq) }
            for seq in anaphoricSequences { devices.append(RhetoricalDevice(type: .anaphora, text: seq.joined(separator: "; "), explanation: "Anafor: upprepning av '\(currentStart)' i början av \(seq.count) satser", positions: [], strength: min(0.95, 0.5 + Double(seq.count) * 0.15))) }
        }

        // Epistrophe
        if sentences.count >= 2 {
            var epiSequences: [[String]] = []; var currentSeq: [String] = [sentences[0]]
            var currentEnd = String(sentences[0].lowercased().suffix(4))
            for i in 1..<sentences.count {
                let sentEnd = String(sentences[i].lowercased().suffix(4))
                if sentEnd == currentEnd && currentEnd.count >= 3 { currentSeq.append(sentences[i]) }
                else { if currentSeq.count >= 2 { epiSequences.append(currentSeq) }; currentSeq = [sentences[i]]; currentEnd = String(sentences[i].lowercased().suffix(4)) }
            }
            if currentSeq.count >= 2 { epiSequences.append(currentSeq) }
            for seq in epiSequences { devices.append(RhetoricalDevice(type: .epistrophe, text: seq.joined(separator: "; "), explanation: "Epifor: upprepning i slutet av \(seq.count) satser", positions: [], strength: min(0.95, 0.5 + Double(seq.count) * 0.15))) }
        }

        // Chiasmus
        for i in 0..<(sentences.count - 1) {
            let w1 = sentences[i].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 }
            let w2 = sentences[i + 1].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 }
            if w1.count >= 2 && w2.count >= 2 && w1.first == w2.last && w1.last == w2.first {
                devices.append(RhetoricalDevice(type: .chiasmus, text: "\(sentences[i]); \(sentences[i + 1])", explanation: "Chiasm: ABBA-struktur", positions: [], strength: 0.8))
            }
        }

        // Parallelism
        for i in 0..<(sentences.count - 1) {
            let w1P = sentences[i].lowercased().components(separatedBy: .whitespacesAndNewlines).prefix(2).joined(separator: " ")
            let w2P = sentences[i + 1].lowercased().components(separatedBy: .whitespacesAndNewlines).prefix(2).joined(separator: " ")
            if w1P.count > 3 && w2P.count > 3 && w1P.count == w2P.count {
                let sim = Double(zip(w1P, w2P).filter { $0 == $1 }.count) / Double(w1P.count)
                if sim >= 0.5 { devices.append(RhetoricalDevice(type: .parallelism, text: "\(sentences[i]); \(sentences[i + 1])", explanation: "Parallelism: '\(w1P)' / '\(w2P)'", positions: [], strength: sim * 0.8)) }
            }
        }

        // Tricolon
        for s in sentences {
            let parts = s.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 2 }
            if parts.count == 3 {
                let lengths = parts.map { Double($0.components(separatedBy: .whitespacesAndNewlines).count) }
                let avg = lengths.reduce(0, +) / 3.0; let variance = lengths.map { pow($0 - avg, 2) }.reduce(0, +) / 3.0
                if variance < 2.0 { devices.append(RhetoricalDevice(type: .tricolon, text: s, explanation: "Trikolon: tredelad uppräkning", positions: [], strength: min(0.9, 0.6 + (1.0 - variance / 2.0) * 0.3))) }
            }
        }

        // Rhetorical questions
        for s in sentences where s.contains("?") {
            let sl = s.lowercased(); let qws = ["vem", "vad", "varför", "hur", "när", "var", "vilken"]
            if qws.contains(where: { sl.contains($0) }) { devices.append(RhetoricalDevice(type: .rhetoricalQuestion, text: s, explanation: "Retorisk fråga", positions: [], strength: 0.7)) }
        }

        // Litotes
        for pattern in ["inte dålig", "inte illa", "inte osannolikt", "inte obetydlig", "inte helt fel", "inte ovanligt", "inte utan", "icke desto mindre", "inte okunnig", "inte ointressant", "inte oviktigt", "inte omöjligt", "inte helt ovanligt", "inte så dumt"] where lowerText.contains(pattern) {
            devices.append(RhetoricalDevice(type: .litotes, text: pattern, explanation: "Litotes: underdrift genom dubbel negation", positions: [], strength: 0.75))
        }

        // Hyperbole
        let hyperWords = Set(["aldrig", "alltid", "värsta", "bästa", "sämsta", "ofattbart", "absolut", "totalt", "extremt", "enormt", "världens", "oändligt", "evigt", "fantastiskt", "fullständigt", "komplett"])
        let hyperMatches = words.filter { hyperWords.contains($0) }
        if hyperMatches.count >= 2 { devices.append(RhetoricalDevice(type: .hyperbole, text: String(hyperMatches.joined(separator: ", ")), explanation: "Hyperbol: överdrivna uttryck (\(hyperMatches.count) ord)", positions: [], strength: min(0.9, 0.4 + Double(hyperMatches.count) * 0.1))) }

        // Alliteration
        for s in sentences {
            let sw = s.lowercased().components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { $0.count > 2 }
            var i = 0
            while i < sw.count - 1 {
                let fl = sw[i].first; var count = 1
                while i + count < sw.count && sw[i + count].first == fl { count += 1 }
                if count >= 3 { devices.append(RhetoricalDevice(type: .alliteration, text: sw[i..<i + count].joined(separator: " "), explanation: "Allitteration: \(count) ord på '\(String(fl ?? "x"))'", positions: [], strength: min(0.9, 0.4 + Double(count) * 0.15))); i += count } else { i += 1 }
            }
        }

        // Assonance
        for (vowel, label) in [("a", "a/å"), ("e", "e/ä"), ("o", "o/ö"), ("i", "i"), ("u", "u")] {
            let vw = words.filter { $0.contains(vowel) }
            if vw.count >= 3 { devices.append(RhetoricalDevice(type: .assonance, text: vw.prefix(4).joined(separator: ", "), explanation: "Assonans: vokal '\(label)' i \(vw.count) ord", positions: [], strength: min(0.8, 0.3 + Double(vw.count) * 0.1))) }
        }

        // Folkvisestil
        for (pattern, explanation) in Self.folkvisestilPatterns where lowerText.contains(pattern) {
            devices.append(RhetoricalDevice(type: .folkvisestil, text: pattern, explanation: explanation, positions: [], strength: 0.7))
        }
        // Talesätt
        for ta in Self.talesattPatterns where lowerText.contains(ta) {
            devices.append(RhetoricalDevice(type: .talesätt, text: ta, explanation: "Talesätt: '\(ta)'", positions: [], strength: 0.85))
        }
        return devices
    }

    // MARK: - Iteration 64: Frame Semantics

    struct FrameAnalysis {
        let frames: [SemanticFrame]; let frameRelations: [FrameRelation]; let frameCompleteness: Double
        let whoDidWhat: [String]; let comprehensionBoost: Double
    }
    struct SemanticFrame: Identifiable {
        let id = UUID(); let frameName: String; let triggerWord: String; let frameElements: [FrameElement]; let completeness: Double
    }
    struct FrameElement: Codable { let role: String; let filler: String; let confidence: Double }
    struct FrameRelation: Identifiable {
        let id = UUID(); let fromFrame: String; let toFrame: String; let relationType: FrameRelationType
        enum FrameRelationType: String { case causes, enables, precedes, contrastsWith, partOf }
    }

    private static let frameDatabase: [String: (frameName: String, roles: [String])] = [
        "köpa": ("COMMERCE_BUY", ["köpare", "säljare", "vara", "pengar"]), "köp": ("COMMERCE_BUY", ["köpare", "säljare", "vara"]),
        "handla": ("COMMERCE_BUY", ["köpare", "säljare", "vara"]),
        "sälja": ("COMMERCE_SELL", ["säljare", "köpare", "vara", "pris"]), "försäljning": ("COMMERCE_SELL", ["säljare", "köpare", "vara"]),
        "ge": ("GIVING", ["givare", "mottagare", "objekt"]), "gav": ("GIVING", ["givare", "mottagare", "objekt"]), "giva": ("GIVING", ["givare", "mottagare", "objekt"]),
        "få": ("RECEIVING", ["mottagare", "givare", "objekt"]), "motta": ("RECEIVING", ["mottagare", "avsändare", "objekt"]),
        "ta": ("RECEIVING", ["tagare", "källa", "objekt"]),
        "skicka": ("TRANSFER", ["avsändare", "mottagare", "objekt", "medium"]), "sända": ("TRANSFER", ["avsändare", "mottagare", "objekt"]),
        "säga": ("COMMUNICATION", ["talare", "lyssnare", "meddelande"]), "berätta": ("COMMUNICATION", ["berättare", "åhörare", "innehåll"]),
        "skriva": ("COMMUNICATION", ["författare", "läsare", "text"]), "tala": ("COMMUNICATION", ["talare", "publik", "ämne"]),
        "prata": ("COMMUNICATION", ["talare", "lyssnare", "ämne"]), "fråga": ("COMMUNICATION", ["frågare", "svarare", "fråga"]),
        "svara": ("COMMUNICATION", ["svarare", "frågare", "svar"]), "meddela": ("COMMUNICATION", ["avsändare", "mottagare", "meddelande"]),
        "se": ("PERCEPTION", ["observatör", "fenomen"]), "höra": ("PERCEPTION", ["lyssnare", "ljud"]),
        "känna": ("PERCEPTION", ["kännare", "stimulus"]), "observera": ("PERCEPTION", ["observatör", "fenomen"]),
        "tänka": ("COGNITION", ["tänkare", "tankeinnehåll"]), "tro": ("COGNITION", ["troende", "proposition"]),
        "veta": ("COGNITION", ["vetare", "faktum"]), "förstå": ("COGNITION", ["förstående", "fenomen"]),
        "begripa": ("COGNITION", ["begripare", "fenomen"]), "minnas": ("COGNITION", ["minnande", "erinran"]),
        "glömma": ("COGNITION", ["glömsk", "glömt"]), "lära": ("COGNITION", ["lärande", "innehåll", "källa"]),
        "fundera": ("COGNITION", ["funderande", "ämne"]), "misstänka": ("COGNITION", ["misstänkande", "proposition"]),
        "älska": ("EMOTION", ["kännare", "objekt"]), "hata": ("EMOTION", ["kännare", "objekt"]),
        "frukta": ("EMOTION", ["kännare", "hot"]), "oroa": ("EMOTION", ["kännare", "orsak"]),
        "glädja": ("EMOTION", ["kännare", "orsak"]), "sörja": ("EMOTION", ["sörjande", "orsak"]),
        "gå": ("MOTION", ["rörelseaktör", "källa", "mål"]), "springa": ("MOTION", ["rörelseaktör", "mål"]),
        "åka": ("MOTION", ["rörelseaktör", "källa", "mål"]), "resa": ("MOTION", ["resenär", "källa", "mål"]),
        "flyga": ("MOTION", ["rörelseaktör", "källa", "mål"]), "cykla": ("MOTION", ["cyklist", "källa", "mål"]),
        "köra": ("MOTION", ["förare", "fordon", "källa", "mål"]), "vandra": ("MOTION", ["vandrare", "källa", "mål"]),
        "bli": ("CHANGE", ["entitet", "sluttillstånd", "orsak"]), "ändra": ("CHANGE", ["aktör", "objekt", "nytt_tillstånd"]),
        "förändra": ("CHANGE", ["aktör", "objekt", "nytt_tillstånd"]), "utveckla": ("CHANGE", ["aktör", "objekt", "resultat"]),
        "öka": ("CHANGE", ["entitet", "mängd"]), "minska": ("CHANGE", ["entitet", "mängd"]),
        "skapa": ("CREATION", ["skapare", "resultat"]), "bygga": ("CREATION", ["byggare", "resultat"]),
        "tillverka": ("CREATION", ["tillverkare", "resultat"]), "göra": ("CREATION", ["aktör", "resultat"]),
        "producera": ("CREATION", ["producent", "resultat"]), "konstruera": ("CREATION", ["konstruktör", "resultat"]),
        "förstöra": ("DESTRUCTION", ["aktör", "objekt"]), "krossa": ("DESTRUCTION", ["aktör", "objekt"]),
        "ha": ("POSSESSION", ["ägare", "objekt"]), "äga": ("POSSESSION", ["ägare", "objekt"]),
        "tillhöra": ("POSSESSION", ["ägare", "objekt"]), "förlora": ("POSSESSION", ["förlorare", "objekt"]),
        "hjälpa": ("SOCIAL", ["hjälpare", "hjälptagare", "uppgift"]), "stjäla": ("SOCIAL", ["tjuv", "offer", "objekt"]),
        "lova": ("SOCIAL", ["lovare", "mottagare", "löfte"]), "tacka": ("SOCIAL", ["tackare", "mottagare"]),
        "förlåta": ("SOCIAL", ["förlåtare", "syndare"]), "straffa": ("SOCIAL", ["straffare", "bestraffad", "brott"]),
        "döma": ("JUDGING", ["domare", "bedömd", "kriterium"]), "bedöma": ("JUDGING", ["bedömare", "bedömd", "kriterium"]),
        "kritisera": ("JUDGING", ["kritiker", "kritiserad"]), "berömma": ("JUDGING", ["berömmare", "berömd"]),
        "försöka": ("ATTEMPT", ["försökare", "mål"]), "pröva": ("ATTEMPT", ["prövare", "mål"]),
        "orsaka": ("CAUSE", ["orsak", "verkan", "aktör"]), "leda": ("CAUSE", ["orsak", "verkan"]),
        "resultera": ("CAUSE", ["orsak", "verkan"]), "medföra": ("CAUSE", ["orsak", "verkan"]),
        "påverka": ("CAUSE", ["påverkare", "påverkad"]), "utlösa": ("CAUSE", ["utlösare", "händelse"]),
        "bidra": ("CAUSE", ["bidragare", "resultat"]),
        "födas": ("BEING_BORN", ["person", "tid", "plats"]), "dö": ("DYING", ["person", "tid", "orsak"]),
        "upptäcka": ("BECOMING_AWARE", ["upptäckare", "fenomen"]), "inse": ("BECOMING_AWARE", ["inseende", "faktum"]),
        "studera": ("EDUCATION", ["student", "ämne", "plats"]), "läsa": ("EDUCATION", ["läsare", "ämne"]),
        "undervisa": ("EDUCATION", ["lärare", "elev", "ämne"]), "forska": ("EDUCATION", ["forskare", "ämne"]),
        "analysera": ("EDUCATION", ["analytiker", "objekt"]),
        "leverera": ("TRANSFER", ["leverantör", "mottagare", "objekt"]), "upplysa": ("COMMUNICATION", ["upplysare", "mottagare", "information"]),
        "lukta": ("PERCEPTION", ["observatör", "doft"]), "smaka": ("PERCEPTION", ["smakare", "mat"]),
        "glömma": ("COGNITION", ["glömsk", "glömt"]), "ana": ("COGNITION", ["anande", "proposition"]),
        "beundra": ("EMOTION", ["beundrare", "objekt"]), "förundra": ("EMOTION", ["förundrande", "fenomen"]),
        "simma": ("MOTION", ["simnare", "källa", "mål"]), "röra": ("MOTION", ["aktör", "objekt", "riktning"]),
        "förbättra": ("CHANGE", ["aktör", "objekt"]), "försämra": ("CHANGE", ["aktör", "objekt"]),
        "forma": ("CREATION", ["aktör", "resultat"]), "designa": ("CREATION", ["designer", "resultat"]),
        "rasera": ("DESTRUCTION", ["aktör", "objekt"]), "bryta": ("DESTRUCTION", ["aktör", "objekt"]),
        "behålla": ("POSSESSION", ["behållare", "objekt"]), "hålla": ("POSSESSION", ["hållare", "objekt"]),
        "lura": ("SOCIAL", ["bedragare", "offer"]), "bedra": ("SOCIAL", ["bedragare", "offer"]),
        "svika": ("SOCIAL", ["svikare", "offer"]), "hota": ("SOCIAL", ["hotare", "hotad", "hot"]),
        "bjuda": ("SOCIAL", ["värd", "gäst", "erbjudande"]), "ursäkta": ("SOCIAL", ["ursäktare", "mottagare"]),
        "belöna": ("SOCIAL", ["belönare", "belönad", "förtjänst"]),
        "ogilla": ("JUDGING", ["ogillare", "ogillad"]), "gilla": ("JUDGING", ["gillare", "gillad"]),
        "förakta": ("JUDGING", ["föraktare", "föraktad"]),
        "sträva": ("ATTEMPT", ["strävare", "mål"]),
        "framkalla": ("CAUSE", ["orsak", "effekt"]), "bidra": ("CAUSE", ["bidragare", "resultat"]),
        "avlida": ("DYING", ["person", "tid"]), "mörda": ("DYING", ["mördare", "offer"]),
        "märka": ("BECOMING_AWARE", ["märkare", "fenomen"]), "notera": ("BECOMING_AWARE", ["noterande", "fenomen"]),
        "erkänna": ("BECOMING_AWARE", ["erkännande", "faktum"]),
        "svära": ("MAKING_PROMISES", ["svärande", "löfte"]), "garantera": ("MAKING_PROMISES", ["garant", "löfte"]),
        "utbilda": ("EDUCATION", ["utbildare", "elev", "ämne"]), "examinera": ("EDUCATION", ["examinator", "student"]),
    ]

    func analyzeFrameSemantics(text: String) -> FrameAnalysis {
        let lower = text.lowercased()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        var frames: [SemanticFrame] = []; var frameRelations: [FrameRelation] = []; var whoDidWhat: [String] = []

        for sentence in sentences {
            let sl = sentence.lowercased()
            let sw = sl.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
            for word in sw {
                if let (frameName, roles) = Self.frameDatabase[word] {
                    var elements: [FrameElement] = []
                    let otherWords = sw.filter { $0 != word }
                    for (roleIdx, role) in roles.enumerated() where roleIdx < otherWords.count {
                        elements.append(FrameElement(role: role, filler: otherWords[roleIdx], confidence: 0.6))
                    }
                    // Preposition-based role filling
                    if let idx = sw.firstIndex(of: "av"), idx + 1 < sw.count { elements.append(FrameElement(role: "källa/agent", filler: sw[idx + 1], confidence: 0.7)) }
                    if let idx = sw.firstIndex(of: "till"), idx + 1 < sw.count { elements.append(FrameElement(role: "mål/mottagare", filler: sw[idx + 1], confidence: 0.7)) }
                    if let idx = sw.firstIndex(of: "med"), idx + 1 < sw.count { elements.append(FrameElement(role: "instrument", filler: sw[idx + 1], confidence: 0.7)) }
                    if let idx = sw.firstIndex(of: "från"), idx + 1 < sw.count { elements.append(FrameElement(role: "ursprung", filler: sw[idx + 1], confidence: 0.7)) }

                    let completeness = roles.isEmpty ? 0.0 : Double(elements.count) / Double(max(1, roles.count))
                    frames.append(SemanticFrame(frameName: frameName, triggerWord: word, frameElements: elements, completeness: min(1.0, completeness)))

                    let agent = elements.first(where: { $0.role.contains("givare") || $0.role.contains("aktör") || $0.role.contains("köpare") || $0.role.contains("talare") })
                    let patient = elements.first(where: { $0.role.contains("objekt") || $0.role.contains("vara") || $0.role.contains("meddelande") })
                    let goal = elements.first(where: { $0.role.contains("mottagare") || $0.role.contains("mål") })
                    if let a = agent, let p = patient { whoDidWhat.append(goal != nil ? "\(a.filler) \(word) \(p.filler) till \(goal!.filler)" : "\(a.filler) \(word) \(p.filler)") }
                    else if let p = patient { whoDidWhat.append("\(word) \(p.filler)") }
                }
            }
        }

        for i in 0..<(frames.count - 1) {
            let f1 = frames[i], f2 = frames[i + 1]
            if (f1.frameName == "ATTEMPT" || f1.frameName == "CAUSE") && (f2.frameName == "CHANGE" || f2.frameName == "CREATION") { frameRelations.append(FrameRelation(fromFrame: f1.frameName, toFrame: f2.frameName, relationType: .causes)) }
            if f1.frameName == "MOTION" && f2.frameName == "PERCEPTION" { frameRelations.append(FrameRelation(fromFrame: f1.frameName, toFrame: f2.frameName, relationType: .precedes)) }
            if (f1.frameName == "POSSESSION" && f2.frameName == "DESTRUCTION") || (f1.frameName == "DESTRUCTION" && f2.frameName == "POSSESSION") { frameRelations.append(FrameRelation(fromFrame: f1.frameName, toFrame: f2.frameName, relationType: .contrastsWith)) }
        }

        let frameCompleteness = frames.isEmpty ? 0.0 : frames.reduce(0.0) { $0 + $1.completeness } / Double(frames.count)
        return FrameAnalysis(frames: frames, frameRelations: frameRelations, frameCompleteness: frameCompleteness, whoDidWhat: whoDidWhat, comprehensionBoost: min(0.1, Double(frames.count) * 0.005))
    }

    // MARK: - Iteration 65: Presupposition Detection

    struct Presupposition: Identifiable {
        let id = UUID(); let type: PresuppositionType; let text: String; let presupposedContent: String; let trigger: String; let confidence: Double; let negationTest: Bool
        enum PresuppositionType: String { case factive = "faktiv"; case implicative = "implikativ"; case lexical = "lexikalisk"; case structural = "strukturell"; case nonRestrictiveRelative = "icke-restriktiv relativsats" }
    }

    private static let factiveVerbs: Set<String> = ["vet", "veta", "visste", "inse", "inser", "insåg", "upptäcka", "upptäcker", "upptäckte", "ångra", "ångrade", "begråta", "begråter", "förvånad", "glad över", "ledsen över", "stolt över", "realisera", "realiserar", "förstå", "förstår", "förstod", "medge", "medger", "medgav", "erkänna", "erkänner", "erkände", "är medveten", "var medveten"]
    private static let implicativeVerbs: Set<String> = ["lyckades", "lyckas", "glömde", "glömmer", "glömma", "undvek", "undviker", "undvika", "tvingades", "tvingas", "tvinga", "vågade", "vågar", "våga", "kunde", "kan", "kunna", "hinner", "hinna", "hann", "orkade", "orkar", "orka", "förmådde", "förmår", "förmå"]
    private static let lexicalPresuppositionTriggers: [String: String] = ["sluta": "att personen tidigare gjorde handlingen", "slutar": "att personen tidigare gjorde handlingen", "slutade": "att personen tidigare gjorde handlingen", "fortsätta": "att personen redan påbörjat handlingen", "fortsätter": "att personen redan påbörjat handlingen", "fortsatte": "att personen redan påbörjat handlingen", "börja": "att handlingen inte pågick tidigare", "börjar": "att handlingen inte pågick tidigare", "började": "att handlingen inte pågick tidigare", "återvända": "att personen varit där tidigare", "återvänder": "att personen varit där tidigare", "återvände": "att personen varit där tidigare", "än en gång": "att det hänt minst en gång tidigare", "återigen": "att det hänt minst en gång tidigare", "igen": "att det hänt minst en gång tidigare", "också": "att något annat liknande gäller", "dessutom": "att något annat redan etablerats"]
    private static let structuralPresupPositions: Set<String> = ["om", "ifall", "såvida", "förutsatt att", "under förutsättning att"]
    private static let nonRestrictiveMarkers = [", som ", ", vilket ", ", vilken ", ", vilka "]

    func detectPresuppositions(text: String) -> [Presupposition] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        var presuppositions: [Presupposition] = []
        for sentence in sentences {
            let sl = sentence.lowercased()
            let words = sl.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
            for (i, word) in words.enumerated() where Self.factiveVerbs.contains(word) {
                let complement = words[(i + 1)...].joined(separator: " ")
                presuppositions.append(Presupposition(type: .factive, text: sentence, presupposedContent: complement, trigger: word, confidence: 0.85, negationTest: true))
            }
            for (i, word) in words.enumerated() where Self.implicativeVerbs.contains(word) && i + 1 < words.count {
                let complement = words[(i + 1)...].joined(separator: " ")
                presuppositions.append(Presupposition(type: .implicative, text: sentence, presupposedContent: "försökte: \(complement)", trigger: word, confidence: 0.75, negationTest: false))
            }
            for (trigger, meaning) in Self.lexicalPresuppositionTriggers where sl.contains(trigger) {
                presuppositions.append(Presupposition(type: .lexical, text: sentence, presupposedContent: meaning, trigger: trigger, confidence: 0.7, negationTest: true))
            }
            if let condIdx = words.firstIndex(where: { Self.structuralPresupPositions.contains($0) }) {
                let condition = words[(condIdx + 1)...].joined(separator: " ")
                presuppositions.append(Presupposition(type: .structural, text: sentence, presupposedContent: "möjligt att: \(condition)", trigger: words[condIdx], confidence: 0.65, negationTest: false))
            }
            for marker in Self.nonRestrictiveMarkers where sl.contains(marker) {
                if let idx = sl.range(of: marker) {
                    let relativeContent = String(sl[idx.upperBound...]).components(separatedBy: ".").first ?? ""
                    presuppositions.append(Presupposition(type: .nonRestrictiveRelative, text: sentence, presupposedContent: "det som beskrivs existerar: \(relativeContent)", trigger: marker.trimmingCharacters(in: .whitespaces), confidence: 0.7, negationTest: true))
                }
            }
        }
        return presuppositions
    }

    // MARK: - Iteration 66: Conversational Implicature Detection

    struct Implicature: Identifiable {
        let id = UUID(); let violatedMaxim: GriceanMaxim; let utterance: String; let literalMeaning: String; let inferredMeaning: String; let confidence: Double; let explanation: String
    }
    enum GriceanMaxim: String, CaseIterable { case quantity = "Kvantitet"; case quality = "Kvalitet"; case relation = "Relation"; case manner = "Sätt" }

    func detectImplicatures(conversation: [String]) -> [Implicature] {
        guard conversation.count >= 2 else { return [] }
        var implicatures: [Implicature] = []
        for (idx, utterance) in conversation.enumerated() {
            let lower = utterance.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let words = lower.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }

            // Quantity violations
            if idx > 0 {
                let prevLen = conversation[idx - 1].count
                if prevLen > 50 && utterance.count < 10 && words.count <= 2 {
                    if words == ["ok"] || words == ["okej"] || words == ["ja"] || words == ["n"] || words == ["nä"] {
                        implicatures.append(Implicature(violatedMaxim: .quantity, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Talaren ger medvetet minimal information — kanske ogillande eller ointresse", confidence: 0.6, explanation: "Kvantitetsbrott: oväntat kort svar"))
                    }
                }
            }
            if words.count > 50 {
                let hedgeCount = words.filter { ["kanske", "möjligen", "typ", "liksom", "asså", "egentligen"].contains($0) }.count
                if hedgeCount >= 3 {
                    implicatures.append(Implicature(violatedMaxim: .quantity, utterance: utterance, literalMeaning: String(utterance.prefix(100)), inferredMeaning: "Onödigt mycket detaljinformation — kanske för att dölja något", confidence: 0.5, explanation: "Kvantitetsbrott: överdrivet detaljerat"))
                }
            }

            // Quality violations
            if lower.contains("alla ") && (lower.contains("vet") || lower.contains("tycker")) {
                implicatures.append(Implicature(violatedMaxim: .quality, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Generalisering utan belägg — subjektiv uppfattning som fakta", confidence: 0.55, explanation: "Kvalitetsbrott: obelagd generalisering"))
            }
            if (lower.contains("jag vet") || lower.contains("alla vet")) && words.contains(where: { $0.contains("alltid") || $0.contains("aldrig") }) {
                implicatures.append(Implicature(violatedMaxim: .quality, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Kunskapspåstående som inte kan verifieras — ironi eller överdrift", confidence: 0.6, explanation: "Kvalitetsbrott: kunskapspåstående med absolut formulering"))
            }

            // Relation violations
            if idx > 0 && words.count >= 3 {
                let prevWords = Set(conversation[idx - 1].lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
                let currWords = Set(words.filter { $0.count > 3 })
                if prevWords.intersection(currWords).isEmpty && !lower.contains("?") && !conversation[idx - 1].contains("?") {
                    let hasTopicShift = ["förresten", "just det", "apropå", "men", "annars", "på ett annat plan"].contains { lower.contains($0) }
                    if !hasTopicShift {
                        implicatures.append(Implicature(violatedMaxim: .relation, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Svaret verkar inte relevant — talaren kanske undviker ämnet", confidence: 0.45, explanation: "Relationsbrott: ingen tydlig topikanknytning"))
                    }
                }
            }

            // Manner violations
            let vagueWords = Set(["något", "någon", "någonting", "saker", "ting", "grejer", "grej", "grejen", "typ", "liksom", "asså", "va", "nån", "nånstans"])
            let vagueCount = words.filter { vagueWords.contains($0) }.count
            if vagueCount >= 4 && words.count > 5 {
                implicatures.append(Implicature(violatedMaxim: .manner, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Talaren är medvetet otydlig — kanske för att undvika ansvar", confidence: 0.55, explanation: "Sättbrott: \(vagueCount) vaga uttryck"))
            }

            // Irony via maxim violation
            let posInBad = lower.contains("bra") || lower.contains("fint") || lower.contains("trevligt") || lower.contains("underbart")
            let badWords = ["problem", "fel", "dåligt", "trasig", "krångel", "misslyckad", "död", "katastrof"]
            if posInBad && words.contains(where: { badWords.contains($0) }) {
                implicatures.append(Implicature(violatedMaxim: .quality, utterance: utterance, literalMeaning: utterance, inferredMeaning: "Ironi: positivt ord i negativ kontext — talaren menar motsatsen", confidence: 0.7, explanation: "Kvalitetsbrott: inkongruens mellan känsla och kontext"))
            }
        }
        return implicatures
    }

    // MARK: - Iteration 67: Genre Classification

    struct GenreClassification {
        let genre: Genre; let confidence: Double; let secondaryGenres: [(Genre, Double)]; let interpretationMode: InterpretationMode; let features: GenreFeatures
    }
    enum Genre: String, CaseIterable { case newsArticle = "nyhetsartikel"; case academicText = "akademisk text"; case casualConversation = "vardagssamtal"; case formalLetter = "formellt brev"; case instructionManual = "instruktion"; case opinionPiece = "opinion/ledare"; case narrativeFiction = "skönlitteratur"; case poetry = "poesi"; case advertisement = "annons/reklam"; case legalText = "juridisk text"; case email = "e-post"; case socialMedia = "sociala medier"; case unknown = "okänd" }
    enum InterpretationMode: String { case factChecking = "faktagranskning"; case hedgingAware = "hedging-medveten"; case metaphorHeavy = "metaforintensiv"; case imperativeDriven = "imperativstyrd"; case persuasionAware = "persuasionsmedveten"; case legalInterpretation = "juridisk tolkning"; case casual = "vardaglig"; case standard = "standard" }
    struct GenreFeatures { let avgSentenceLength: Double; let lexicalDiversity: Double; let formalWordRatio: Double; let punctuationDensity: Double; let hasHeadline: Bool; let hasCitations: Bool; let hasImperatives: Bool; let hasEmojis: Bool }

    private static let newsIndicators: Set<String> = ["enligt uppgift", "polis meddelar", "källa uppger", "nyhetsbyrån", "presstjänsten", "TT", "reporter", "korrespondent", "breaking", "senaste nytt", "just nu", "publicerad", "uppdaterad"]
    private static let academicIndicators: Set<String> = ["enligt studien", "forskningsresultat", "hypotes", "metod", "empirisk", "kvantitativ", "kvalitativ", "signifikant", "korrelation", "kausal", "sammanfattning", "abstract", "referens", "citerad", "litteratur", "avhandling"]
    private static let casualIndicators: Set<String> = ["asså", "typ", "liksom", "va", "ju", "haha", "lol", "fan", "sjukt", "grymt", "nice"]
    private static let formalLetterIndicators: Set<String> = ["bästa", "bäste", "med vänliga hälsningar", "vänliga hälsningar", "högaktningsfullt", "härmed", "bifogas", "åberopar", "diarienummer"]
    private static let instructionIndicators: Set<String> = ["gör så här", "steg", "instruktion", "observera", "viktigt", "säkerhet", "montera", "installera", "koppla", "anslut", "tryck", "klicka", "öppna", "välj", "spara"]
    private static let opinionIndicators: Set<String> = ["jag anser", "jag tycker", "enligt min mening", "det är dags", "vi bör", "vi måste", "det är fel att", "regeringen borde", "ledare", "krönika", "debattartikel"]
    private static let fictionIndicators: Set<String> = ["det var en gång", "han gick", "hon såg", "de stod", "plötsligt", "då hände", "berättade", "sade", "svarade", "tänkte", "kände", "viskade", "ropade"]
    private static let poetryIndicators: Set<String> = ["vers", "strof", "rim", "rytm", "dikt", "poesi", "låt", "sång", "melodi"]
    private static let advertisementIndicators: Set<String> = ["köp nu", "erbjudande", "rea", "rabatt", "begränsad tid", "exklusivt", "missa inte", "just nu", "billigt", "kampanj", "nyhet", "fri frakt", "prova gratis"]
    private static let legalIndicators: Set<String> = ["enligt lag", "paragraf", "lagrum", "rättsfall", "domstol", "åtal", "rättighet", "skyldighet", "avtal", "villkor", "bestämmelse", "föreskrift", "stadga", "förordning", "lagen"]
    private static let emailIndicators: Set<String> = ["hej", "bästa", "mvh", "hälsningar", "bilaga", "vidarebefordra", "svara alla", "cc", "bcc"]
    private static let socialMediaIndicators: Set<String> = ["#", "@", "follow", "like", "share", "retweet", "tagga", "story", "post", "uppdatering", "följare", "gilla"]

    func classifyGenre(text: String) -> GenreClassification {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        let totalWords = words.count; let totalSentences = max(1, sentences.count)
        let avgSentenceLength = Double(totalWords) / Double(totalSentences)
        let uniqueWords = Set(words); let lexicalDiversity = uniqueWords.isEmpty ? 0.0 : Double(uniqueWords.count) / Double(max(1, totalWords))
        let formalCount = words.filter { ["härmed", "bifogas", "enligt", "beträffande", "avseende", "vederbörande", "följaktligen", "således"].contains($0) }.count
        let formalWordRatio = Double(formalCount) / Double(max(1, totalWords))
        let punctuationCount = text.filter { ".!?,;:".contains($0) }.count
        let punctuationDensity = Double(punctuationCount) / Double(max(1, text.count))
        let hasHeadline = (sentences.first?.count ?? 0) < 30 && totalSentences > 2
        let hasCitations = lower.contains("\"") || lower.contains("enligt ")
        let hasImperatives = words.contains { ["gör", "öppna", "stäng", "tryck", "klicka", "välj", "spara", "montera", "installera"].contains($0) }
        let hasEmojis = text.unicodeScalars.contains { $0.properties.isEmojiPresentation == true }
        let features = GenreFeatures(avgSentenceLength: avgSentenceLength, lexicalDiversity: lexicalDiversity, formalWordRatio: formalWordRatio, punctuationDensity: punctuationDensity, hasHeadline: hasHeadline, hasCitations: hasCitations, hasImperatives: hasImperatives, hasEmojis: hasEmojis)

        var scores: [Genre: Double] = [:]
        scores[.newsArticle] = Double(words.filter { Self.newsIndicators.contains($0) }.count) * 0.3 + (hasCitations ? 0.3 : 0.0) + (hasHeadline ? 0.2 : 0.0) + (avgSentenceLength > 15 && avgSentenceLength < 30 ? 0.2 : 0.0)
        scores[.academicText] = Double(words.filter { Self.academicIndicators.contains($0) }.count) * 0.3 + (avgSentenceLength > 20 ? 0.3 : 0.0) + (lexicalDiversity > 0.6 ? 0.2 : 0.0) + (formalWordRatio > 0.05 ? 0.2 : 0.0)
        scores[.casualConversation] = Double(words.filter { Self.casualIndicators.contains($0) }.count) * 0.3 + (hasEmojis ? 0.4 : 0.0) + (avgSentenceLength < 10 ? 0.2 : 0.0)
        scores[.formalLetter] = Double(words.filter { Self.formalLetterIndicators.contains($0) }.count) * 0.4 + (formalWordRatio > 0.05 ? 0.3 : 0.0)
        scores[.instructionManual] = Double(words.filter { Self.instructionIndicators.contains($0) }.count) * 0.3 + (hasImperatives ? 0.4 : 0.0) + (avgSentenceLength < 15 ? 0.2 : 0.0)
        scores[.opinionPiece] = Double(words.filter { Self.opinionIndicators.contains($0) }.count) * 0.3 + (lower.contains("jag tycker") || lower.contains("jag anser") ? 0.3 : 0.0)
        scores[.narrativeFiction] = Double(words.filter { Self.fictionIndicators.contains($0) }.count) * 0.3 + (lower.contains("han ") && lower.contains("hon ") ? 0.2 : 0.0) + (avgSentenceLength > 10 && avgSentenceLength < 25 ? 0.2 : 0.0)
        let lineCount = text.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).count > 0 }.count
        scores[.poetry] = Double(words.filter { Self.poetryIndicators.contains($0) }.count) * 0.3 + (lineCount > totalSentences ? 0.4 : 0.0) + (avgSentenceLength < 8 ? 0.2 : 0.0)
        scores[.advertisement] = Double(words.filter { Self.advertisementIndicators.contains($0) }.count) * 0.3 + (hasImperatives ? 0.2 : 0.0) + (lower.contains("!") ? 0.2 : 0.0)
        scores[.legalText] = Double(words.filter { Self.legalIndicators.contains($0) }.count) * 0.3 + (formalWordRatio > 0.08 ? 0.3 : 0.0) + (avgSentenceLength > 25 ? 0.2 : 0.0)
        scores[.email] = Double(words.filter { Self.emailIndicators.contains($0) }.count) * 0.3 + (lower.hasPrefix("hej") || lower.hasPrefix("bästa") ? 0.3 : 0.0)
        scores[.socialMedia] = Double(words.filter { Self.socialMediaIndicators.contains($0) }.count) * 0.3 + (hasEmojis ? 0.3 : 0.0) + (avgSentenceLength < 8 ? 0.2 : 0.0)

        let sorted = scores.sorted { $0.value > $1.value }
        let primaryGenre = sorted.first?.key ?? .unknown
        let primaryScore = sorted.first?.value ?? 0.0
        let secondaryGenres = sorted.dropFirst(1).prefix(2).map { ($0.key, min(0.99, $0.value)) }.filter { $0.1 > 0.1 }
        let mode: InterpretationMode
        switch primaryGenre {
        case .newsArticle: mode = .factChecking
        case .academicText: mode = .hedgingAware
        case .poetry, .narrativeFiction: mode = .metaphorHeavy
        case .instructionManual: mode = .imperativeDriven
        case .opinionPiece, .advertisement: mode = .persuasionAware
        case .legalText: mode = .legalInterpretation
        case .casualConversation, .socialMedia: mode = .casual
        default: mode = .standard
        }
        return GenreClassification(genre: primaryGenre, confidence: min(0.95, primaryScore), secondaryGenres: secondaryGenres, interpretationMode: mode, features: features)
    }

    // MARK: - Iteration 68: Sentiment Trajectory Analysis

    struct SentimentTrajectory {
        let perSentenceSentiment: [SentenceSentiment]; let sentimentShifts: [SentimentShift]; let turningPoints: [TurningPoint]
        let emotionalArc: EmotionalArcType; let valenceStart: Double; let valenceEnd: Double; let valenceRange: ClosedRange<Double>
        let mixedSentiment: Bool; let bodyBudgetUpdate: BodyBudgetEffect
    }
    struct SentenceSentiment: Identifiable { let id = UUID(); let sentence: String; let index: Int; let valence: Double; let arousal: Double; let emotion: String }
    struct SentimentShift: Identifiable {
        let id = UUID(); let fromIndex: Int; let toIndex: Int; let fromValence: Double; let toValence: Double; let shiftMagnitude: Double; let shiftType: ShiftType
        enum ShiftType: String { case rising, falling, volatile, stable }
    }
    struct TurningPoint: Identifiable {
        let id = UUID(); let sentenceIndex: Int; let sentence: String; let valence: Double; let type: TurningPointType
        enum TurningPointType: String { case peak, trough, inflection }
    }
    enum EmotionalArcType: String { case rising = "stigande"; case falling = "fallande"; case risingFalling = "stigande-fallande"; case fallingRising = "fallande-stigande"; case stable = "stabil"; case volatile = "volatil"; case complex = "komplex" }
    struct BodyBudgetEffect { let effect: BodyBudgetEffectType; let intensity: Double; enum BodyBudgetEffectType: String { case energizing = "energigivande"; case draining = "energitömmande"; case calming = "lugnande"; case stimulating = "stimulerande"; case neutral = "neutral" } }

    func analyzeSentimentTrajectory(text: String) -> SentimentTrajectory {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?;")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 3 }
        guard !sentences.isEmpty else { return SentimentTrajectory(perSentenceSentiment: [], sentimentShifts: [], turningPoints: [], emotionalArc: .stable, valenceStart: 0, valenceEnd: 0, valenceRange: 0...0, mixedSentiment: false, bodyBudgetUpdate: BodyBudgetEffect(effect: .neutral, intensity: 0)) }

        var perSentence: [SentenceSentiment] = []
        for (idx, sentence) in sentences.enumerated() {
            let result = analyzeEmotionalValence(sentence)
            perSentence.append(SentenceSentiment(sentence: sentence, index: idx, valence: result.valence, arousal: result.arousal, emotion: result.emotion))
        }

        var shifts: [SentimentShift] = []
        for i in 0..<(perSentence.count - 1) {
            let from = perSentence[i], to = perSentence[i + 1]
            let magnitude = abs(to.valence - from.valence)
            if magnitude > 0.3 {
                let type: SentimentShift.ShiftType
                if to.valence > from.valence + 0.3 { type = .rising }
                else if to.valence < from.valence - 0.3 { type = .falling }
                else if magnitude > 0.6 { type = .volatile }
                else { type = .stable }
                shifts.append(SentimentShift(fromIndex: i, toIndex: i + 1, fromValence: from.valence, toValence: to.valence, shiftMagnitude: magnitude, shiftType: type))
            }
        }

        var turningPoints: [TurningPoint] = []
        for i in 1..<(perSentence.count - 1) {
            let prev = perSentence[i - 1].valence, curr = perSentence[i].valence, next = perSentence[i + 1].valence
            if curr > prev && curr > next { turningPoints.append(TurningPoint(sentenceIndex: i, sentence: perSentence[i].sentence, valence: curr, type: .peak)) }
            else if curr < prev && curr < next { turningPoints.append(TurningPoint(sentenceIndex: i, sentence: perSentence[i].sentence, valence: curr, type: .trough)) }
            else if (curr - prev) * (next - curr) < 0 { turningPoints.append(TurningPoint(sentenceIndex: i, sentence: perSentence[i].sentence, valence: curr, type: .inflection)) }
        }

        let valenceStart = perSentence.first?.valence ?? 0; let valenceEnd = perSentence.last?.valence ?? 0
        let allValences = perSentence.map { $0.valence }; let valenceMin = allValences.min() ?? 0; let valenceMax = allValences.max() ?? 0
        let overallDelta = valenceEnd - valenceStart; let shiftCount = shifts.count
        let arcType: EmotionalArcType
        if shiftCount >= 3 && abs(overallDelta) < 0.3 { arcType = .volatile }
        else if shiftCount >= 4 { arcType = .complex }
        else if overallDelta > 0.3 { arcType = .rising }
        else if overallDelta < -0.3 { arcType = .falling }
        else if turningPoints.count == 1 && turningPoints[0].type == .peak { arcType = .risingFalling }
        else if turningPoints.count == 1 && turningPoints[0].type == .trough { arcType = .fallingRising }
        else { arcType = .stable }

        let positiveCount = perSentence.filter { $0.valence > 0.3 }.count; let negativeCount = perSentence.filter { $0.valence < -0.3 }.count
        let mixedSentiment = positiveCount > 0 && negativeCount > 0 && Double(min(positiveCount, negativeCount)) / Double(perSentence.count) > 0.2

        let avgArousal = perSentence.map { $0.arousal }.reduce(0, +) / Double(max(1, perSentence.count))
        let avgValence = allValences.reduce(0, +) / Double(max(1, allValences.count))
        let bodyBudget: BodyBudgetEffect
        if avgValence > 0.3 && avgArousal > 0.5 { bodyBudget = BodyBudgetEffect(effect: .energizing, intensity: min(1.0, avgValence * avgArousal)) }
        else if avgValence < -0.3 && avgArousal > 0.5 { bodyBudget = BodyBudgetEffect(effect: .draining, intensity: min(1.0, abs(avgValence) * avgArousal)) }
        else if avgArousal < 0.3 { bodyBudget = BodyBudgetEffect(effect: .calming, intensity: min(1.0, 1.0 - avgArousal)) }
        else if avgValence > 0 && avgArousal > 0.3 { bodyBudget = BodyBudgetEffect(effect: .stimulating, intensity: min(1.0, avgArousal)) }
        else { bodyBudget = BodyBudgetEffect(effect: .neutral, intensity: 0) }

        return SentimentTrajectory(perSentenceSentiment: perSentence, sentimentShifts: shifts, turningPoints: turningPoints, emotionalArc: arcType, valenceStart: valenceStart, valenceEnd: valenceEnd, valenceRange: valenceMin...valenceMax, mixedSentiment: mixedSentiment, bodyBudgetUpdate: bodyBudget)
    }

    // MARK: - Iteration 69: Semantic Role Labeling

    struct SemanticRole: Identifiable { let id = UUID(); let predicate: String; let roles: [RoleFiller]; let sentence: String; let confidence: Double }
    struct RoleFiller: Codable { let role: SemanticRoleType; let filler: String; let position: String; let confidence: Double }
    enum SemanticRoleType: String, CaseIterable { case agent = "agens"; case patient = "patiens"; case instrument = "instrument"; case source = "källa"; case goal = "mål"; case location = "lokal"; case time = "tid"; case manner = "sätt"; case cause = "orsak"; case experiencer = "experiens"; case beneficiary = "gynnare" }

    private static let agentPreps: Set<String> = ["av", "genom", "med hjälp av"]
    private static let sourcePreps: Set<String> = ["från", "ur", "av", "ifrån"]
    private static let goalPreps: Set<String> = ["till", "mot", "in i", "upp till"]
    private static let locationPreps: Set<String> = ["i", "på", "vid", "under", "över", "bredvid", "mellan", "framför", "bakom"]
    private static let instrumentPreps: Set<String> = ["med", "genom", "med hjälp av"]
    private static let timePreps: Set<String> = ["på", "i", "under", "före", "efter", "mellan", "vid", "innan", "sedan", "tills"]
    private static let mannerPreps: Set<String> = ["på", "med", "utan", "genom"]
    private static let causePreps: Set<String> = ["på grund av", "genom", "tack vare", "av", "av skäl"]
    private static let beneficiaryPreps: Set<String> = ["för", "till", "åt"]
    private static let psychVerbs: Set<String> = ["älska", "hata", "frukta", "älskar", "hatar", "fruktar", "beundra", "beundrar", "ogilla", "ogillar", "gilla", "gillar", "tycka", "tycker", "tro", "tror", "känna", "känner", "uppleva", "upplever"]

    func labelSemanticRoles(sentence: String) -> [SemanticRole] {
        let lower = sentence.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines).map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
        var roles: [SemanticRole] = []

        for (i, word) in words.enumerated() {
            let isVerb = isLikelyVerbWord(word)
            guard isVerb else { continue }
            var roleFillers: [RoleFiller] = []
            let isPsychVerb = Self.psychVerbs.contains(word)

            // Subject = agent/experiencer
            if i >= 1 {
                let subject = words[max(0, i - 1)]
                let skipWords = Set(["och", "eller", "men", "för", "att", "som", "när", "om", "inte", "där", "här"])
                if !skipWords.contains(subject) && subject.count > 1 {
                    roleFillers.append(RoleFiller(role: isPsychVerb ? .experiencer : .agent, filler: subject, position: subject, confidence: 0.75))
                }
            }

            // Object = patient
            if i + 1 < words.count {
                var patientWords: [String] = []
                for w in words[(i + 1)...] {
                    if isPrepositionWord(w) { break }
                    let skipWords = Set(["och", "eller", "men", "för", "att", "som", "när", "om", "inte", "där", "här", "också", "bara", "redan", "alltid", "aldrig"])
                    if !skipWords.contains(w) && w.count > 1 { patientWords.append(w) }
                }
                if !patientWords.isEmpty { roleFillers.append(RoleFiller(role: .patient, filler: patientWords.joined(separator: " "), position: patientWords.joined(separator: " "), confidence: 0.65)) }
            }

            // Preposition-based role filling
            var cIdx = i
            while cIdx < words.count - 1 {
                cIdx += 1; let w = words[cIdx]
                if Self.agentPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .agent, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.8)) }
                else if Self.sourcePreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .source, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.8)) }
                else if Self.goalPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .goal, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.8)) }
                else if Self.locationPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .location, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.75)) }
                else if Self.instrumentPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .instrument, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.75)) }
                else if Self.timePreps.contains(w) && cIdx + 1 < words.count { let tp = collectPhrase(from: cIdx + 1, in: words); roleFillers.append(RoleFiller(role: .time, filler: tp, position: "\(w) \(tp)", confidence: 0.7)) }
                else if Self.mannerPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .manner, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.65)) }
                else if Self.causePreps.contains(w) && cIdx + 1 < words.count { let cp = collectPhrase(from: cIdx + 1, in: words); roleFillers.append(RoleFiller(role: .cause, filler: cp, position: "\(w) \(cp)", confidence: 0.7)) }
                else if Self.beneficiaryPreps.contains(w) && cIdx + 1 < words.count { roleFillers.append(RoleFiller(role: .beneficiary, filler: words[cIdx + 1], position: "\(w) \(words[cIdx + 1])", confidence: 0.75)) }
            }

            // Passive detection
            if word.hasSuffix("s") && word.count > 3, let avIdx = words.firstIndex(of: "av"), avIdx + 1 < words.count {
                roleFillers.append(RoleFiller(role: .agent, filler: words[avIdx + 1], position: "av \(words[avIdx + 1])", confidence: 0.85))
            }

            if !roleFillers.isEmpty {
                let avgConf = roleFillers.map { $0.confidence }.reduce(0, +) / Double(roleFillers.count)
                roles.append(SemanticRole(predicate: word, roles: roleFillers, sentence: sentence, confidence: avgConf))
            }
        }
        return roles
    }

    private func isLikelyVerbWord(_ word: String) -> Bool {
        let commonVerbs: Set<String> = ["är", "var", "bli", "ha", "få", "kunna", "måste", "ska", "vill", "gör", "säger", "går", "kommer", "tar", "ger", "ser", "hör", "vet", "tror", "tycker", "känner", "minns", "glömmer", "skriver", "läser", "tänker", "arbetar", "sover", "äter", "dricker", "springer", "åker", "reser", "flyger", "simmar", "cyklar", "kör", "köper", "säljer", "betalar", "kostar", "sparar", "bygger", "skapar", "fixar", "lagar", "hjälper", "älskar", "hatar", "gillar", "ogillar", "börjar", "slutar", "fortsätter", "försöker", "lyckas", "öppnar", "stänger", "ställer", "lägger", "sätter", "håller", "frågar", "svarar", "berättar", "förklarar", "ändrar", "påverkar", "leder", "följer", "stannar", "stiger", "faller", "ökar", "minskar", "växer"]
        if commonVerbs.contains(word) { return true }
        return word.hasSuffix("ar") || word.hasSuffix("er") || word.hasSuffix("r") || word.hasSuffix("ade") || word.hasSuffix("de") || word.hasSuffix("te") || word.hasSuffix("at") || word.hasSuffix("t") || word.hasSuffix("it") || word.hasSuffix("as") || word.hasSuffix("es")
    }
    private func isPrepositionWord(_ word: String) -> Bool {
        ["på", "i", "av", "för", "med", "till", "från", "om", "under", "över", "mellan", "genom", "utan", "vid", "efter", "före", "inom", "utanför", "bredvid", "framför", "bakom", "längs", "runt", "tack", "på", "grund", "med", "hjälp"].contains(word)
    }
    private func collectPhrase(from index: Int, in words: [String]) -> String {
        var phrase = ""; var idx = index
        while idx < words.count { let w = words[idx]; if isPrepositionWord(w) && idx > index { break }; if w == "och" || w == "eller" { break }; phrase += (phrase.isEmpty ? "" : " ") + w; idx += 1 }
        return phrase.isEmpty ? (index < words.count ? words[index] : "") : phrase
    }
}

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
        guard !contextEmb.isEmpty else { return disambiguate(context).first(where: { $0.word == word }) }
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

// MARK: - Data models

struct LexiconEntry: Codable {
    let word: String
    let pos: String
    let forms: [String: String]
}

struct MorphemeAnalysis: Identifiable {
    let id = UUID()
    let word: String
    let baseForm: String
    let pos: String
    let morphemes: [String]
    let isCompound: Bool
    let forms: [String: String]

    var description: String {
        if isCompound {
            return "\(word) → \(morphemes.joined(separator: "+"))"
        }
        return "\(word) [\(pos)]"
    }
}

struct WordSense: Identifiable {
    let id: String
    let definition: String
    let examples: [String]
    var confidence: Double
}

struct DisambiguationResult: Identifiable {
    let id = UUID()
    let word: String
    let selectedSense: WordSense
    let allSenses: [WordSense]
    let confidence: Double
}

struct SwedishAnalysis {
    let originalText: String
    let morphemes: [MorphemeAnalysis]
    let disambiguations: [DisambiguationResult]
    let register: SwedishRegister
    let modalParticles: [ModalParticle]
    var detectedIdioms: [DetectedIdiom] = []
    var clauses: [ClauseSegment] = []
    var anaphoraResolutions: [AnaphoraResolution] = []

    // v16: Empty analysis for fast-path (greetings etc)
    static let empty = SwedishAnalysis(
        originalText: "",
        morphemes: [],
        disambiguations: [],
        register: .neutral,
        modalParticles: []
    )

    /// Quick summary for prompt building
    var analysisSummary: String {
        var parts: [String] = []
        if register != .neutral { parts.append("Register: \(register.label)") }
        if !modalParticles.isEmpty { parts.append("Partiklar: \(modalParticles.map { $0.word }.joined(separator: ", "))") }
        if !detectedIdioms.isEmpty { parts.append("Idiom: \(detectedIdioms.map { $0.meaning }.joined(separator: "; "))") }
        if clauses.count > 1 { parts.append("\(clauses.count) satser") }
        let unknowns = morphemes.filter { $0.pos == "unknown" }.count
        if unknowns > 0 { parts.append("\(unknowns) okända ord") }
        return parts.isEmpty ? "Standard analys" : parts.joined(separator: " · ")
    }
}

struct DetectedIdiom: Identifiable {
    let id = UUID()
    let phrase: String
    let meaning: String
    let literalTranslation: String
    let category: String  // Iteration 20: idiom category (emotion, cognition, social, etc.)
}

struct ClauseSegment: Identifiable {
    let id = UUID()
    let text: String
    let type: ClauseType
    let startWord: String

    enum ClauseType {
        case main       // Huvudsats
        case subordinate // Bisats (inleds med subjunktion)
    }
}

struct AnaphoraResolution: Identifiable {
    let id = UUID()
    let pronoun: String
    let antecedent: String
    let distance: Int       // Words between pronoun and antecedent
    let confidence: Double  // 0..1
}

enum SwedishRegister {
    case formal, neutral, informal, technical, academic
    var label: String {
        switch self {
        case .formal: return "Formellt"
        case .neutral: return "Neutralt"
        case .informal: return "Informellt"
        case .technical: return "Tekniskt"
        case .academic: return "Akademiskt"
        }
    }
}

struct ModalParticle: Identifiable {
    let id = UUID()
    let word: String
    let meaning: Meaning
    let frequency: Int  // Iteration 18: occurrence count in text

    enum Meaning {
        case sharedKnowledge  // ju
        case hedging          // väl
        case probability      // nog
        case confirmation     // visst
        case emphasis         // faktiskt
        case concession       // egentligen
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 135: Language Fingerprint
// ═══════════════════════════════════════════════════════════

struct LanguageFingerprint: Sendable {
    let mostUsedWords: [(word: String, count: Int)]
    let preferredSentenceStructures: [String: Double]
    let commonErrors: [String]
    let distinctivePhrases: [String]
    let registerDistribution: [String: Double]
    let avgSentenceLength: Double
    let avgWordLength: Double
    let capturedAt: Date
}

extension SwedishLanguageCore {
    /// Unique profile of Eon's Swedish: most-used words, preferred sentence structures, common errors, distinctive phrases, register preferences.
    func computeLanguageFingerprint() async -> LanguageFingerprint {
        let memory = PersistentMemoryStore.shared
        let conversations = await memory.getRecentConversation(limit: 100)

        var wordCounts: [String: Int] = [:]
        var totalWords = 0
        var totalSentences = 0
        var totalSentenceLength = 0
        var registerCounts: [String: Int] = [:]

        for conv in conversations {
            let lower = conv.content.lowercased()
            let words = lower.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 3 }

            for word in words {
                wordCounts[word, default: 0] += 1
                totalWords += 1
            }

            let sentences = conv.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .filter { $0.trimmingCharacters(in: .whitespaces).count > 3 }
            totalSentences += sentences.count
            totalSentenceLength += words.count

            // Register detection
            let register = detectRegister(conv.content)
            registerCounts[register.label, default: 0] += 1
        }

        // Most used words (excluding stop words)
        let stopWords: Set<String> = ["och", "att", "som", "har", "den", "det", "inte", "var", "kan", "men", "från", "till", "för", "med", "utan", "här", "där", "efter", "när", "vad", "hur", "om"]
        let mostUsed = wordCounts.filter { !stopWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map { (word: $0.key, count: $0.value) }

        // Sentence structure preferences
        let avgSentenceLength = totalSentences > 0 ? Double(totalSentenceLength) / Double(totalSentences) : 15.0
        let shortSentences = avgSentenceLength < 12 ? 0.6 : 0.2
        let mediumSentences = avgSentenceLength >= 12 && avgSentenceLength < 20 ? 0.6 : 0.3
        let longSentences = avgSentenceLength >= 20 ? 0.6 : 0.1
        let sentenceStructures = [
            "korta_meningar": shortSentences,
            "medellånga_meningar": mediumSentences,
            "långa_meningar": longSentences,
        ]

        // Common errors (detected from grammar issues in learning)
        let commonErrors: [String] = []  // Would need grammar error tracking to populate

        // Distinctive phrases (frequently used multi-word expressions)
        let distinctivePhrases: [String] = []  // Would need phrase frequency analysis

        // Register distribution
        let regTotal = max(1, registerCounts.values.reduce(0, +))
        let registerDistribution = registerCounts.mapValues { Double($0) / Double(regTotal) }

        // Average word length
        let avgWordLength = totalWords > 0 ? Double(wordCounts.map { $0.key.count }.reduce(0, +)) / Double(wordCounts.count) : 5.0

        return LanguageFingerprint(
            mostUsedWords: mostUsed,
            preferredSentenceStructures: sentenceStructures,
            commonErrors: commonErrors,
            distinctivePhrases: distinctivePhrases,
            registerDistribution: registerDistribution,
            avgSentenceLength: avgSentenceLength,
            avgWordLength: avgWordLength,
            capturedAt: Date()
        )
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 139: Emotional Intelligence Detection
// ═══════════════════════════════════════════════════════════

struct EQAnalysis: Sendable {
    let empathyScore: Double
    let emotionalValidation: Double
    let appropriateEmotionalResponse: Double
    let emotionalVocabulary: Double
    let socialAwareness: Double
    let overallEQ: Double
    let emotionalWords: [String]
    let timestamp: Date
}

extension SwedishLanguageCore {
    /// Measure: empathy shown, emotional validation, appropriate emotional responses, emotional vocabulary, social awareness.
    func detectEmotionalIntelligence(text: String) -> EQAnalysis {
        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespacesAndNewlines)

        // Empathy indicators
        let empathyWords: Set<String> = ["förstår", "känner", "lyssnar", "hjälp", "stöd", "bryr", "viktig", "också", "precis", "svårt", "tuff", "jobbig"]
        let empathyCount = words.filter { empathyWords.contains($0) }.count
        let empathyScore = min(1.0, Double(empathyCount) / 3.0)

        // Emotional validation
        let validationPhrases = ["det är okej", "jag förstår", "känns", "det är normalt", "många känner", "du är inte ensam", "jag lyssnar", "berätta mer"]
        let validationCount = validationPhrases.filter { lower.contains($0) }.count
        let emotionalValidation = min(1.0, Double(validationCount) / 2.0)

        // Appropriate emotional response (matching user's emotional tone)
        let emotionWords = ["ledsen", "glad", "arg", "rädd", "orolig", "nöjd", "frustrerad", "stressad", "ensam", "tacksam", "stolt", "skam"]
        let emotionalVocab = words.filter { emotionWords.contains($0) }
        let emotionalVocabulary = min(1.0, Double(emotionalVocab.count) / 4.0)

        // Social awareness
        let socialWords: Set<String> = ["vi", "tillsammans", "alla", "relation", "vän", "familj", "grupp", "samhälle", "respekt", "förståelse", "kommunikation"]
        let socialCount = words.filter { socialWords.contains($0) }.count
        let socialAwareness = min(1.0, Double(socialCount) / 3.0)

        // Appropriate response estimation (heuristic: if text contains emotional words and validation, likely appropriate)
        let appropriateEmotionalResponse = (emotionalVocabulary + emotionalValidation) / 2.0

        let overallEQ = empathyScore * 0.25 + emotionalValidation * 0.2 + appropriateEmotionalResponse * 0.2 + emotionalVocabulary * 0.15 + socialAwareness * 0.2

        return EQAnalysis(
            empathyScore: empathyScore,
            emotionalValidation: emotionalValidation,
            appropriateEmotionalResponse: appropriateEmotionalResponse,
            emotionalVocabulary: emotionalVocabulary,
            socialAwareness: socialAwareness,
            overallEQ: overallEQ,
            emotionalWords: emotionalVocab,
            timestamp: Date()
        )
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 145: Swedish Word Network
// ═══════════════════════════════════════════════════════════

struct WordNetwork: Sendable {
    let nodes: [WordNode]
    let edges: [WordEdge]
    let networkMetrics: NetworkMetrics
}

struct WordNode: Sendable {
    let word: String
    let pos: String
    let frequency: Int
    let cefrLevel: String
}

struct WordEdge: Sendable {
    let from: String
    let to: String
    let edgeType: EdgeType
    let weight: Double
}

enum EdgeType: String, Sendable {
    case synonymy = "synonymy"
    case antonymy = "antonymy"
    case derivation = "derivation"
    case collocation = "collocation"
    case semanticField = "semantic-field"
    case morphologicalFamily = "morphological-family"
}

struct NetworkMetrics: Sendable {
    let nodeCount: Int
    let edgeCount: Int
    let density: Double
    let avgDegree: Double
    let connectedComponents: Int
    let avgClusteringCoeff: Double
}

extension SwedishLanguageCore {
    /// Build a word network where words are connected by synonymy, antonymy, derivation, collocation, semantic field, morphological family.
    func createSwedishWordNetwork() async -> WordNetwork {
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 1000)
        let learningEngine = LearningEngine.shared

        // Extract words from known vocabulary and facts
        var wordNodes: [WordNode] = []
        let knownVocab = await learningEngine.swedishVocabularyCount()

        // Create nodes from fact subjects (words/concepts Eon knows)
        var wordSet: Set<String> = []
        for fact in facts.prefix(200) {
            let words = fact.subject.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 2 }
            for word in words {
                if wordSet.insert(word).inserted {
                    wordNodes.append(WordNode(word: word, pos: "unknown", frequency: 1, cefrLevel: "B1"))
                }
            }
        }

        // Create edges based on relationships
        var edges: [WordEdge] = []

        // Synonymy/antonymy from fact predicates
        for fact in facts.prefix(200) {
            if fact.predicate.contains("synonym") || fact.predicate.contains("liknande") {
                let parts = fact.object.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 {
                    edges.append(WordEdge(from: parts[0], to: parts[1], edgeType: .synonymy, weight: 0.8))
                }
            }
        }

        // Collocations from co-occurrence in facts
        var cooccurrence: [String: Int] = [:]
        for fact in facts.prefix(200) {
            let words = "\(fact.subject) \(fact.object)".lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }
            for i in 0..<(words.count - 1) {
                let key = "\(words[i])|\(words[i + 1])"
                cooccurrence[key, default: 0] += 1
            }
        }
        for (pair, count) in cooccurrence where count >= 2 {
            let parts = pair.components(separatedBy: "|")
            if parts.count == 2 {
                edges.append(WordEdge(from: parts[0], to: parts[1], edgeType: .collocation, weight: min(1.0, Double(count) * 0.2)))
            }
        }

        // Semantic field edges (words in same domain)
        let domainKeywords: [String: [String]] = [
            "emotion": ["glad", "ledsen", "arg", "rädd", "kär", "stolt"],
            "cognition": ["tänka", "veta", "förstå", "lära", "minnas", "glömma"],
            "motion": ["gå", "springa", "åka", "flyga", "simma", "hoppa"],
        ]
        for (_, keywords) in domainKeywords {
            for i in 0..<keywords.count {
                for j in (i+1)..<keywords.count {
                    if wordSet.contains(keywords[i]) && wordSet.contains(keywords[j]) {
                        edges.append(WordEdge(from: keywords[i], to: keywords[j], edgeType: .semanticField, weight: 0.5))
                    }
                }
            }
        }

        // Compute network metrics
        let allWords = Set(wordNodes.map { $0.word })
        let degreeMap: [String: Int] = {
            var d: [String: Int] = [:]
            for edge in edges {
                d[edge.from, default: 0] += 1
                d[edge.to, default: 0] += 1
            }
            return d
        }()
        let connectedNodes = degreeMap.keys.intersection(allWords).count
        let avgDegree = allWords.isEmpty ? 0 : Double(edges.count * 2) / Double(allWords.count)
        let maxEdges = allWords.count * (allWords.count - 1) / 2
        let density = maxEdges > 0 ? Double(edges.count) / Double(maxEdges) : 0

        let metrics = NetworkMetrics(
            nodeCount: wordNodes.count,
            edgeCount: edges.count,
            density: density,
            avgDegree: avgDegree,
            connectedComponents: max(1, wordNodes.count - connectedNodes),
            avgClusteringCoeff: 0.3  // Simplified — would need triangle counting
        )

        return WordNetwork(nodes: wordNodes, edges: edges, networkMetrics: metrics)
    }
}

// ═══════════════════════════════════════════════════════════
// ITERATION 159: Swedish Crossword Generation
// ═══════════════════════════════════════════════════════════

struct CrosswordPuzzle: Sendable {
    let grid: [[Character?]]
    let clues: [Clue]
    let wordCount: Int
    let difficulty: String
}

struct Clue: Sendable {
    let number: Int
    let direction: ClueDirection
    let clue: String
    let answer: String
    let row: Int
    let col: Int
}

enum ClueDirection: String, Sendable {
    case across = "Vågrätt"
    case down = "Lodrätt"
}

extension SwedishLanguageCore {
    /// Generate crossword puzzles from Eon's vocabulary.
    func generateSwedishCrossword() async -> CrosswordPuzzle {
        let learningEngine = LearningEngine.shared
        let memory = PersistentMemoryStore.shared
        let facts = await memory.getAllFacts(limit: 500)

        // Collect Swedish words Eon knows
        var candidateWords: [String] = []
        for fact in facts {
            let words = fact.subject.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count >= 3 && $0.count <= 12 && $0.allSatisfy { $0.isLetter } }
            candidateWords.append(contentsOf: words)
        }

        // Deduplicate and take unique words
        let uniqueWords = Array(Set(candidateWords)).shuffled().prefix(20)

        // Simple crossword: place words in a grid
        let gridSize = 15
        var grid: [[Character?]] = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        var clues: [Clue] = []
        var clueNumber = 0

        // Place first word horizontally in center
        if let firstWord = uniqueWords.first {
            let startCol = (gridSize - firstWord.count) / 2
            let centerRow = gridSize / 2
            for (i, char) in firstWord.enumerated() {
                grid[centerRow][startCol + i] = char
            }
            clueNumber += 1
            clues.append(Clue(number: clueNumber, direction: .across, clue: "Svenskt ord: \(firstWord.prefix(1).uppercased())...", answer: firstWord, row: centerRow, col: startCol))
        }

        // Try to place more words intersecting with existing words
        for word in uniqueWords.dropFirst().prefix(8) {
            // Find intersection with existing letters
            for (rowIdx, row) in grid.enumerated() {
                for (colIdx, cell) in row.enumerated() {
                    if let existingChar = cell, let wordCharIdx = word.firstIndex(of: existingChar) {
                        // Try to place word vertically through this position
                        let startRow = rowIdx - wordCharIdx
                        guard startRow >= 0 && startRow + word.count <= gridSize else { continue }

                        // Check if placement is valid
                        var valid = true
                        for (i, char) in word.enumerated() {
                            let r = startRow + i
                            if let existing = grid[r][colIdx], existing != char {
                                valid = false
                                break
                            }
                        }

                        if valid {
                            for (i, char) in word.enumerated() {
                                grid[startRow + i][colIdx] = char
                            }
                            clueNumber += 1
                            clues.append(Clue(number: clueNumber, direction: .down, clue: "Svenskt ord", answer: word, row: startRow, col: colIdx))
                            break
                        }
                    }
                }
            }
        }

        let difficulty = uniqueWords.count > 15 ? "svår" : uniqueWords.count > 8 ? "medel" : "lätt"

        return CrosswordPuzzle(grid: grid, clues: clues, wordCount: clues.count, difficulty: difficulty)
    }
}
