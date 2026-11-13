# Privacy

My Sound Control processes the selected applications' audio locally in memory. It does not record audio files, upload audio, include analytics or contact an application server.

Device and audio-process discovery starts when the app opens. Audio capture starts only when you switch on Mixer for an application, subject to macOS system audio recording permission. Microphone metering/capture is not implemented. Choosing the system microphone or changing its hardware gain affects the macOS default device and other applications using it.

Volume, mute, favorite and output-device preferences are saved in local UserDefaults. Active capture sessions are never restored automatically on launch. Session logs contain operational errors, not audio samples. Closing the mixer window leaves the menu-bar app running; choose Quit to stop it.
