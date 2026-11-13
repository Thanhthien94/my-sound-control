import SwiftUI

struct SettingsView: View {
    @StateObject private var loginItem = LoginItemStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section {
                Toggle("Khởi động cùng macOS", isOn: Binding(
                    get: { loginItem.enabled }, set: { loginItem.setEnabled($0) }
                )).disabled(!loginItem.installed)
                Text("App mở trong menu bar. Mixer âm thanh luôn chờ bạn bật thủ công.")
                    .font(.caption).foregroundStyle(.secondary)
                if !loginItem.installed {
                    Text("Mở bản trong Applications để thay đổi mục khởi động.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if loginItem.status == .requiresApproval {
                    Text("macOS đang chờ bạn cho phép mục khởi động.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Mở cài đặt đăng nhập") { loginItem.openLoginSettings() }
                }
                if let error = loginItem.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
            } header: { Text("Khởi động") }
        }
        .formStyle(.grouped).frame(width: 460, height: 260)
        .onAppear { loginItem.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loginItem.refresh() }
        }
    }
}
