import AudioDSP
import CoreAudio
import Testing

struct AudioDSPTests {
    private func render(_ processor: OpaquePointer, samples: [Float], outputChannels: UInt32 = 2) -> [Float] {
        var input = samples
        var output = [Float](repeating: 999, count: samples.count / 2 * Int(outputChannels))
        input.withUnsafeMutableBytes { source in
            output.withUnsafeMutableBytes { destination in
                var i = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(source.count), mData: source.baseAddress))
                var o = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: outputChannels, mDataByteSize: UInt32(destination.count), mData: destination.baseAddress))
                MSCProcessorRender(processor, &i, &o)
            }
        }
        return output
    }

    @Test func testStereoGainAndPeak() throws {
        let p = try #require(MSCProcessorCreate(48000, 0.5)); defer { MSCProcessorDestroy(p) }
        #expect(render(p, samples: [1, -1, 0.4, -0.2]) == [0.5, -0.5, 0.2, -0.1])
        #expect(MSCProcessorPeak(p) == 0.5)
        #expect(MSCProcessorCycles(p) == 1)
        #expect(MSCProcessorFaults(p) == 0)
    }

    @Test func testMonoOutputMixesBothChannels() throws {
        let p = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(p) }
        #expect(render(p, samples: [0, 1, 1, -1], outputChannels: 1) == [0.5, 0])
    }

    @Test func testGainRampIsContinuousAndSettlesToMute() throws {
        let p = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(p) }
        MSCProcessorSetGain(p, 0)
        let result = render(p, samples: [Float](repeating: 1, count: 9600))
        #expect(result[0] > 0.99)
        #expect(abs(result.last!) < 0.00001)
        for i in stride(from: 2, to: result.count, by: 2) {
            #expect(result[i] <= result[i - 2])
            #expect(result[i - 2] - result[i] < 0.005)
            #expect(result[i] == result[i + 1])
        }
    }

    @Test func testIndependentSessionsDoNotShareGain() throws {
        let a = try #require(MSCProcessorCreate(48000, 0.25)); defer { MSCProcessorDestroy(a) }
        let b = try #require(MSCProcessorCreate(48000, 0.75)); defer { MSCProcessorDestroy(b) }
        #expect(render(a, samples: [1, 1]) == [0.25, 0.25])
        #expect(render(b, samples: [1, 1]) == [0.75, 0.75])
    }

    @Test func testNonFiniteSamplesAndGainCannotPoisonOutput() throws {
        let p = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(p) }
        #expect(render(p, samples: [.nan, .infinity, -.infinity, 0.5]) == [0, 0, 0, 0.5])
        MSCProcessorSetGain(p, .nan)
        let finite = render(p, samples: [Float](repeating: 1, count: 9600)).allSatisfy { $0.isFinite }
        #expect(finite)
        #expect(MSCProcessorPeak(p) < 1)
        #expect(MSCProcessorCreate(.nan, 1) == nil)
        #expect(MSCProcessorCreate(0, 1) == nil)
    }

    @Test func testMalformedInputSilencesOutputAndSignalsFault() throws {
        let p = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(p) }
        var samples: [Float] = [1, 1]
        samples.withUnsafeMutableBytes { data in
            var input = AudioBufferList(mNumberBuffers: 0, mBuffers: AudioBuffer())
            var output = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(data.count), mData: data.baseAddress))
            MSCProcessorRender(p, &input, &output)
        }
        #expect(samples == [0, 0])
        #expect(MSCProcessorFaults(p) == 1)
    }

    @Test func testPlanarStereoMaintainsChannelOrder() throws {
        let p = try #require(MSCProcessorCreate(48000, 0.5)); defer { MSCProcessorDestroy(p) }
        var left: [Float] = [1, 0.5], right: [Float] = [-1, -0.5]
        var output = [Float](repeating: 0, count: 4)
        let input = AudioBufferList.allocate(maximumBuffers: 2)
        defer { input.unsafeMutablePointer.deallocate() }
        input.unsafeMutablePointer.pointee.mNumberBuffers = 2
        left.withUnsafeMutableBytes { l in
            right.withUnsafeMutableBytes { r in
                input[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(l.count), mData: l.baseAddress)
                input[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(r.count), mData: r.baseAddress)
                output.withUnsafeMutableBytes { data in
                    var o = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(data.count), mData: data.baseAddress))
                    MSCProcessorRender(p, input.unsafeMutablePointer, &o)
                }
            }
        }
        #expect(output == [0.5, -0.5, 0.25, -0.25])
    }

    @Test func testMismatchedFramesFailToSilence() throws {
        let p = try #require(MSCProcessorCreate(48000, 1)); defer { MSCProcessorDestroy(p) }
        var input: [Float] = [1, 1], output: [Float] = [9, 9, 9, 9]
        input.withUnsafeMutableBytes { source in
            output.withUnsafeMutableBytes { destination in
                var i = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(source.count), mData: source.baseAddress))
                var o = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(destination.count), mData: destination.baseAddress))
                MSCProcessorRender(p, &i, &o)
            }
        }
        #expect(output == [0, 0, 0, 0])
        #expect(MSCProcessorFaults(p) == 1)
    }
}
