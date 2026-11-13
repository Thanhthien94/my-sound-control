import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItemStore: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var errorMessage: String?

    var enabled: Bool { status == .enabled || status == .requiresApproval }
    var installed: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) {
        guard installed else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
        refresh()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
}
