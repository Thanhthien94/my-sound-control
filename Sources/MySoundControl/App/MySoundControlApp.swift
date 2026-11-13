import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility: no Dock icon. The mixer window appears on first launch.
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { MixerStore.shared.stopAll() }
    }
}

@main
struct MySoundControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MixerStore.shared

    var body: some Scene {
        WindowGroup("My Sound Control", id: "mixer") {
            MixerView(store: store)
        }
        .defaultSize(width: 720, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Âm thanh") {
                Button("Làm mới") { store.refresh() }.keyboardShortcut("r")
                Button("Trả tất cả về âm gốc") { store.stopAll() }.keyboardShortcut("0", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("My Sound Control", systemImage: "slider.horizontal.3") {
            MenuBarView(store: store)
        }.menuBarExtraStyle(.window)
    }
}
