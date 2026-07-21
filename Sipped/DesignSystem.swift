import SwiftUI
import UIKit

enum SippedTheme {
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.92, blue: 0.87, alpha: 1)
            : UIColor(red: 0.13, green: 0.14, blue: 0.13, alpha: 1)
    })
    static let secondaryInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.68, green: 0.67, blue: 0.63, alpha: 1)
            : UIColor(red: 0.38, green: 0.39, blue: 0.36, alpha: 1)
    })
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.065, green: 0.075, blue: 0.07, alpha: 1)
            : UIColor(red: 0.965, green: 0.958, blue: 0.925, alpha: 1)
    })
    static let surface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.135, blue: 0.125, alpha: 1)
            : UIColor(red: 1, green: 0.995, blue: 0.975, alpha: 1)
    })
    static let raisedSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.185, blue: 0.17, alpha: 1)
            : UIColor(red: 0.925, green: 0.91, blue: 0.865, alpha: 1)
    })
    static let vessel = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 56 / 255, green: 56 / 255, blue: 59 / 255, alpha: 1)
            : UIColor(red: 0.76, green: 0.74, blue: 0.69, alpha: 1)
    })
    static let line = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor.black.withAlphaComponent(0.10)
    })
    // App chrome follows the warm neutral palette in both appearances. In light
    // mode this resolves to charcoal on ivory; dark mode reverses the pair.
    static let chromeAccent = ink
    static let onChromeAccent = canvas
    static let containerPreviewLiquid = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.75, green: 0.71, blue: 0.62, alpha: 1)
            : UIColor(red: 0.42, green: 0.38, blue: 0.32, alpha: 1)
    })
    static let warmHighlight = Color(red: 0.91, green: 0.63, blue: 0.28)
    static let panelRadius: CGFloat = 22
    static let controlRadius: CGFloat = 14
}

enum SippedLayout {
    static let floatingChromeContentClearance: CGFloat = 112
}

enum SippedTypography {
    static let onboardingCTA: Font = .title3.weight(.bold)
}

enum GalleryStyle {
    static let titleFont: Font = .headline
    static let capacityFont: Font = .subheadline.weight(.semibold).monospacedDigit()
}

enum SippedMotionDirection: Equatable {
    case forward
    case backward
}

enum SippedMotion {
    static let screen = Animation.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.08)
    static let element = Animation.spring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.06)
    static let reduced = Animation.easeOut(duration: 0.16)

    static func direction(from oldIndex: Int, to newIndex: Int) -> SippedMotionDirection {
        newIndex >= oldIndex ? .forward : .backward
    }

    static func screenTransition(direction: SippedMotionDirection) -> AnyTransition {
        let enteringOffset: CGFloat = direction == .forward ? 24 : -24
        let leavingOffset = -enteringOffset * 0.72
        return .asymmetric(
            insertion: .modifier(
                active: SippedBlurTransitionModifier(opacity: 0, blur: 9, scale: 0.985, x: enteringOffset),
                identity: SippedBlurTransitionModifier()
            ),
            removal: .modifier(
                active: SippedBlurTransitionModifier(opacity: 0, blur: 6, scale: 0.992, x: leavingOffset),
                identity: SippedBlurTransitionModifier()
            )
        )
    }

    static let blurReplace = AnyTransition.asymmetric(
        insertion: .modifier(
            active: SippedBlurTransitionModifier(opacity: 0, blur: 7, scale: 0.97),
            identity: SippedBlurTransitionModifier()
        ),
        removal: .modifier(
            active: SippedBlurTransitionModifier(opacity: 0, blur: 5, scale: 1.02),
            identity: SippedBlurTransitionModifier()
        )
    )
}

struct SippedBlurTransitionModifier: ViewModifier {
    var opacity: Double = 1
    var blur: CGFloat = 0
    var scale: CGFloat = 1
    var x: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .scaleEffect(scale)
            .offset(x: x)
    }
}

enum DigitMotionMath {
    static func blurRadius(previousDigit: Int?, currentDigit: Int, elapsed: TimeInterval) -> CGFloat {
        let directDistance = abs(currentDigit - (previousDigit ?? currentDigit - 1))
        let digitDistance = min(directDistance, 10 - min(directDistance, 10))
        guard digitDistance > 0 else { return 0 }
        let rate = Double(digitDistance) / max(elapsed, 1 / 120)
        let normalizedRate = min(1, max(0, (rate - 2) / 48))
        return 0.042 + CGFloat(sqrt(normalizedRate)) * 0.238
    }
}

private struct DigitMotionPulse {
    var radius: CGFloat
    var generation: Int
}

struct SippedAnimatedNumericText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    @State private var pulses: [Int: DigitMotionPulse] = [:]
    @State private var lastChangeTimes: [Int: TimeInterval] = [:]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                if character.wholeNumberValue != nil {
                    Text(String(character))
                        .contentTransition(reduceMotion ? .opacity : .numericText())
                        .blur(radius: pulses[index]?.radius ?? 0)
                        .animation(
                            reduceMotion
                                ? SippedMotion.reduced
                                : .timingCurve(0.22, 1, 0.36, 1, duration: 0.22),
                            value: character
                        )
                } else {
                    Text(String(character))
                }
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .onChange(of: text) { oldText, newText in
            animateChangedDigits(from: oldText, to: newText)
        }
    }

    private func animateChangedDigits(from oldText: String, to newText: String) {
        guard !reduceMotion else { return }
        let oldCharacters = Array(oldText)
        let newCharacters = Array(newText)
        let now = Date.timeIntervalSinceReferenceDate

        for (index, character) in newCharacters.enumerated() {
            let oldCharacter = oldCharacters.indices.contains(index) ? oldCharacters[index] : nil
            guard let currentDigit = character.wholeNumberValue,
                  oldCharacter != character
            else { continue }

            let elapsed = now - (lastChangeTimes[index] ?? now - 0.18)
            lastChangeTimes[index] = now
            let targetRadius = DigitMotionMath.blurRadius(
                previousDigit: oldCharacter?.wholeNumberValue,
                currentDigit: currentDigit,
                elapsed: elapsed
            )
            let generation = (pulses[index]?.generation ?? 0) + 1
            let currentRadius = pulses[index]?.radius ?? 0
            pulses[index] = DigitMotionPulse(radius: currentRadius, generation: generation)

            withAnimation(.timingCurve(0.45, 0, 0.55, 1, duration: 0.07)) {
                pulses[index] = DigitMotionPulse(radius: targetRadius, generation: generation)
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(70))
                guard pulses[index]?.generation == generation else { return }
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.20)) {
                    pulses[index] = DigitMotionPulse(radius: 0, generation: generation)
                }
            }
        }
    }
}

private struct SippedBlurReplaceTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : SippedMotion.blurReplace)
    }
}

struct SippedCardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: SippedTheme.panelRadius, style: .continuous))
    }
}

extension View {
    func sippedCard(padding: CGFloat = 16) -> some View {
        modifier(SippedCardModifier(padding: padding))
    }

    func sippedFormCanvas() -> some View {
        scrollContentBackground(.hidden)
            .background(SippedTheme.canvas)
            .tint(SippedTheme.chromeAccent)
    }

    func sippedFormRows() -> some View {
        listRowBackground(SippedTheme.surface)
            .listRowSeparatorTint(SippedTheme.line)
    }

    func sippedBlurReplaceTransition() -> some View {
        modifier(SippedBlurReplaceTransitionModifier())
    }
}

struct SippedPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = SippedTheme.chromeAccent
    var foreground: Color = SippedTheme.onChromeAccent
    var font: Font = .headline

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(tint.opacity(configuration.isPressed ? 0.78 : 1),
                        in: RoundedRectangle(cornerRadius: SippedTheme.controlRadius, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SippedChip: View {
    let title: String
    let symbol: String?
    let selected: Bool
    var tint: Color = SippedTheme.chromeAccent
    var selectedForeground: Color = SippedTheme.onChromeAccent

    var body: some View {
        HStack(spacing: 7) {
            if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
        }
        .foregroundStyle(selected ? selectedForeground : SippedTheme.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(selected ? tint : SippedTheme.surface,
                    in: Capsule(style: .continuous))
        .overlay {
            if !selected { Capsule().stroke(SippedTheme.line, lineWidth: 1) }
        }
    }
}

struct KeyboardDismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.black.opacity(0.70)), in: .circle)
        .accessibilityLabel("Dismiss keyboard")
        .accessibilityIdentifier("keyboard.dismiss")
    }
}

struct SippedSectionHeading: View {
    let eyebrow: String?
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(SippedTheme.chromeAccent)
                }
                Text(title).font(.title2.weight(.bold))
            }
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline.monospacedDigit()).foregroundStyle(SippedTheme.secondaryInk)
            }
        }
    }
}

struct SippedSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(SippedTheme.secondaryInk)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(SippedTheme.secondaryInk)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 48)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: SippedTheme.controlRadius, style: .continuous))
    }
}

enum DisplayFormatter {
    static func volume(_ millilitres: Double, units: DisplayUnits, compact: Bool = false) -> String {
        if units == .imperial {
            let ounces = millilitres / 29.5735
            return ounces.formatted(.number.precision(.fractionLength(compact ? 0 : 1))) + " fl oz"
        }
        if millilitres >= 1000 {
            return (millilitres / 1000).formatted(.number.precision(.fractionLength(compact ? 1 : 2))) + " L"
        }
        return millilitres.formatted(.number.precision(.fractionLength(0))) + " mL"
    }

    static func value(_ value: Double, measure: MeasureKind, units: DisplayUnits) -> String {
        switch measure {
        case .fluid: volume(value, units: units, compact: true)
        case .caffeine: value.formatted(.number.precision(.fractionLength(0))) + " mg"
        case .sugar: value.formatted(.number.precision(.fractionLength(1))) + " g"
        case .alcohol: value.formatted(.number.precision(.fractionLength(2))) + " std"
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
