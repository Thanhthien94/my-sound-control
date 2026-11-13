# Changelog

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
