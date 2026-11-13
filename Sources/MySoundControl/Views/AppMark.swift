import AppKit
import SwiftUI

enum AppBrand {
    static let icon: NSImage? = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap { NSImage(contentsOf: $0) }
}

struct AppMark: View {
    var body: some View {
        Group {
            if let icon = AppBrand.icon {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "waveform.circle.fill").resizable().scaledToFit().foregroundStyle(.tint)
            }
        }.accessibilityLabel("My Sound Control")
    }
}
