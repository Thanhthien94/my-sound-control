import AppKit
import CoreAudio

enum ProcessService {
    static func applications() throws -> [AudioApplication] {
        let objects = try HAL.ids(HAL.system, HAL.address(kAudioHardwarePropertyProcessObjectList))
        var groups: [String: (String, String, [AudioObjectID], pid_t, Bool, Set<AudioObjectID>)] = [:]
        for object in objects {
            guard let pid = try? HAL.value(object, HAL.address(kAudioProcessPropertyPID), initial: pid_t(0)),
                  pid != ProcessInfo.processInfo.processIdentifier, pid > 0 else { continue }
            let app = NSRunningApplication(processIdentifier: pid)
            let bundle = (try? HAL.string(object, kAudioProcessPropertyBundleID)) ?? app?.bundleIdentifier ?? ""
            let key = bundle.isEmpty ? "pid:\(pid)" : bundle
            let playing = (try? HAL.value(object, HAL.address(kAudioProcessPropertyIsRunningOutput), initial: UInt32(0))) == 1
            let existing = groups[key]
            let deviceIDs = (try? HAL.ids(object, HAL.address(kAudioProcessPropertyDevices))) ?? []
            groups[key] = (app?.localizedName ?? bundle.split(separator: ".").last.map(String.init) ?? "Process \(pid)",
                           bundle, (existing?.2 ?? []) + [object], existing?.3 ?? pid, (existing?.4 ?? false) || playing,
                           (existing?.5 ?? []).union(deviceIDs))
        }
        return groups.map { key, value in
            AudioApplication(id: key, name: value.0, bundleID: value.1, processObjects: value.2.sorted(), deviceIDs: value.5.sorted(), pid: value.3, isPlaying: value.4)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
