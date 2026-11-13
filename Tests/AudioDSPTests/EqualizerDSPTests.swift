import AudioDSP
import CoreAudio
import Dispatch
import Foundation
import Testing

struct EqualizerDSPTests {
    private func configure(_ p: OpaquePointer, gains: [Float] = Array(repeating: 0, count: 10),
                           enabled: Bool = true, preamp: Float = 0, automatic: Bool = false) {
        gains.withUnsafeBufferPointer { MSCProcessorSetEqualizer(p, enabled, $0.baseAddress, UInt32($0.count), preamp, automatic) }
    }

    private func render(_ p: OpaquePointer, _ samples: [Float], blockSize: Int = 256) -> [Float] {
        var source = samples, result = [Float](repeating: 0, count: samples.count)
        source.withUnsafeMutableBufferPointer { input in
            result.withUnsafeMutableBufferPointer { output in
                for offset in stride(from: 0, to: samples.count, by: blockSize * 2) {
                    let count = min(blockSize * 2, samples.count - offset)
                    var i = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2,
                        mDataByteSize: UInt32(count * 4), mData: input.baseAddress!.advanced(by: offset)))
                    var o = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2,
                        mDataByteSize: UInt32(count * 4), mData: output.baseAddress!.advanced(by: offset)))
                    MSCProcessorRender(p, &i, &o)
                }
            }
        }
        return result
    }

    private func sine(_ frequency: Double, sampleRate: Double, amplitude: Double = 0.05) -> [Float] {
        (0..<Int(sampleRate / 2)).flatMap { frame -> [Float] in
            [Float(amplitude * sin(2 * .pi * frequency * Double(frame) / sampleRate)), 0]
        }
    }

    private func rms(_ data: [Float]) -> Double {
        let tail = data.count / 2
        let values = stride(from: tail + tail % 2, to: data.count, by: 2).map { Double(data[$0]) }
        return sqrt(values.reduce(0) { $0 + $1 * $1 } / Double(values.count))
    }

    @Test func centerFrequencyGainMatchesAcrossSampleRates() throws {
        let centers: [Double] = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for rate in [44100.0, 48000, 96000] {
            for (index, frequency) in centers.enumerated() {
                for gain: Float in [-12, -6, 6, 12] {
                    let p = try #require(MSCProcessorCreate(rate, 1)); defer { MSCProcessorDestroy(p) }
                    var bands = [Float](repeating: 0, count: 10); bands[index] = gain
                    configure(p, gains: bands)
                    let input = sine(frequency, sampleRate: rate)
                    let output = render(p, input)
                    let measured = 20 * log10(rms(output) / rms(input))
                    #expect(abs(measured - Double(gain)) < 0.15,
                            "\(rate) Hz, band \(frequency): \(measured) dB vs \(gain)")
                    #expect(stride(from: 1, to: output.count, by: 2).allSatisfy { output[$0] == 0 })
                    #expect(MSCProcessorFaults(p) == 0)
                }
            }
        }
    }

    @Test func flatAndBypassPreserveSamplesAndPreampHasExpectedGain() throws {
        let p = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(p) }
        let input = sine(1000, sampleRate: 48000)
        configure(p)
        #expect(render(p, input) == input)
        configure(p, preamp: -6)
        let reduced = render(p, input)
        #expect(abs(20 * log10(rms(reduced) / rms(input)) + 6) < 0.01)
        configure(p, gains: Array(repeating: 12, count: 10), enabled: false, preamp: -24)
        _ = render(p, [Float](repeating: 0, count: 4096))
        #expect(render(p, input) == input)
    }

    @Test func automaticHeadroomAndEmergencyClipping() throws {
        let input = sine(1000, sampleRate: 48000, amplitude: 0.9)
        let a = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(a) }
        let b = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(b) }
        let gains = [Float](repeating: 12, count: 10)
        configure(a, gains: gains, automatic: true)
        configure(b, gains: gains)
        let safe = render(a, input), clipped = render(b, input)
        #expect(safe.allSatisfy { $0.isFinite && abs($0) <= 1 })
        #expect(clipped.allSatisfy { $0.isFinite && abs($0) <= 1 })
        #expect(MSCProcessorClippedFrames(a) == 0)
        #expect(MSCProcessorClippedFrames(b) > 0)
        #expect(rms(safe) < rms(clipped))
    }

    @Test func transitionIsBoundedAndMuteRemainsSilent() throws {
        let p = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(p) }
        let input = [Float](repeating: 0.2, count: 4800)
        configure(p, preamp: -12)
        let output = render(p, input)
        #expect(output[0] > 0.19)
        #expect(abs(output.last! - 0.2 * pow(10, -12 / 20)) < 0.00001)
        #expect(stride(from: 2, to: output.count, by: 2).allSatisfy { abs(output[$0] - output[$0 - 2]) < 0.001 })
        MSCProcessorSetGain(p, 0)
        configure(p, gains: Array(repeating: 12, count: 10))
        _ = render(p, input)
        let silent = render(p, input)
        #expect(silent.allSatisfy { abs($0) < 0.00001 })
    }

    @Test func unsupportedBandsAndInvalidValuesCannotPoisonState() throws {
        let p = try #require(MSCProcessorCreate(8000, 1)); defer { MSCProcessorDestroy(p) }
        var bands = [Float](repeating: 0, count: 10); bands[8] = 12; bands[9] = -12
        configure(p, gains: bands)
        let input = sine(1000, sampleRate: 8000)
        #expect(render(p, input) == input)
        configure(p, gains: [.nan, .infinity, -.infinity], preamp: .nan)
        #expect(render(p, input).allSatisfy { $0.isFinite })
        configure(p, gains: Array(repeating: 12, count: 10))
        _ = render(p, input)
        let bad: [Float] = [.nan, .infinity, -.infinity, 0]
        #expect(render(p, bad).allSatisfy { $0.isFinite })
    }

    @Test func publicationWhileRenderingKeepsSessionsIndependent() throws {
        // Exactly one control producer and one render consumer per processor.
        final class Pointer: @unchecked Sendable {
            let value: OpaquePointer
            init(_ value: OpaquePointer) { self.value = value }
        }
        let p = Pointer(try #require(MSCProcessorCreate(48000, 1)))
        defer { MSCProcessorDestroy(p.value) }
        let untouched = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(untouched) }
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            for i in 0..<2000 {
                let gains = [Float](repeating: i % 2 == 0 ? -6 : 6, count: 10)
                gains.withUnsafeBufferPointer {
                    MSCProcessorSetEqualizer(p.value, true, $0.baseAddress, 10, -6, false)
                }
            }
            group.leave()
        }
        let input = sine(1000, sampleRate: 48000)
        for _ in 0..<8 { #expect(render(p.value, input).allSatisfy { $0.isFinite && abs($0) <= 1 }) }
        group.wait()
        var final = [Float](repeating: 0, count: 10); final[5] = 6
        configure(p.value, gains: final)
        let settled = render(p.value, input)
        #expect(abs(20 * log10(rms(settled) / rms(input)) - 6) < 0.15)
        #expect(render(untouched, input) == input)
        #expect(MSCProcessorFaults(p.value) == 0)
    }
}
