import XCTest
@testable import Eon_Y

final class PhenomenalBenchmarkTests: XCTestCase {
    func testBenchmarkIsStrictAndExplicitlyOperational() {
        XCTAssertEqual(PhenomenalBenchmark.cases.count, 8)
        XCTAssertTrue(PhenomenalBenchmark.cases.allSatisfy { $0.requiresHeldOutData })
        let result = PhenomenalBenchmark.emptyResult()
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.limitations.joined().contains("operationella"))
    }
}
