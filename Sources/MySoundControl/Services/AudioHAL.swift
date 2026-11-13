import CoreAudio
import Foundation

struct AudioFailure: LocalizedError {
    let operation: String
    let status: OSStatus?
    var errorDescription: String? {
        guard let status else { return operation }
        let bytes = (0..<4).map { UInt8(truncatingIfNeeded: UInt32(bitPattern: status) >> (24 - $0 * 8)) }
        let code = bytes.allSatisfy { (32...126).contains($0) } ? String(bytes: bytes, encoding: .ascii)! : "\(status)"
        return "\(operation) (\(code))."
    }
}

enum HAL {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        .init(mSelector: selector, mScope: scope, mElement: element)
    }
    static func check(_ status: OSStatus, _ operation: String) throws {
        if status != noErr { throw AudioFailure(operation: operation, status: status) }
    }
    static func value<T: BitwiseCopyable>(_ object: AudioObjectID, _ property: AudioObjectPropertyAddress, initial: T) throws -> T {
        var property = property
        var result = initial
        var size = UInt32(MemoryLayout<T>.size)
        try withUnsafeMutableBytes(of: &result) {
            try check(AudioObjectGetPropertyData(object, &property, 0, nil, &size, $0.baseAddress!), "Không đọc được thuộc tính âm thanh")
        }
        return result
    }
    static func ids(_ object: AudioObjectID, _ property: AudioObjectPropertyAddress) throws -> [AudioObjectID] {
        var property = property
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(object, &property, 0, nil, &size), "Không đọc được danh sách âm thanh")
        guard size > 0 else { return [] }
        var result = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        try result.withUnsafeMutableBytes {
            try check(AudioObjectGetPropertyData(object, &property, 0, nil, &size, $0.baseAddress!), "Không đọc được danh sách âm thanh")
        }
        return Array(result.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }
    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var property = address(selector)
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try withUnsafeMutablePointer(to: &result) {
            try check(AudioObjectGetPropertyData(object, &property, 0, nil, &size, $0), "Không đọc được tên thiết bị")
        }
        return result?.takeRetainedValue() as String? ?? ""
    }
    static func set<T: BitwiseCopyable>(_ object: AudioObjectID, _ property: AudioObjectPropertyAddress, _ value: T) throws {
        var property = property, value = value
        try withUnsafeBytes(of: &value) {
            try check(AudioObjectSetPropertyData(object, &property, 0, nil, UInt32($0.count), $0.baseAddress!), "Không thay đổi được thiết lập âm thanh")
        }
    }
    static func settable(_ object: AudioObjectID, _ property: AudioObjectPropertyAddress) -> Bool {
        var property = property, result = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(object, &property, &result) == noErr && result.boolValue
    }
    static func channelCount(_ object: AudioObjectID, scope: AudioObjectPropertyScope) throws -> Int {
        var property = address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(object, &property, 0, nil, &size), "Không đọc được số kênh")
        guard size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { memory.deallocate() }
        try check(AudioObjectGetPropertyData(object, &property, 0, nil, &size, memory), "Không đọc được số kênh")
        return UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
