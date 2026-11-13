import CoreAudio

enum DeviceRole: CaseIterable, Identifiable {
    case output, input, effects
    var id: Self { self }
    var title: String {
        switch self { case .output: "Đầu ra"; case .input: "Microphone"; case .effects: "Âm thanh thông báo" }
    }
    var symbol: String {
        switch self { case .output: "speaker.wave.2.fill"; case .input: "mic.fill"; case .effects: "bell.fill" }
    }
    var selector: AudioObjectPropertySelector {
        switch self {
        case .output: kAudioHardwarePropertyDefaultOutputDevice
        case .input: kAudioHardwarePropertyDefaultInputDevice
        case .effects: kAudioHardwarePropertyDefaultSystemOutputDevice
        }
    }
    var scope: AudioObjectPropertyScope { self == .input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput }
}

enum DeviceService {
    static func devices() throws -> [AudioDevice] {
        try HAL.ids(HAL.system, HAL.address(kAudioHardwarePropertyDevices)).compactMap { id in
            let uid = try HAL.string(id, kAudioDevicePropertyDeviceUID)
            guard !uid.hasPrefix("vn.thiendev.mysoundcontrol.aggregate.") else { return nil }
            return AudioDevice(id: id, uid: uid, name: try HAL.string(id, kAudioObjectPropertyName),
                               inputs: try HAL.channelCount(id, scope: kAudioObjectPropertyScopeInput),
                               outputs: try HAL.channelCount(id, scope: kAudioObjectPropertyScopeOutput))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    static func defaultDevice(_ role: DeviceRole) throws -> AudioObjectID {
        try HAL.value(HAL.system, HAL.address(role.selector), initial: AudioObjectID(0))
    }
    static func select(_ id: AudioObjectID, role: DeviceRole) throws {
        try HAL.set(HAL.system, HAL.address(role.selector), id)
    }
    static func volumeProperty(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress? {
        // Some devices expose only channel controls. Do not pretend a master exists for those devices.
        let property = HAL.address(kAudioDevicePropertyVolumeScalar, scope: scope)
        return HAL.settable(id, property) ? property : nil
    }
    static func volume(_ id: AudioObjectID, role: DeviceRole) -> Float32? {
        guard let property = volumeProperty(id, scope: role.scope) else { return nil }
        return try? HAL.value(id, property, initial: Float32(0))
    }
    static func setVolume(_ id: AudioObjectID, role: DeviceRole, volume: Float32) throws {
        guard let property = volumeProperty(id, scope: role.scope) else {
            throw AudioFailure(operation: "Thiết bị không có volume tổng có thể điều chỉnh", status: nil)
        }
        try HAL.set(id, property, max(0, min(1, volume)))
    }
    static func muted(_ id: AudioObjectID, role: DeviceRole) -> Bool? {
        let property = HAL.address(kAudioDevicePropertyMute, scope: role.scope)
        guard HAL.settable(id, property), let value = try? HAL.value(id, property, initial: UInt32(0)) else { return nil }
        return value != 0
    }
    static func setMuted(_ id: AudioObjectID, role: DeviceRole, muted: Bool) throws {
        try HAL.set(id, HAL.address(kAudioDevicePropertyMute, scope: role.scope), UInt32(muted ? 1 : 0))
    }
}
