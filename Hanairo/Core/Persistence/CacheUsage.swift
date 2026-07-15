import Foundation

nonisolated struct CacheUsage: Equatable, Sendable {
    let byteCount: Int64
    let itemCount: Int
    let capacityBytes: Int64

    var fraction: Double {
        guard capacityBytes > 0 else { return 0 }
        return min(max(Double(byteCount) / Double(capacityBytes), 0), 1)
    }
}
