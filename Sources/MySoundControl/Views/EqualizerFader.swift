import AppKit
import SwiftUI

/// NSSlider provides native vertical drawing, keyboard steps and accessibility.
struct EqualizerFader: NSViewRepresentable {
    @Binding var value: Double
    let label: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: -12, maxValue: 12,
                              target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        slider.isVertical = true
        slider.isContinuous = true
        slider.numberOfTickMarks = 49
        slider.allowsTickMarkValuesOnly = true
        slider.tickMarkPosition = .leading
        slider.setAccessibilityLabel(label)
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        if slider.doubleValue != value { slider.doubleValue = value }
        slider.setAccessibilityLabel(label)
    }

    final class Coordinator: NSObject {
        var parent: EqualizerFader
        init(_ parent: EqualizerFader) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) {
            parent.value = (sender.doubleValue * 2).rounded() / 2
        }
    }
}
