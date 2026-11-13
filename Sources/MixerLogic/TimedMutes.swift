/// Ephemeral deadlines only: manual mute and saved volume belong to preferences.
/// ContinuousClock advances across system sleep and is unaffected by wall-clock edits.
public struct TimedMutes {
    private var deadlines: [String: ContinuousClock.Instant] = [:]

    public init() {}

    public mutating func start(_ id: String, seconds: Int, now: ContinuousClock.Instant = .now) {
        guard seconds > 0 else { return }
        deadlines[id] = now.advanced(by: .seconds(seconds))
    }

    public mutating func cancel(_ id: String) { deadlines[id] = nil }
    public mutating func cancelAll() { deadlines.removeAll() }

    /// Remove expired entries and return IDs whose gain must be restored.
    public mutating func expire(now: ContinuousClock.Instant = .now) -> [String] {
        let expired = deadlines.compactMap { $0.value <= now ? $0.key : nil }
        for id in expired { deadlines[id] = nil }
        return expired
    }

    /// Round up so the UI never shows zero while the source is still muted.
    public func remaining(now: ContinuousClock.Instant = .now) -> [String: Int] {
        deadlines.mapValues { deadline in
            let duration = now.duration(to: deadline).components
            return max(0, Int(duration.seconds) + (duration.attoseconds > 0 ? 1 : 0))
        }
    }
}
