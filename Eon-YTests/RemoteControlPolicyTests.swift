import XCTest
@testable import Eon_Y

final class RemoteControlPolicyTests: XCTestCase {
    func testOnlyAllowlistedParameterKeysAreAccepted() {
        let result = RemoteControlPolicy.sanitize(parameters: [
            "attention.decay": 0.4,
            "shell.command": 1.0,
            "learning.rate": 0.2
        ])

        XCTAssertEqual(result.accepted, ["attention.decay": 0.4])
        XCTAssertEqual(result.rejected, ["shell.command", "learning.rate"])
    }

    func testEmergencyStopIsAlwaysAllowedAsDataOnlyDirective() {
        XCTAssertTrue(RemoteControlDirective.emergencyStop.isAllowed)
    }
}
