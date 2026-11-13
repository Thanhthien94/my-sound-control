import MixerLogic
import SwiftUI

struct EqualizerView: View {
    @ObservedObject var store: MixerStore
    let app: AudioApplication
    @Environment(\.dismiss) private var dismiss
    private var settings: EqualizerSettings { store.preference(app.id).equalizer }
    private var selectedPreset: String {
        EqualizerPreset.allCases.first { $0.gains == settings.gains }?.rawValue ?? "custom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Equalizer").font(.title2.bold())
                    Text(app.name).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Toggle("Bật EQ", isOn: Binding(get: { settings.enabled }, set: { enabled in
                    change { $0.enabled = enabled }
                })).toggleStyle(.switch)
                Button("Xong") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            HStack {
                Picker("Preset", selection: Binding(get: { selectedPreset }, set: { name in
                    guard let preset = EqualizerPreset(rawValue: name) else { return }
                    change { $0.gains = preset.gains }
                })) {
                    ForEach(EqualizerPreset.allCases) { Text($0.title).tag($0.rawValue) }
                    Text("Tùy chỉnh").tag("custom")
                }.frame(width: 250)
                Spacer()
                Button("Đặt lại") {
                    let enabled = settings.enabled
                    change { $0 = EqualizerSettings(); $0.enabled = enabled }
                }.help("Đưa các băng và preamp về 0 dB, bật tự bù headroom")
            }
            HStack(alignment: .top, spacing: 6) {
                VStack {
                    Text("+12"); Spacer(); Text("0"); Spacer(); Text("−12")
                }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: 26, height: 142).padding(.top, 26)
                ForEach(0..<10, id: \.self) { index in
                    band(index)
                }
            }
            Divider()
            HStack {
                Text("Preamp").frame(width: 70, alignment: .leading)
                Slider(value: Binding(get: { settings.preampDB }, set: { value in change { $0.preampDB = value } }),
                       in: -24...0, step: 0.5).accessibilityLabel("Preamp")
                Text(db(settings.preampDB)).font(.caption.monospacedDigit()).frame(width: 70, alignment: .trailing)
            }
            Toggle("Tự bù headroom", isOn: Binding(get: { settings.automaticHeadroom }, set: { value in
                change { $0.automaticHeadroom = value }
            }))
            Text("Tự giảm gain theo đáp tuyến EQ để chừa khoảng trống khi nâng dải. Preamp ở trên giảm thêm mức tín hiệu. Bảo vệ đỉnh mẫu vẫn có thể cắt đỉnh; đây không phải limiter true-peak.")
                .font(.caption).foregroundStyle(.secondary)
            if (store.clippedFrames[app.id] ?? 0) > 0 {
                Label("Đã cắt đỉnh trong phiên này. Hạ preamp hoặc giảm mức nâng dải nếu nghe méo.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Label(status, systemImage: store.activeIDs.contains(app.id) && settings.enabled ? "waveform" : "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 670)
    }

    private var status: String {
        if !store.activeIDs.contains(app.id) { return "Thiết lập được lưu. Bật Mixer của ứng dụng để nghe EQ." }
        return settings.enabled ? "EQ đang xử lý trực tiếp · 10 băng stereo" : "EQ đang bypass. Các mức chỉnh vẫn được giữ."
    }

    private func change(_ body: (inout EqualizerSettings) -> Void) {
        store.update(app.id) { body(&$0.equalizer) }
    }

    private func db(_ value: Double) -> String { String(format: "%+.1f dB", value) }

    private func band(_ index: Int) -> some View {
        VStack(spacing: 8) {
            Text(db(settings.gains[index])).font(.caption2.monospacedDigit()).frame(height: 18)
            EqualizerFader(value: Binding(get: { settings.gains[index] }, set: { value in
                change { $0.gains[index] = value }
            }), label: "EQ \(EqualizerSettings.labels[index]) Hz cho \(app.name)")
                .frame(width: 40, height: 142)
            Text(EqualizerSettings.labels[index]).font(.caption.monospacedDigit())
            Text("Hz").font(.caption2).foregroundStyle(.tertiary)
        }.frame(maxWidth: .infinity)
    }
}
