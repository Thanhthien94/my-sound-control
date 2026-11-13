import Testing
import MixerLogic

struct TimedMutesTests {
    @Test func independentDeadlinesAndExactRestoration() {
        let now = ContinuousClock.now
        var timers = TimedMutes()
        timers.start("music", seconds: 30, now: now)
        timers.start("browser", seconds: 60, now: now)
        #expect(timers.remaining(now: now.advanced(by: .milliseconds(29_100)))["music"] == 1)
        #expect(timers.expire(now: now.advanced(by: .milliseconds(29_999))).isEmpty)
        #expect(timers.expire(now: now.advanced(by: .seconds(30))) == ["music"])
        #expect(timers.remaining(now: now.advanced(by: .seconds(30))) == ["browser": 30])
        #expect(timers.expire(now: now.advanced(by: .seconds(60))) == ["browser"])
        #expect(timers.expire(now: now.advanced(by: .seconds(61))).isEmpty)
    }

    @Test func replacementDoesNotRestoreAtOldDeadline() {
        let now = ContinuousClock.now
        var timers = TimedMutes()
        timers.start("music", seconds: 30, now: now)
        timers.start("music", seconds: 120, now: now.advanced(by: .seconds(10)))
        #expect(timers.expire(now: now.advanced(by: .seconds(30))).isEmpty)
        #expect(timers.remaining(now: now.advanced(by: .seconds(30))) == ["music": 100])
        #expect(timers.expire(now: now.advanced(by: .seconds(130))) == ["music"])
    }

    @Test func cancellationAndStopPreventDelayedRestoration() {
        let now = ContinuousClock.now
        var timers = TimedMutes()
        timers.start("music", seconds: 30, now: now)
        timers.start("browser", seconds: 60, now: now)
        timers.cancel("music")
        #expect(timers.remaining(now: now) == ["browser": 60])
        timers.cancelAll()
        #expect(timers.expire(now: now.advanced(by: .seconds(300))).isEmpty)
        #expect(timers.remaining(now: now).isEmpty)
    }

    @Test func invalidDurationDoesNotReplaceExistingTimer() {
        let now = ContinuousClock.now
        var timers = TimedMutes()
        timers.start("music", seconds: 30, now: now)
        timers.start("music", seconds: 0, now: now)
        timers.start("browser", seconds: -1, now: now)
        #expect(timers.remaining(now: now) == ["music": 30])
    }
}
