import Foundation

public struct MixerPreference: Codable {
    public var volume: Double = 1
    public var muted = false
    public var favorite = false
    public var outputUID: String = ""
    public var equalizer = EqualizerSettings()
    public init() {}

    private enum CodingKeys: String, CodingKey { case volume, muted, favorite, outputUID, equalizer }
    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        volume = try data.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        muted = try data.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        favorite = try data.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        outputUID = try data.decodeIfPresent(String.self, forKey: .outputUID) ?? ""
        equalizer = try data.decodeIfPresent(EqualizerSettings.self, forKey: .equalizer) ?? EqualizerSettings()
        volume = volume.isFinite ? max(0, min(1, volume)) : 1
    }
}
