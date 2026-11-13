import CoreAudio
import SwiftUI

struct DeviceControlView: View {
    @ObservedObject var store: MixerStore
    let role: DeviceRole

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: role.symbol).font(.title3).foregroundStyle(.tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(role.title).font(.callout.weight(.semibold))
                    Spacer()
                    Picker(role.title, selection: Binding(get: { store.defaultIDs[role] ?? 0 }, set: { store.selectDevice($0, role: role) })) {
                        Text("Chưa có thiết bị").tag(AudioObjectID(0))
                        ForEach(store.devices.filter { role == .input ? $0.inputs > 0 : $0.outputs > 0 }) { device in
                            Text(device.name).tag(device.id)
                        }
                    }.labelsHidden().frame(maxWidth: 270)
                }
                HStack {
                    Slider(value: Binding(get: { Double(store.volumes[role] ?? 0) }, set: { store.setVolume($0, role: role) }), in: 0...1)
                        .disabled(store.volumes[role] == nil)
                        .accessibilityLabel("Âm lượng \(role.title)")
                    Text(store.volumes[role].map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 40)
                    Button { store.toggleMute(role) } label: {
                        Image(systemName: store.mutes[role] == true ? "speaker.slash.fill" : "speaker.wave.2")
                    }.disabled(store.mutes[role] == nil).help("Bật/tắt tiếng \(role.title)")
                }
                if store.volumes[role] == nil {
                    Text("Thiết bị không hỗ trợ chỉnh volume tổng.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(14).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}
