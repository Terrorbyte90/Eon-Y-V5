import Foundation

actor PredictionRecordStore {
    static let shared = PredictionRecordStore()
    private var records: [EonPredictionRecord] = []

    func append(_ record: EonPredictionRecord) {
        records.append(record)
        if records.count > 256 { records.removeFirst(records.count - 256) }
    }

    func recent(limit: Int = 32) -> [EonPredictionRecord] { Array(records.suffix(max(1, limit))) }
}
