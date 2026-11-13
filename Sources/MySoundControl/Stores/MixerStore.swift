import AppKit
import Combine
import CoreAudio
import OSLog
import MixerLogic

@MainActor
final class MixerStore: ObservableObject {
    static let shared = MixerStore()
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var applications: [AudioApplication] = []
    @Published private(set) var defaultIDs: [DeviceRole: AudioObjectID] = [:]
    @Published private(set) var volumes: [DeviceRole: Float] = [:]
    @Published private(set) var mutes: [DeviceRole: Bool] = [:]
    @Published private(set) var preferences: [String: MixerPreference] = [:]
    @Published private(set) var activeIDs: Set<String> = []
    @Published private(set) var peaks: [String: Float] = [:]
    @Published private(set) var clippedFrames: [String: UInt64] = [:]
    @Published private(set) var appErrors: [String: String] = [:]
    @Published private(set) var pendingCleanupCount = 0
    @Published private(set) var muteSecondsRemaining: [String: Int] = [:]
    @Published var errorMessage: String?
    private var sessions: [String: ProcessAudioSession] = [:]
    private var pendingCleanup: [ProcessAudioSession] = []
    private var timer: Timer?
    private var sleepObserver: NSObjectProtocol?
    private var tick = 0
    private var timedMutes = TimedMutes()
    private var idleSince: [String: Date] = [:]
    private var lastCycles: [String: UInt64] = [:]
    private let log = Logger(subsystem: "vn.thiendev.mysoundcontrol", category: "Mixer")
    private let preferenceKey = "mixer.preferences.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: preferenceKey) {
            do { preferences = try JSONDecoder().decode([String: MixerPreference].self, from: data).filter { !$0.key.hasPrefix("pid:") } }
            catch { errorMessage = "Không đọc được thiết lập đã lưu. Bản lưu cũ được giữ nguyên cho tới khi bạn thay đổi thiết lập." }
        }
        refresh()
        // Inventory/health once per second; meters at 10 Hz. No mic monitoring.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.advanceTimedMutes()
                let levels = self.sessions.mapValues(\.peak)
                if self.peaks != levels { self.peaks = levels }
                let clips = self.sessions.mapValues(\.clippedFrames)
                if self.clippedFrames != clips { self.clippedFrames = clips }
                self.tick += 1
                if self.tick % 10 == 0 { self.refresh() }
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopAll() }
        }
    }

    func preference(_ id: String) -> MixerPreference { preferences[id] ?? MixerPreference() }

    func update(_ id: String, _ body: (inout MixerPreference) -> Void) {
        var value = preference(id)
        let wasMuted = value.muted
        let previousEQ = value.equalizer
        body(&value)
        if value.muted != wasMuted { cancelTimedMute(id) }
        value.volume = value.volume.isFinite ? max(0, min(1, value.volume)) : 1
        value.equalizer.normalize()
        preferences[id] = value
        applyGain(id)
        if previousEQ != value.equalizer { sessions[id]?.setEqualizer(value.equalizer) }
        // PIDs are reused by macOS. Never restore a process-only preference onto
        // an unrelated application after relaunch; only bundle identities persist.
        do { UserDefaults.standard.set(try JSONEncoder().encode(preferences.filter { !$0.key.hasPrefix("pid:") }), forKey: preferenceKey) }
        catch { report(error) }
    }

    func isMuted(_ id: String) -> Bool {
        preference(id).muted || muteSecondsRemaining[id] != nil
    }

    func toggleApplicationMute(_ id: String) {
        let shouldMute = !isMuted(id)
        cancelTimedMute(id)
        update(id) { $0.muted = shouldMute }
    }

    func muteTemporarily(_ id: String, seconds: Int) {
        guard activeIDs.contains(id), !preference(id).muted, [30, 60, 120].contains(seconds) else { return }
        timedMutes.start(id, seconds: seconds)
        muteSecondsRemaining = timedMutes.remaining()
        applyGain(id)
    }

    func unmuteNow(_ id: String) {
        cancelTimedMute(id)
        update(id) { $0.muted = false }
    }

    private func cancelTimedMute(_ id: String) {
        timedMutes.cancel(id)
        muteSecondsRemaining[id] = nil
    }

    private func advanceTimedMutes() {
        let expired = timedMutes.expire()
        let remaining = timedMutes.remaining()
        if muteSecondsRemaining != remaining { muteSecondsRemaining = remaining }
        for id in expired { applyGain(id) }
    }

    private func applyGain(_ id: String) {
        sessions[id]?.setGain(Float(isMuted(id) ? 0 : preference(id).volume))
    }

    func refresh() {
        do {
            let updatedDevices = try DeviceService.devices()
            let updatedApps = try ProcessService.applications()
            var defaults: [DeviceRole: AudioObjectID] = [:]
            for role in DeviceRole.allCases { defaults[role] = try DeviceService.defaultDevice(role) }
            for (id, session) in Array(sessions) {
                let app = updatedApps.first { $0.id == id }
                let missing = !updatedDevices.contains { $0.uid == session.outputUID } || !updatedDevices.contains { $0.uid == session.captureUID }
                let defaultChanged = session.followsDefault && defaultIDs[.output] != nil && defaults[.output] != defaultIDs[.output]
                if missing || defaultChanged || app?.processObjects != session.processObjects || app?.deviceIDs != session.sourceDeviceIDs {
                    disable(id)
                    appErrors[id] = "Đường âm thanh đã thay đổi; đã trả về âm gốc. Bật lại để tiếp tục."
                    continue
                }
                if session.faults > 0 {
                    disable(id)
                    appErrors[id] = "Định dạng buffer thay đổi; đã dừng xử lý và trả về âm gốc."
                    continue
                }
                let cycles = session.cycles
                if app?.isPlaying == true && lastCycles[id] == cycles {
                    if idleSince[id] == nil { idleSince[id] = Date() }
                    if let idle = idleSince[id], Date().timeIntervalSince(idle) > 5 {
                        disable(id)
                        appErrors[id] = "Chưa nhận được audio. Kiểm tra quyền ghi âm hệ thống rồi bật lại."
                    }
                } else { idleSince[id] = nil }
                lastCycles[id] = cycles
            }
            if devices != updatedDevices { devices = updatedDevices }
            let sortedApps = updatedApps.sorted {
                let a = preference($0.id).favorite, b = preference($1.id).favorite
                if a != b { return a }
                if $0.isPlaying != $1.isPlaying { return $0.isPlaying }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            if applications != sortedApps { applications = sortedApps }
            if defaultIDs != defaults { defaultIDs = defaults }
            var newVolumes: [DeviceRole: Float] = [:]
            var newMutes: [DeviceRole: Bool] = [:]
            for role in DeviceRole.allCases {
                guard let id = defaults[role] else { continue }
                newVolumes[role] = DeviceService.volume(id, role: role)
                newMutes[role] = DeviceService.muted(id, role: role)
            }
            if volumes != newVolumes { volumes = newVolumes }
            if mutes != newMutes { mutes = newMutes }
        } catch { report(error) }
    }

    func selectDevice(_ id: AudioObjectID, role: DeviceRole) {
        perform { try DeviceService.select(id, role: role); refresh() }
    }
    func setVolume(_ volume: Double, role: DeviceRole) {
        guard let id = defaultIDs[role] else { return }
        perform { try DeviceService.setVolume(id, role: role, volume: Float(volume)); volumes[role] = Float(volume) }
    }
    func toggleMute(_ role: DeviceRole) {
        guard let id = defaultIDs[role], let current = mutes[role] else { return }
        perform { try DeviceService.setMuted(id, role: role, muted: !current); mutes[role] = !current }
    }

    func enable(_ app: AudioApplication) {
        guard sessions[app.id] == nil else { return }
        guard pendingCleanup.isEmpty else {
            appErrors[app.id] = "Cần trả tất cả về âm gốc để dọn phiên trước khi bật mixer mới."
            return
        }
        let preference = preference(app.id)
        let output = preference.outputUID.isEmpty
            ? devices.first { $0.id == defaultIDs[.output] }
            : devices.first { $0.uid == preference.outputUID }
        guard let output else { appErrors[app.id] = "Không tìm thấy đầu ra đã chọn."; return }
        let sources = devices.filter { $0.outputs > 0 && app.deviceIDs.contains($0.id) }
        guard sources.count <= 1 else {
            appErrors[app.id] = "App đang dùng nhiều đầu ra; bản đầu hỗ trợ một nguồn phát cho mỗi app."
            return
        }
        guard let capture = sources.first ?? devices.first(where: { $0.id == defaultIDs[.output] }) else {
            appErrors[app.id] = "Không tìm thấy thiết bị nguồn đang phát."
            return
        }
        let session = ProcessAudioSession(application: app, output: output, capture: capture, followsDefault: preference.outputUID.isEmpty)
        do {
            try session.start(gain: Float(preference.muted ? 0 : preference.volume), equalizer: preference.equalizer)
            sessions[app.id] = session
            activeIDs.insert(app.id)
            appErrors[app.id] = nil
            idleSince[app.id] = nil
            lastCycles[app.id] = nil
        } catch {
            appErrors[app.id] = error.localizedDescription
            log.error("Start failed: \(error.localizedDescription, privacy: .public)")
            do { try session.stop() }
            catch { pendingCleanup.append(session); pendingCleanupCount = pendingCleanup.count; report(error) }
        }
    }

    func disable(_ id: String) {
        cancelTimedMute(id)
        guard let session = sessions.removeValue(forKey: id) else { return }
        activeIDs.remove(id)
        peaks[id] = nil
        clippedFrames[id] = nil
        idleSince[id] = nil
        lastCycles[id] = nil
        do { try session.stop() }
        catch { pendingCleanup.append(session); pendingCleanupCount = pendingCleanup.count; report(error) }
    }

    func route(_ app: AudioApplication, uid: String) {
        let wasActive = activeIDs.contains(app.id)
        disable(app.id)
        update(app.id) { $0.outputUID = uid }
        if wasActive { enable(app) }
    }

    func stopAll() {
        timedMutes.cancelAll()
        muteSecondsRemaining = [:]
        for id in Array(sessions.keys) { disable(id) }
        var remaining: [ProcessAudioSession] = []
        for session in pendingCleanup {
            do { try session.stop() }
            catch { remaining.append(session); report(error) }
        }
        pendingCleanup = remaining
        pendingCleanupCount = remaining.count
    }
    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { report(error) }
    }
    private func report(_ error: Error) {
        log.error("\(error.localizedDescription, privacy: .public)")
        errorMessage = error.localizedDescription
    }
}
