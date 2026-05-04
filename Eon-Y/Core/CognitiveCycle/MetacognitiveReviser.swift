
import Foundation

actor MetacognitiveReviser {
    func revise(original: String, confidence: Double, neuralEngine: NeuralEngineOrchestrator) async -> String {
        // v8: More specific revision instructions based on confidence level
        let specificInstruction: String
        if confidence < 0.40 {
            specificInstruction = "Svaret verkar helt irrelevant eller oförståeligt. Skriv ett nytt, kortfattat svar som direkt adresserar frågan."
        } else if confidence < 0.50 {
            specificInstruction = "Svaret saknar substans eller är för generiskt. Lägg till konkreta fakta, exempel eller resonemang."
        } else {
            specificInstruction = "Svaret kan förbättras — skärp formuleringen, erkänn osäkerhet explicit och lägg till en insikt."
        }

        let revisionPrompt = """
        REVISION: Konfidens \(String(format: "%.0f%%", confidence * 100)).
        Tidigare svar: \(String(original.prefix(400)))

        \(specificInstruction)
        VIKTIGT: Upprepa ALDRIG meningar eller idéer. Varje mening ska vara unik och tillföra nytt.
        Reviderat svar (på svenska):
        """

        let revised = await neuralEngine.generate(prompt: revisionPrompt, maxTokens: 250, temperature: 0.58)
        // v10: generate() already deduplicates, but ensure revision output is clean
        return revised.isEmpty ? original : revised
    }
}

// MARK: - Context & Result models
