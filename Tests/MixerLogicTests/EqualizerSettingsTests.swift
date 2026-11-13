import Foundation
import MixerLogic
import Testing

struct EqualizerSettingsTests {
    @Test func legacyPreferencesKeepVolumeMuteFavoriteAndRoute() throws {
        let legacy = Data(#"{"volume":0.42,"muted":true,"favorite":true,"outputUID":"speakers"}"#.utf8)
        let p = try JSONDecoder().decode(MixerPreference.self, from: legacy)
        #expect(p.volume == 0.42 && p.muted && p.favorite && p.outputUID == "speakers")
        #expect(!p.equalizer.enabled && p.equalizer.automaticHeadroom)
        #expect(p.equalizer.gains == Array(repeating: 0, count: 10))
    }

    @Test func malformedBandCountAndRangeAreNormalized() throws {
        let data = Data(#"{"enabled":true,"gains":[99,-99,3],"preampDB":20}"#.utf8)
        let eq = try JSONDecoder().decode(EqualizerSettings.self, from: data)
        #expect(eq.gains == [12, -12, 3, 0, 0, 0, 0, 0, 0, 0])
        #expect(eq.preampDB == 0)
        var dirty = EqualizerSettings()
        dirty.gains = [.nan, .infinity] + Array(repeating: -99, count: 12)
        dirty.preampDB = -.infinity
        dirty.normalize()
        #expect(dirty.gains.count == 10 && dirty.gains[0] == 0 && dirty.gains[2] == -12)
        #expect(dirty.preampDB == 0)
    }

    @Test func independentApplicationEQsRoundTripWithoutChangingMute() throws {
        var a = MixerPreference(), b = MixerPreference()
        a.equalizer.enabled = true
        a.equalizer.gains = EqualizerPreset.bass.gains
        a.equalizer.preampDB = -6
        b.muted = true
        b.equalizer.gains = EqualizerPreset.voice.gains
        let decoded = try JSONDecoder().decode([String: MixerPreference].self,
            from: JSONEncoder().encode(["music": a, "browser": b]))
        #expect(decoded["music"]?.equalizer == a.equalizer)
        #expect(decoded["browser"]?.equalizer == b.equalizer)
        #expect(decoded["browser"]?.muted == true)
    }
}
