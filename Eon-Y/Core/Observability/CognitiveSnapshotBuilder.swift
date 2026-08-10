import Foundation

enum CognitiveSnapshotBuilder {
    static func make(from state: UnifiedConsciousState, sessionID: String, runtimeMode: String = "autonomous") -> EonCognitiveSnapshot {
        let metrics = state.metrics
        let descriptors = [
            descriptor("integration.proxy", "Integrationsproxy", metrics.integrationProxy, "Normaliserad proxy för intern koppling.", "ConsciousnessOrchestrator"),
            descriptor("workspace.availability", "Workspace-tillgänglighet", metrics.globalAvailability, "Hur ofta broadcast är tillgänglig för delsystem.", "GlobalWorkspaceEngine"),
            descriptor("recurrence.depth", "Rekursionsdjup", metrics.recurrentDepth, "Observerad återkopplingsgrad i cykeln.", "ConsciousnessOrchestrator"),
            descriptor("selfmodel.coupling", "Självmodellkoppling", metrics.selfModelCoupling, "Koppling mellan självmodell och aktuell state.", "MetacognitionCore"),
            descriptor("temporal.continuity", "Temporal kontinuitet", metrics.temporalContinuity, "Kontinuitet mellan efterföljande snapshots.", "ConsciousnessOrchestrator"),
            descriptor("metacognition.calibration", "Metakognitiv kalibrering", metrics.metacognitiveCalibration, "Överensstämmelse mellan confidence och utfall.", "MetacognitionCore")
        ]
        let claims = [
            CognitiveClaim(text: "\(state.globalBroadcast.count) broadcast-kandidater är tillgängliga.", epistemicStatus: .observed, source: "UnifiedConsciousState"),
            CognitiveClaim(text: "Proxy-mätningarna är härledda och säger inte i sig något om qualia.", epistemicStatus: .inferred, source: "MeasurementCatalog")
        ]
        return EonCognitiveSnapshot(
            schemaVersion: 1,
            sessionID: sessionID,
            cycleID: state.cycleIndex,
            timestamp: state.timestamp == .distantPast ? Date() : state.timestamp,
            runtimeMode: runtimeMode,
            measurements: descriptors,
            motorStates: ["workspace": "active", "metacognition": "active"],
            claims: claims,
            qwenState: ["loaded": "unknown", "role": "advisory"]
        )
    }

    private static func descriptor(_ id: String, _ label: String, _ value: Double, _ definition: String, _ provenance: String) -> MeasurementDescriptor {
        MeasurementDescriptor(id: id, label: label, definition: definition, value: value, unit: "ratio",
                              confidence: 0.5, provenance: provenance, temporalWindow: 1, epistemicStatus: .inferred)
    }
}
