import XCTest
@testable import Eon_Y

final class ObservabilitySchemaTests: XCTestCase {
    func testMeasurementRoundTripsWithEpistemicStatusAndProvenance() throws {
        let measurement = MeasurementDescriptor(
            id: "integration.proxy",
            label: "Integrationsproxy",
            definition: "Normaliserad proxy för intern koppling.",
            value: 0.42,
            unit: "ratio",
            confidence: 0.61,
            provenance: "OscillatorBank",
            temporalWindow: 60,
            epistemicStatus: .inferred
        )

        let data = try JSONEncoder().encode(measurement)
        let decoded = try JSONDecoder().decode(MeasurementDescriptor.self, from: data)

        XCTAssertEqual(decoded.id, measurement.id)
        XCTAssertEqual(decoded.value, measurement.value, accuracy: 0.0001)
        XCTAssertEqual(decoded.epistemicStatus, .inferred)
        XCTAssertEqual(decoded.provenance, "OscillatorBank")
    }

    func testEventRoundTripsWithStableIdentity() throws {
        let event = EonObservableEvent(
            sessionID: "session-1",
            cycleID: 12,
            sequence: 4,
            source: "ConsciousnessOrchestrator",
            kind: .measurement,
            severity: .info,
            payload: ["metric": "integration.proxy", "value": "0.42"]
        )

        let decoded = try JSONDecoder().decode(EonObservableEvent.self, from: JSONEncoder().encode(event))

        XCTAssertEqual(decoded.eventID, event.eventID)
        XCTAssertEqual(decoded.sessionID, "session-1")
        XCTAssertEqual(decoded.cycleID, 12)
        XCTAssertEqual(decoded.payload["metric"], "integration.proxy")
    }

    func testSnapshotNeverClaimsPhenomenalConsciousness() throws {
        let snapshot = EonCognitiveSnapshot.empty(sessionID: "session-1", cycleID: 1)
        let encoded = try String(data: JSONEncoder().encode(snapshot), encoding: .utf8) ?? ""

        XCTAssertFalse(encoded.localizedCaseInsensitiveContains("qualia"))
        XCTAssertFalse(encoded.localizedCaseInsensitiveContains("proven conscious"))
        XCTAssertEqual(snapshot.claims.first?.epistemicStatus, .observed)
    }

    func testSnapshotBuilderPublishesAllProxyMeasurements() {
        var state = UnifiedConsciousState()
        state.cycleIndex = 7
        state.metrics.integrationProxy = 0.4
        state.metrics.globalAvailability = 0.8

        let snapshot = CognitiveSnapshotBuilder.make(from: state, sessionID: "session-1")

        XCTAssertEqual(snapshot.cycleID, 7)
        XCTAssertEqual(snapshot.measurements.count, 6)
        XCTAssertTrue(snapshot.measurements.allSatisfy { $0.epistemicStatus == .inferred })
        XCTAssertTrue(snapshot.claims.contains { $0.text.contains("qualia") })
    }
}
