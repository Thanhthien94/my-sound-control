# Changelog

## 0.1.0-preview.4

- Per-application stereo 10-band EQ (31.25 Hz–16 kHz, ±12 dB, 0.5 dB steps), bypass, reset and five tonal presets.
- Per-app persistence with backward-compatible decoding of existing volume/mute/route/favorites.
- Preamp −24…0 dB, optional response-based automatic headroom and sample-peak clipping protection/counter.
- Independent filter states and SPSC triple-buffer configuration handoff; 20 ms dual-bank crossfades without render-time allocation, locks or coefficient calculation.
- Native AppKit vertical faders and dedicated EQ sheet.
- Response, bypass, preamp, transitions, clipping, sample-rate, concurrent publication and preference migration tests.

## 0.1.0-preview.3

- Per-application timed mute: 30 seconds, 1 minute, 2 minutes, countdown and immediate unmute.
- Ephemeral continuous-clock deadlines, cancellation on session stop, and restoration through the existing gain ramp.
- Native Settings window with opt-in launch at login via ServiceManagement, approval status and error reporting.
- Four deterministic timer lifecycle tests, alongside the eight existing DSP tests.

## 0.1.0-preview.2

- Original waveform/fader icon using the SkyTruong palette, matching the My Fan Control visual family.
- Bundled macOS ICNS and mixer header artwork, with reproducible local raster exports.
- Audio features and limitations remain as in Preview 1.

## 0.1.0-preview.1

- Initial independent menu-bar mixer and Vietnamese UI.
- System input/output/notification selection and supported hardware volume/mute.
- Opt-in per-application process tap, 0–100% gain, mute, meter and output selection.
- Local preferences, cleanup and stop-on-topology-change behavior.
- C real-time gain smoothing with DSP regression tests.
- arm64 ad-hoc DMG/ZIP/checksums, following my-fan-control distribution.

Initial preview without EQ, boost, AU plugins or multi-device AirPlay. See validation notes for hardware limitations.
