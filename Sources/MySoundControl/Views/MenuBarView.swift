import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: MixerStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My Sound Control").font(.headline)
                Spacer()
                Text("Preview").font(.caption).foregroundStyle(.secondary)
            }
            DeviceControlView(store: store, role: .output)
            Text(store.activeIDs.isEmpty ? "Chưa bật mixer ứng dụng" : "Đang xử lý \(store.activeIDs.count) ứng dụng")
                .font(.caption).foregroundStyle(.secondary)
            Button("Mở bộ trộn âm thanh") {
                openWindow(id: "mixer")
                NSApp.activate(ignoringOtherApps: true)
            }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            Button("Trả tất cả về âm gốc") { store.stopAll() }.disabled(store.activeIDs.isEmpty && store.pendingCleanupCount == 0)
            Divider()
            HStack {
                Button("Thông tin") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "My Sound Control",
                        .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Preview",
                        .credits: NSAttributedString(string: "Ứng dụng âm thanh độc lập cho macOS.\nBản preview: mixer stereo, chưa có EQ/AirPlay.")
                    ])
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Thoát") { store.stopAll(); NSApp.terminate(nil) }.keyboardShortcut("q")
            }.font(.caption)
        }.padding(16).frame(width: 400)
    }
}
