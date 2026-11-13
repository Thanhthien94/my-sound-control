import AppKit
import SwiftUI

struct ApplicationRow: View {
    @ObservedObject var store: MixerStore
    let app: AudioApplication
    private var preference: MixerPreference { store.preference(app.id) }
    private var active: Bool { store.activeIDs.contains(app.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let icon = NSRunningApplication(processIdentifier: app.pid)?.icon {
                    Image(nsImage: icon).resizable().frame(width: 30, height: 30)
                } else {
                    Image(systemName: "app.fill").font(.title2).frame(width: 30, height: 30).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(active ? "Mixer đang bật" : app.isPlaying ? "Đang phát · Âm gốc" : "Âm gốc")
                        .font(.caption).foregroundStyle(active ? Color.accentColor : Color.secondary)
                }
                Spacer()
                Button { store.update(app.id) { $0.favorite.toggle() } } label: {
                    Image(systemName: preference.favorite ? "star.fill" : "star")
                        .foregroundStyle(preference.favorite ? Color.yellow : Color.secondary)
                }.buttonStyle(.plain).help("Ưa thích")
                Toggle("Mixer", isOn: Binding(get: { active }, set: { $0 ? store.enable(app) : store.disable(app.id) }))
                    .toggleStyle(.switch).controlSize(.small).fixedSize()
            }
            HStack(spacing: 10) {
                Button { store.toggleApplicationMute(app.id) } label: {
                    Image(systemName: store.isMuted(app.id) && active ? "speaker.slash.fill" : "speaker.wave.2")
                }.disabled(!active).help("Bật/tắt tiếng \(app.name)")
                Menu {
                    Button("30 giây") { store.muteTemporarily(app.id, seconds: 30) }
                    Button("1 phút") { store.muteTemporarily(app.id, seconds: 60) }
                    Button("2 phút") { store.muteTemporarily(app.id, seconds: 120) }
                } label: {
                    Label("Tạm tắt tiếng \(app.name)", systemImage: "timer").labelStyle(.iconOnly)
                }.menuStyle(.borderlessButton).fixedSize()
                    .disabled(!active || preference.muted)
                    .help("Tạm tắt tiếng \(app.name)")
                    .accessibilityLabel("Tạm tắt tiếng \(app.name)")
                Slider(value: Binding(get: { preference.volume }, set: { value in store.update(app.id) { $0.volume = value } }), in: 0...1)
                    .disabled(!active).accessibilityLabel("Âm lượng \(app.name)")
                Text(active ? "\(Int((preference.volume * 100).rounded()))%" : "—")
                    .font(.caption.monospacedDigit()).frame(width: 40).foregroundStyle(.secondary)
                Picker("Đầu ra cho \(app.name)", selection: Binding(get: { preference.outputUID }, set: { store.route(app, uid: $0) })) {
                    Text("Theo hệ thống").tag("")
                    ForEach(store.devices.filter { $0.outputs > 0 }) { device in Text(device.name).tag(device.uid) }
                    if !preference.outputUID.isEmpty && !store.devices.contains(where: { $0.uid == preference.outputUID }) {
                        Text("Thiết bị đã ngắt").tag(preference.outputUID)
                    }
                }.labelsHidden().frame(width: 210)
            }
            if let seconds = store.muteSecondsRemaining[app.id] {
                HStack {
                    Label("Bật tiếng sau \(seconds / 60):\(String(format: "%02d", seconds % 60))", systemImage: "timer")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Button("Bật tiếng ngay") { store.unmuteNow(app.id) }
                        .font(.caption)
                }
            }
            if active {
                HStack(spacing: 8) {
                    GeometryReader { geometry in
                        Capsule().fill(.quaternary)
                        Capsule().fill(.tint).frame(width: geometry.size.width * CGFloat(min(1, max(0, store.peaks[app.id] ?? 0))))
                    }.frame(height: 3)
                    Text(levelText).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel("Mức âm thanh \(app.name)").accessibilityValue(levelText)
            }
            if let error = store.appErrors[app.id] {
                Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
        }.padding(.vertical, 3)
    }

    private var levelText: String {
        let peak = store.peaks[app.id] ?? 0
        return peak > 0.00001 ? String(format: "%.0f dBFS", 20 * log10(peak)) : "−∞ dBFS"
    }
}
