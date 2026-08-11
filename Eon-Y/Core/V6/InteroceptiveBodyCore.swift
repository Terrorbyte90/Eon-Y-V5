import Foundation

struct InteroceptiveBodyCore: Sendable {
    func state(thermal: Double, cpu: Double, memory: Double, sleepPressure: Double = 0) -> EonBodyState {
        let thermal = min(1, max(0, thermal))
        let compute = min(1, max(0, cpu))
        let mem = min(1, max(0, memory))
        let pressure = max(thermal, max(compute, mem))
        return EonBodyState(thermalPressure: thermal, computePressure: compute, memoryPressure: mem, energyBudget: 1 - pressure * 0.8, processingAvailability: 1 - pressure, wakeState: sleepPressure > 0.75 ? "recovery" : "awake", sleepPressure: sleepPressure, cognitiveLoad: pressure, recoveryNeed: pressure * pressure)
    }
}
