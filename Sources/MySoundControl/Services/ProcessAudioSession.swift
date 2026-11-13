import AudioDSP
import CoreAudio
import Foundation
import OSLog

/// Owns one private tap and aggregate. All lifecycle methods run on the main thread;
/// only the C IOProc touches sample memory. No vendor binary is loaded.
final class ProcessAudioSession {
    let applicationID: String
    let processObjects: [AudioObjectID]
    let sourceDeviceIDs: [AudioObjectID]
    let outputUID: String
    let captureUID: String
    let followsDefault: Bool
    let startedAt = Date()
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private var processor: OpaquePointer?
    private(set) var sampleRate: Double = 0
    private static let log = Logger(subsystem: "vn.thiendev.mysoundcontrol", category: "AudioSession")

    init(application: AudioApplication, output: AudioDevice, capture: AudioDevice, followsDefault: Bool) {
        applicationID = application.id
        processObjects = application.processObjects
        sourceDeviceIDs = application.deviceIDs
        outputUID = output.uid
        captureUID = capture.uid
        self.followsDefault = followsDefault
    }

    var peak: Float { MSCProcessorPeak(processor) }
    var cycles: UInt64 { MSCProcessorCycles(processor) }
    var faults: UInt64 { MSCProcessorFaults(processor) }

    func start(gain: Float) throws {
        do { try createPipeline(gain: gain) }
        catch {
            let startError = error
            do { try stop() }
            catch { throw AudioFailure(operation: "\(startError.localizedDescription) Dọn tài nguyên: \(error.localizedDescription)", status: nil) }
            throw startError
        }
    }

    private func createPipeline(gain: Float) throws {
        guard aggregate == 0, tap == 0, processor == nil else {
            throw AudioFailure(operation: "Phiên âm thanh đã tồn tại", status: nil)
        }
        // A device-scoped tap preserves its stream sample rate. A global mixdown
        // can use 48 kHz even when the selected output is running at 44.1 kHz.
        let description = CATapDescription(processes: processObjects, deviceUID: captureUID, stream: 0)
        description.name = "My Sound Control · \(applicationID)"
        description.uuid = UUID()
        description.isPrivate = true
        // Restores original playback whenever our IO stops reading the tap.
        description.muteBehavior = .mutedWhenTapped
        try HAL.check(AudioHardwareCreateProcessTap(description, &tap), "Không tạo được luồng thu âm. Kiểm tra quyền ghi âm hệ thống")
        let tapFormat = try HAL.value(tap, HAL.address(kAudioTapPropertyFormat), initial: AudioStreamBasicDescription())
        try validate(tapFormat)
        guard tapFormat.mChannelsPerFrame == 2 else {
            throw AudioFailure(operation: "Bản thử nghiệm cần nguồn thu stereo", status: nil)
        }
        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "My Sound Control · Private",
            kAudioAggregateDeviceUIDKey: "vn.thiendev.mysoundcontrol.aggregate.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID, kAudioSubDeviceInputChannelsKey: 0]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]],
            kAudioAggregateDeviceTapAutoStartKey: true
        ]
        try HAL.check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregate), "Không tạo được đường phát âm thanh")

        // Fail closed for unsupported duplex/multichannel layouts instead of accidentally
        // copying a hardware microphone into the output. The sole input must be our stereo tap.
        guard try HAL.channelCount(aggregate, scope: kAudioObjectPropertyScopeInput) == 2 else {
            throw AudioFailure(operation: "Thiết bị này chưa hỗ trợ đường thu stereo riêng. Thử loa tích hợp hoặc thiết bị output-only", status: nil)
        }
        let inputs = try HAL.ids(aggregate, HAL.address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput))
        let outputs = try HAL.ids(aggregate, HAL.address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput))
        guard !inputs.isEmpty, !outputs.isEmpty else {
            throw AudioFailure(operation: "Thiết bị chưa cung cấp luồng âm thanh", status: nil)
        }
        var outputChannels: UInt32 = 0
        for stream in inputs + outputs {
            let format = try HAL.value(stream, HAL.address(kAudioStreamPropertyVirtualFormat), initial: AudioStreamBasicDescription())
            try validate(format)
            guard abs(format.mSampleRate - tapFormat.mSampleRate) < 1 else {
                throw AudioFailure(operation: "Nguồn \(Int(tapFormat.mSampleRate)) Hz và đường phát \(Int(format.mSampleRate)) Hz khác nhau. Chọn đầu ra cùng sample rate", status: nil)
            }
            if outputs.contains(stream) { outputChannels += format.mChannelsPerFrame }
        }
        guard (1...2).contains(outputChannels) else {
            throw AudioFailure(operation: "Bản đầu hỗ trợ đầu ra mono hoặc stereo", status: nil)
        }
        sampleRate = tapFormat.mSampleRate
        guard let created = MSCProcessorCreate(sampleRate, gain) else {
            throw AudioFailure(operation: "Không khởi tạo được bộ xử lý âm thanh", status: nil)
        }
        processor = created
        try HAL.check(MSCProcessorRegister(aggregate, created, &ioProc), "Không đăng ký được bộ xử lý âm thanh")
        try HAL.check(AudioDeviceStart(aggregate, ioProc), "Không bắt đầu được audio. Cho phép ghi âm hệ thống trong Quyền riêng tư & Bảo mật")
        Self.log.info("Audio session started, sample rate \(self.sampleRate)")
    }

    private func validate(_ format: AudioStreamBasicDescription) throws {
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
              format.mFormatFlags & kAudioFormatFlagIsPacked != 0,
              format.mBitsPerChannel == 32, format.mFramesPerPacket == 1,
              format.mChannelsPerFrame > 0, format.mChannelsPerFrame <= 2,
              format.mBytesPerFrame == 4 * (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 ? 1 : format.mChannelsPerFrame) else {
            throw AudioFailure(operation: "Định dạng thiết bị chưa được hỗ trợ (cần Float32 mono/stereo)", status: nil)
        }
    }

    func setGain(_ gain: Float) { MSCProcessorSetGain(processor, gain) }

    func stop() throws {
        var failures: [String] = []
        if let ioProc, aggregate != 0 {
            let stopped = AudioDeviceStop(aggregate, ioProc)
            if stopped != noErr { Self.log.error("AudioDeviceStop status \(stopped)") }
            let status = AudioDeviceDestroyIOProcID(aggregate, ioProc)
            if status == noErr { self.ioProc = nil }
            else { failures.append("IOProc \(status)") }
        }
        if aggregate != 0 {
            let status = AudioHardwareDestroyAggregateDevice(aggregate)
            if status == noErr { aggregate = 0; ioProc = nil }
            else { failures.append("aggregate \(status)") }
        }
        // Always try to destroy the tap to release the original process output.
        if tap != 0 {
            let status = AudioHardwareDestroyProcessTap(tap)
            if status == noErr { tap = 0 }
            else { failures.append("tap \(status)") }
        }
        if ioProc == nil, let processor {
            MSCProcessorDestroy(processor)
            self.processor = nil
        }
        // If Core Audio refuses to destroy the IOProc, retain its C context rather
        // than free memory that a real-time callback might still reference.
        if !failures.isEmpty {
            throw AudioFailure(operation: "Chưa dọn xong phiên âm thanh: \(failures.joined(separator: ", "))", status: nil)
        }
    }

    deinit {
        do { try stop() }
        catch { Self.log.error("Session cleanup failed: \(error.localizedDescription, privacy: .public)") }
    }
}
