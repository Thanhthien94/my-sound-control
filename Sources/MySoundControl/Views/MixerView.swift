import AppKit
import SwiftUI

struct MixerView: View {
    @ObservedObject var store: MixerStore
    @State private var showAll = false

    private var visibleApps: [AudioApplication] {
        store.applications.filter { showAll || $0.isPlaying || store.preference($0.id).favorite || store.activeIDs.contains($0.id) || store.appErrors[$0.id] != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                AppMark().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Sound Control").font(.title2.bold())
                    Text("Âm thanh theo cách của bạn").foregroundStyle(.secondary)
                }
                Spacer()
                Text("PREVIEW").font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12), in: Capsule()).foregroundStyle(.tint)
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("THIẾT BỊ HỆ THỐNG").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(DeviceRole.allCases) { role in
                            DeviceControlView(store: store, role: role)
                        }
                        Text("Âm lượng thông báo dùng chung volume phần cứng nếu chọn cùng thiết bị với đầu ra.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("ỨNG DỤNG").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Toggle("Hiện tất cả", isOn: $showAll).toggleStyle(.checkbox).font(.caption)
                        }
                        if visibleApps.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary)
                                Text("Phát âm thanh trong một ứng dụng").font(.headline)
                                Text("Ứng dụng đang phát sẽ xuất hiện ở đây. Bật Mixer để điều chỉnh riêng.")
                                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                        ForEach(visibleApps) { app in
                            ApplicationRow(store: store, app: app)
                            if app.id != visibleApps.last?.id { Divider() }
                        }
                    }
                    Label("Lần đầu bật Mixer, macOS có thể yêu cầu quyền ghi âm hệ thống. Không cần bật microphone để chỉnh âm lượng ứng dụng.", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            Divider()
            HStack {
                Label(store.activeIDs.isEmpty ? "Đang dùng âm gốc" : "Đang xử lý \(store.activeIDs.count) ứng dụng",
                      systemImage: store.activeIDs.isEmpty ? "speaker.wave.2" : "waveform")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }.help("Cài đặt")
                Button("Trả về âm gốc") { store.stopAll() }.disabled(store.activeIDs.isEmpty && store.pendingCleanupCount == 0)
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Làm mới")
            }.padding(14)
        }
        .frame(minWidth: 640, minHeight: 560)
        .alert("Không thể hoàn tất", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("Đóng") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
