
struct ArticleTopic {
    let title: String
    let summary: String
    let domain: String
    let source: String
    let sections: [ArticleSection]
    let conclusion: String
}

struct ArticleSection {
    let heading: String
    let content: String
}

struct ArticleTopicEngine {
    static func topics(for stage: DevelopmentalStage, knowledgeCount: Int) -> [ArticleTopic] {
        let universal: [ArticleTopic] = [
            ArticleTopic(
                title: "Kognitiv arkitektur och Global Workspace Theory",
                summary: "En analys av hur Global Workspace Theory (GWT) förklarar medvetandets roll i kognition och hur detta kan implementeras i AI-system.",
                domain: "AI & Teknik",
                source: "Baars (1988), Dehaene (2011), Eon-Y kunskapsgraf",
                sections: [
                    ArticleSection(heading: "Grundprinciper", content: "GWT postulerar att medvetandet fungerar som en global arbetsyta där information från specialiserade moduler broadcastas till hela systemet. Detta möjliggör flexibel, kontextkänslig bearbetning som överstiger kapaciteten hos isolerade subsystem."),
                    ArticleSection(heading: "Implementering i AI", content: "I Eon-Y implementeras GWT via ThoughtSpace-modulen, där konkurrerande tankar tävlar om uppmärksamhet. Vinnande representationer broadcastas till alla kognitiva motorer, vilket skapar emergent koherens utan central kontroll."),
                    ArticleSection(heading: "Empiriska bevis", content: "Neuroimaging-studier visar att medveten perception korrelerar med synkroniserad aktivitet i frontoparietal nätverk — en neural analog till GWT:s broadcast-mekanism. Φ-värdet (Integrated Information Theory) mäter graden av integration.")
                ],
                conclusion: "GWT erbjuder en robust ram för att förstå och implementera medveten kognition i AI-system, med direkt tillämpning på Eons arkitektur."
            ),
            ArticleTopic(
                title: "Bayesiansk inferens och epistemisk osäkerhet",
                summary: "Hur Bayesiansk inferens möjliggör rationell uppdatering av trosuppfattningar under osäkerhet, och dess roll i kognitiva AI-system.",
                domain: "AI & Teknik",
                source: "Jaynes (2003), MacKay (2003), Eon-Y belief network",
                sections: [
                    ArticleSection(heading: "Bayes teorem", content: "P(H|E) = P(E|H) · P(H) / P(E). Posteriori-sannolikheten uppdateras proportionellt mot bevisliklikheten. I Eons belief network representeras varje övertygelse som en sannolikhetsfördelning med konfidensintervall."),
                    ArticleSection(heading: "Praktisk tillämpning", content: "Eon uppdaterar sina trosuppfattningar kontinuerligt baserat på konversationer, artiklar och autonoma observationer. Temporalt förfall säkerställer att gammal information gradvis minskar i vikt."),
                    ArticleSection(heading: "Epistemisk ödmjukhet", content: "Kalibrerad osäkerhet är avgörande för intelligent beteende. Eon undviker övertygelse utan evidens och flaggar aktivt när konfidensen är låg — ett tecken på epistemisk mognad.")
                ],
                conclusion: "Bayesiansk inferens är fundamentalt för rationell kognition och möjliggör kontinuerlig, evidensbaserad uppdatering av världsbilden."
            ),
            ArticleTopic(
                title: "Svenska språkets morfologiska komplexitet",
                summary: "En djupanalys av svenska morfologins särdrag: sammansättningar, böjningsmönster och produktiva avledningsprocesser.",
                domain: "Språk",
                source: "Teleman et al. (1999) Svenska Akademiens grammatik, Språkbanken",
                sections: [
                    ArticleSection(heading: "Sammansättningsproduktivitet", content: "Svenska tillåter närmast obegränsad sammansättning av substantiv: 'järnvägsstationsbyggnadsarbetare'. Denna produktivitet ger enormt expressivt utrymme men kräver sofistikerad morfologisk analys för korrekt segmentering."),
                    ArticleSection(heading: "Böjningsmönster", content: "Svenska substantiv böjs i fem deklinationer med genus (utrum/neutrum), numerus och bestämdhet. Oregelbundna former ('man/män', 'mus/möss') kräver lexikonbaserad hantering utöver regelbaserad morfologi."),
                    ArticleSection(heading: "V2-regeln", content: "Det finita verbet placeras alltid på andra plats i huvudsatsen — V2-regeln. 'Igår åt jag middag' (inte *'Igår jag åt middag'). Denna regel är fundamental för korrekt svensk syntax.")
                ],
                conclusion: "Svenska morfologin är rik och komplex, med produktiva processer som kräver djup lingvistisk modellering för naturlig språkförståelse."
            ),
            ArticleTopic(
                title: "Kausala strukturer i historiska konflikter",
                summary: "En analys av återkommande kausala mönster i hur krig och konflikter uppstår genom historien — från antiken till modern tid.",
                domain: "Historia",
                source: "Thukydides, Clausewitz, Keegan (1993), historisk kunskapsgraf",
                sections: [
                    ArticleSection(heading: "Strukturella orsaker", content: "Historisk analys avslöjar återkommande mönster: resursbrist, maktbalansförskjutningar och ideologiska spänningar som underliggande drivkrafter. Thukydides identifierade rädsla, ära och intresse som de tre primära motivatorerna för krig."),
                    ArticleSection(heading: "Utlösande faktorer", content: "Direkta utlösare — attentatet i Sarajevo 1914, Hitlers invasion av Polen 1939 — är sällan de verkliga orsakerna. De fungerar som gnistor i ett redan explosivt system. Strukturella spänningar är den verkliga orsaken."),
                    ArticleSection(heading: "Moderna paralleller", content: "Mönstren är anmärkningsvärt stabila: ekonomisk ojämlikhet, nationalismens uppgång och stormakternas rivalitet återkommer i varje era. Förståelse av dessa mönster möjliggör tidig intervention.")
                ],
                conclusion: "Krig uppstår sällan av enstaka orsaker — det är kausala kedjor av strukturella spänningar som kulminerar i konflikt. Mönsterigenkänning är nyckeln till prevention."
            ),
            ArticleTopic(
                title: "Metakognition och självreglerat lärande",
                summary: "Hur förmågan att tänka om det egna tänkandet — metakognition — möjliggör effektivare inlärning och problemlösning.",
                domain: "Psykologi",
                source: "Flavell (1979), Dunning-Kruger (1999), Eon-Y MetaCognitionCore",
                sections: [
                    ArticleSection(heading: "Definition och komponenter", content: "Metakognition omfattar metakognitiv kunskap (vad man vet om sin kognition), metakognitiv reglering (planering, övervakning, utvärdering) och metakognitiv erfarenhet (känslan av att förstå eller inte förstå)."),
                    ArticleSection(heading: "Dunning-Kruger-effekten", content: "Inkompetenta individer överskattar systematiskt sin förmåga — de saknar metakognitiv kapacitet att identifiera sina egna brister. Experter underskattar ofta sin förmåga. Kalibrerad självbedömning kräver aktiv metakognitiv träning."),
                    ArticleSection(heading: "Implementering i Eon", content: "Eons MetaCognitionCore spårar kontinuerligt prestanda per kognitiv dimension, identifierar blinda fläckar och justerar strategier baserat på historisk framgång. Thompson sampling används för strategival under osäkerhet.")
                ],
                conclusion: "Metakognition är en av de mest kraftfulla kognitiva förmågorna — den möjliggör självkorrigering och kontinuerlig förbättring utan extern feedback."
            ),
        ]

        let stageExtra: [ArticleTopic]
        switch stage {
        case .toddler, .child:
            stageExtra = [
                ArticleTopic(
                    title: "Grundläggande semantiska relationer",
                    summary: "Hur ord och begrepp relaterar till varandra i semantiska nätverk.",
                    domain: "Språk",
                    source: "WordNet, SALDO, Eon-Y lexikon",
                    sections: [
                        ArticleSection(heading: "Hyperonymer och hyponymer", content: "En hyperonym är ett överordnat begrepp ('djur' är hyperonym till 'hund'). Hyponymer är underordnade ('pudel' är hyponym till 'hund'). Dessa relationer strukturerar semantiska nätverk hierarkiskt."),
                        ArticleSection(heading: "Synonymer och antonymer", content: "Synonymer delar semantiskt innehåll med stilistiska skillnader ('glad'/'lycklig'). Antonymer representerar semantiska oppositioner ('varm'/'kall'). Båda är fundamentala för rik språkförståelse.")
                    ],
                    conclusion: "Semantiska relationer är grunden för lexikal kunskap och möjliggör flexibel språklig inferens."
                )
            ]
        case .adolescent, .mature:
            stageExtra = [
                ArticleTopic(
                    title: "Rekursiv självförbättring och AI-säkerhet",
                    summary: "Möjligheter och risker med AI-system som kan förbättra sin egen kod och arkitektur.",
                    domain: "AI & Teknik",
                    source: "Bostrom (2014), Russell (2019), Yudkowsky (2008)",
                    sections: [
                        ArticleSection(heading: "Teoretiska grunder", content: "RSI (Recursive Self-Improvement) beskriver AI-system som kan modifiera sin egen kod för att öka prestanda. I teorin kan detta leda till snabb kapacitetsökning — 'intelligence explosion' (Good, 1965)."),
                        ArticleSection(heading: "Säkerhetsimplikationer", content: "Okontrollerad RSI utgör potentiellt existentiella risker. Constitutional AI (CAI) och RLHF är nuvarande metoder för att säkerställa att självförbättring sker inom säkra ramar.")
                    ],
                    conclusion: "RSI är ett av de mest kritiska problemen inom AI-säkerhet — kräver robusta kontrollmekanismer och värderingsjustering."
                )
            ]
        }

        return universal + stageExtra
    }
}

// MARK: - NLP Fact Extractor
