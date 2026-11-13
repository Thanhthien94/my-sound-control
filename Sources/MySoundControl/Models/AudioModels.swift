import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let inputs: Int
    let outputs: Int
}

struct AudioApplication: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleID: String
    let processObjects: [AudioObjectID]
    let deviceIDs: [AudioObjectID]
    let pid: pid_t
    let isPlaying: Bool
}

struct MixerPreference: Codable {
    var volume: Double = 1
    var muted = false
    var favorite = false
    var outputUID: String = ""
}
