import Foundation

public struct EqualizerSettings: Codable, Equatable {
    public static let frequencies: [Double] = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    public static let labels = ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    public var enabled = false
    public var gains: [Double] = Array(repeating: 0, count: 10)
    public var preampDB: Double = 0
    public var automaticHeadroom = true
    public init() {}

    public mutating func normalize() {
        gains = (0..<10).map { index in
            let value = gains.indices.contains(index) ? gains[index] : 0
            return value.isFinite ? max(-12, min(12, value)) : 0
        }
        preampDB = preampDB.isFinite ? max(-24, min(0, preampDB)) : 0
    }

    private enum CodingKeys: String, CodingKey { case enabled, gains, preampDB, automaticHeadroom }
    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try data.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        gains = try data.decodeIfPresent([Double].self, forKey: .gains) ?? Array(repeating: 0, count: 10)
        preampDB = try data.decodeIfPresent(Double.self, forKey: .preampDB) ?? 0
        automaticHeadroom = try data.decodeIfPresent(Bool.self, forKey: .automaticHeadroom) ?? true
        normalize()
    }
}

/// Original broad tonal starting points; not headphone correction profiles.
public enum EqualizerPreset: String, CaseIterable, Identifiable {
    case flat, bass, voice, bright, soft
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .flat: return "Phẳng"
        case .bass: return "Âm trầm"
        case .voice: return "Giọng nói"
        case .bright: return "Trong sáng"
        case .soft: return "Êm dịu"
        }
    }
    public var gains: [Double] {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bass: return [4, 4, 3, 1, 0, 0, 0, 0, 0, 0]
        case .voice: return [-3, -3, -2, -1, 0, 2, 3, 2, 0, -1]
        case .bright: return [0, 0, -1, -1, 0, 0, 1, 2, 3, 2]
        case .soft: return [1, 1, 0, 0, 0, -1, -2, -3, -3, -2]
        }
    }
}
