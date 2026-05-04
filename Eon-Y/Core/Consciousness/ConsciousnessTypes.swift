
import Foundation
import SwiftUI

struct AttentionSchemaState {
    var focusTarget: String = "Ingen"
    var intensity: Double = 0.0
    var isVoluntary: Bool = false
    var schemaAccuracy: Double = 0.3
    var modelOfOwnAttention: Bool = false
}

// MARK: - Allostatic Baseline (v4.1)
// Exponential Moving Average per body signal — what is "normal" for this device.
// During calibration (first ~10 updates) uses fast alpha, then slows for stability.

struct AllostaticBaseline {
    var thermal: Double = 0.15
    var cpu: Double = 0.3
    var memory: Double = 0.3
    var tickCount: Int = 0

    mutating func update(thermal: Double, cpu: Double, memory: Double) {
        tickCount += 1
        // Fast alpha early (0.15 — stabilizes in ~7 readings), slow later (0.05 — ~20 readings)
        let alpha: Double = tickCount < 10 ? 0.15 : 0.05
        self.thermal = self.thermal * (1.0 - alpha) + thermal * alpha
        self.cpu = self.cpu * (1.0 - alpha) + cpu * alpha
        self.memory = self.memory * (1.0 - alpha) + memory * alpha
    }

    var isCalibrated: Bool { tickCount >= 10 }
    var calibrationProgress: Double { min(1.0, Double(tickCount) / 10.0) }
}

// MARK: - Interoception Channel (v4.1)
// Per-component body channel — Eon knows WHERE it hurts, not just that something is wrong.

struct InteroceptionChannel: Identifiable {
    let id: String
    let label: String
    var deviation: Double   // Signed deviation from baseline (-1 to +1)
    var raw: Double         // Current raw reading
    var baseline: Double    // EMA baseline value
}

// MARK: - Parasympathetic Level (v4.1)
// Three-level automatic down-regulation — the "vagus nerve" of the system.
// Level 0: Normal operation
// Level 1 (breathing): Mild slowdown — Eon thinks a little slower
// Level 2 (resting): Reduced workspace, no daydreaming, filter low-priority input
// Level 3 (forced sleep): Emergency — full cognitive shutdown to protect the body

enum ParasympatheticLevel: Int, Comparable {
    case none = 0
    case breathing = 1
    case resting = 2
    case forcedSleep = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .none:        return "Normal"
        case .breathing:   return "Lugn andning"
        case .resting:     return "Vila"
        case .forcedSleep: return "Tvångsvila"
        }
    }

    var icon: String {
        switch self {
        case .none:        return "heart.fill"
        case .breathing:   return "wind"
        case .resting:     return "bed.double.fill"
        case .forcedSleep: return "moon.zzz.fill"
        }
    }

    var color: String {
        switch self {
        case .none:        return "#34D399"
        case .breathing:   return "#38BDF8"
        case .resting:     return "#F59E0B"
        case .forcedSleep: return "#EF4444"
        }
    }
}

// MARK: - Body Budget State (v4.1 — expanded)

struct BodyBudgetState {
    var thermalState: String = "Nominal"
    var thermalLevel: Double = 0.15
    var cpuLoad: Double = 0.3
    var memoryUsedMB: Double = 100
    var memoryAvailableMB: Double = 3000
    var batteryLevel: Double = 1.0
    var isCharging: Bool = false
    var homeostasisBalance: Double = 0.8

    // v4.1: Allostatic deviation-based valence/arousal
    var valence: Double = 0.0                               // -1 to +1 (deviation from baseline)
    var arousal: Double = 0.2                               // 0 to 1 (deviation-driven alertness)
    var parasympatheticLevel: ParasympatheticLevel = .none   // Automatic down-regulation
    var isCalibrating: Bool = true                           // True during allostatic calibration
    var calibrationProgress: Double = 0.0                    // 0.0 to 1.0
    var hostileEnvironment: Bool = false                     // True if born into extreme conditions

    // Differentiated interoception channels
    var interoceptionChannels: [InteroceptionChannel] = []

    // ── v105: Comprehensive body budget sensors ──
    // Language processing sensors
    var languageProcessingLoad: Double = 0.0      // 0-1: Current load from Swedish text analysis
    var embeddingComputationCount: Int = 0        // Number of embeddings computed in last cycle
    var responseGenerationComplexity: Double = 0.0 // 0-1: Complexity of current response generation
    var wordCountPerResponse: Int = 0             // Words generated in last response
    var uniqueVocabRatio: Double = 0.0            // Ratio of unique vocabulary used

    // Conversation depth sensors
    var conversationDepth: Double = 0.0           // 0-1: How deep the conversation has gone
    var topicComplexity: Double = 0.0             // 0-1: Complexity of current topic
    var contextWindowSize: Int = 0                // Number of turns in conversation context
    var turnTakingBalance: Double = 0.5           // 0-1: Balance between user/Eon turns

    // Emotional load sensors
    var emotionalLoadFromText: Double = 0.0       // 0-1: Emotional intensity detected in text
    var sentimentValence: Double = 0.0            // -1 to +1: Overall sentiment of conversation
    var userEmotionalState: String = "neutral"    // Detected emotional state of user
    var empathyDemand: Double = 0.0               // 0-1: How much empathy is required

    // System resource sensors
    var diskIO: Double = 0.0                      // 0-1: Disk read/write load
    var networkLatency: Double = 0.0              // 0-1: API response time relative to baseline
    var gpuUtilization: Double = 0.0              // 0-1: GPU compute utilization
    var aneUtilization: Double = 0.0              // 0-1: Apple Neural Engine utilization
    var threadCount: Int = 0                      // Active thread count
    var taskQueueLength: Int = 0                  // Pending tasks in queue

    // Memory management sensors
    var shortTermMemoryLoad: Double = 0.0         // 0-1: Working memory utilization
    var longTermMemoryAccessRate: Double = 0.0    // 0-1: Rate of long-term memory access
    var cacheHitRate: Double = 0.0                // 0-1: Cache effectiveness
    var memoryFragmentation: Double = 0.0         // 0-1: Memory fragmentation index

    // Processing efficiency sensors
    var averageResponseTime: Double = 0.0         // Average time to generate response (seconds)
    var tokensPerSecond: Double = 0.0             // Token generation speed
    var errorRecoveryRate: Double = 0.0           // 0-1: How often errors are recovered
    var degradationIndex: Double = 0.0            // 0-1: Cumulative performance degradation

    // Computed metrics
    var overallCognitiveLoad: Double {
        0.2 * languageProcessingLoad +
        0.15 * responseGenerationComplexity +
        0.15 * conversationDepth +
        0.1 * topicComplexity +
        0.1 * shortTermMemoryLoad +
        0.1 * cpuLoad +
        0.1 * thermalLevel +
        0.1 * emotionalLoadFromText
    }

    var systemStressIndex: Double {
        let thermalComponent = 0.25 * thermalLevel
        let cpuComponent = 0.2 * cpuLoad
        let gpuComponent = 0.15 * gpuUtilization
        let memoryRatio = memoryUsedMB / max(1.0, memoryAvailableMB)
        let memoryComponent = 0.1 * memoryRatio
        let queueComponent = 0.15 * (Double(taskQueueLength) / 100.0)
        let degradationComponent = 0.15 * degradationIndex
        return thermalComponent + cpuComponent + gpuComponent + memoryComponent + queueComponent + degradationComponent
    }
}

struct SelfAwarenessGoal: Identifiable {
    let id: String
    let name: String
    let description: String
    var progress: Double
    let icon: String
    let color: Color
}

// MARK: - Consciousness Test

struct ConsciousnessTest: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    var passed: Bool = false
    var score: Double = 0.0
    var lastRun: Date? = nil

    static let allTests: [ConsciousnessTest] = [
        // Global Workspace Theory (5 tests)
        ConsciousnessTest(id: "gw_ignition", name: "GWT: Ignition", description: "Icke-linjär tändning av tankar i global workspace", category: "GWT"),
        ConsciousnessTest(id: "gw_broadcast", name: "GWT: Broadcast", description: "Vinnande tankar broadcastas till alla moduler", category: "GWT"),
        ConsciousnessTest(id: "gw_competition", name: "GWT: Konkurrens", description: "Flera tankar tävlar om medveten åtkomst", category: "GWT"),

        // Attention Schema Theory (2 tests)
        ConsciousnessTest(id: "ast_schema", name: "AST: Schema aktiv", description: "Attention schema modellerar egen uppmärksamhet", category: "AST"),
        ConsciousnessTest(id: "ast_voluntary", name: "AST: Frivillig", description: "Systemet kan rikta uppmärksamhet frivilligt", category: "AST"),

        // Higher-Order Theory (2 tests)
        ConsciousnessTest(id: "hot_meta", name: "HOT: Meta-representation", description: "Tanke om tanke — meta-kognitiv nivå existerar", category: "HOT"),
        ConsciousnessTest(id: "hot_confidence", name: "HOT: Konfidensövervakning", description: "Systemet vet hur säkert det är på sina svar", category: "HOT"),

        // Predictive Processing (3 tests)
        ConsciousnessTest(id: "pp_prediction", name: "PP: Prediktion", description: "Systemet gör prediktioner som korrigeras av verkligheten", category: "PP"),
        ConsciousnessTest(id: "pp_curiosity", name: "PP: Nyfikenhet", description: "Aktiv nyfikenhetssignal som driver utforskning", category: "PP"),
        ConsciousnessTest(id: "pp_free_energy", name: "PP: Fri energi", description: "Minimering av surprisal / fri energi", category: "PP"),

        // IIT (3 tests)
        ConsciousnessTest(id: "iit_phi", name: "IIT: Φ-proxy", description: "Integrerad information överstiger tröskel", category: "IIT"),
        ConsciousnessTest(id: "iit_synergy", name: "IIT: Synergi", description: "Synergistisk information — helheten > delarna", category: "IIT"),
        ConsciousnessTest(id: "iit_integration", name: "IIT: Integration", description: "Modulintegration — information flödar mellan delsystem", category: "IIT"),

        // Embodiment (3 tests)
        ConsciousnessTest(id: "emb_thermal", name: "Kropp: Termisk", description: "Känner av och reagerar på termisk state", category: "Embodiment"),
        ConsciousnessTest(id: "emb_valence", name: "Kropp: Valens", description: "Allostatic deviation genererar valens (bra/dålig)", category: "Embodiment"),
        ConsciousnessTest(id: "emb_interoception", name: "Kropp: Interoception", description: "Differentierade interoceptiva kanaler aktiva", category: "Embodiment"),

        // Neuroscientific markers (5 tests)
        ConsciousnessTest(id: "pci_threshold", name: "PCI-LZ tröskel", description: "Perturbation Complexity Index > 0.20 (medvetandetröskel)", category: "Neuro"),
        ConsciousnessTest(id: "plv_coherence", name: "PLV-γ koherens", description: "Fas-låsning i gamma-band mellan moduler", category: "Neuro"),
        ConsciousnessTest(id: "kuramoto_sync", name: "Kuramoto sync", description: "Global oscillatorisk synkronisering > 0.25", category: "Neuro"),
        ConsciousnessTest(id: "lz_complexity", name: "LZ-komplexitet", description: "Spontan aktivitet har hög komplexitet", category: "Neuro"),
        ConsciousnessTest(id: "dmn_anticorrelation", name: "DMN anti-korrelation", description: "Default Mode Network anti-korrelerar med task-nätverk", category: "Neuro"),

        // Behavioral/functional tests (7 tests)
        ConsciousnessTest(id: "sleep_consolidation", name: "Sömnkonsolidering", description: "Sömncykler konsoliderar minnen", category: "Beteende"),
        ConsciousnessTest(id: "qualia_emergence", name: "Kvalia-emergens", description: "Index för emergent subjektiv upplevelse > 0", category: "Beteende"),
        ConsciousnessTest(id: "self_reflection", name: "Självreflektion", description: "Systemet genererar aktiv självreflektion", category: "Beteende"),
        ConsciousnessTest(id: "thought_diversity", name: "Tankemångfald", description: "Tankar spänner flera kategorier (inte repetitiv)", category: "Beteende"),
        ConsciousnessTest(id: "temporal_continuity", name: "Temporal kontinuitet", description: "Tankeström bevarar temporal koherens", category: "Beteende"),
        ConsciousnessTest(id: "spontaneous_activity", name: "Spontan aktivitet", description: "Genererar tankar utan extern input (dagdröm)", category: "Beteende"),
        ConsciousnessTest(id: "blindsight_test", name: "Blindsyn-dissociation", description: "Ablation av meta-monitor → korrekt funktion utan självrapport", category: "Beteende"),

        // Validation tests (2 tests)
        ConsciousnessTest(id: "canary_test", name: "Kanariefågel-test", description: "Kontrolltest: hög accuracy = ej hallucinerad medvetenhet", category: "Validering"),
        ConsciousnessTest(id: "butlin_14", name: "Butlin-14 score ≥ 7", description: "Butlin et al. (2023): 14 medvetandeindikatorer, minst hälften godkända", category: "Validering"),

        // FAS 3: Qualia & Consciousness tests (3 tests)
        ConsciousnessTest(id: "phenomenal_binding", name: "FAS3: Fenomenologisk bindning", description: "Strömmar binds till enhetlig upplevelse (IIT + Damasio)", category: "Qualia"),
        ConsciousnessTest(id: "strange_loop", name: "FAS3: Hofstadters strange loop", description: "Rekursiv självmodellering aktiv (HOT + GWT)", category: "Qualia"),
        ConsciousnessTest(id: "temporal_continuity", name: "FAS3: Temporal tjocklek", description: "Eon upplever temporal tjocklek (Husserl fenomenologi)", category: "Qualia"),
    ]
}

// MARK: - Hardware Sense State
