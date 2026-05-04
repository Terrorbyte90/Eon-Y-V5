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
    func detectRegister(_ text: String) -> SwedishRegister {
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
