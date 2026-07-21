import SwiftUI

struct SippedLandingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var wordmarkSize: CGFloat = 72
    let onGetStarted: () -> Void

    private var runsShader: Bool {
        scenePhase == .active
            && !reduceMotion
            && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SmokeShaderBackground(runsAnimation: runsShader)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                LinearGradient(
                    stops: [
                        .init(color: SmokePalette.deep.opacity(0.62), location: 0),
                        .init(color: SmokePalette.deep.opacity(0.16), location: 0.42),
                        .init(color: SmokePalette.deep.opacity(0.88), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 72)

                        Text("Sipped")
                            .font(.system(size: wordmarkSize, weight: .bold, design: .serif))
                            .tracking(-2.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Spacer(minLength: 88)

                        Text("A clear record of what you drink.")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(SmokePalette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 24)

            Button("Get Started", action: onGetStarted)
                            .buttonStyle(SippedLandingButtonStyle())
                            .accessibilityHint("Begins Sipped setup")
                            .accessibilityIdentifier("landing.getStarted")

                        Text("Your data stays on this device.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SmokePalette.secondaryText)
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height - 32)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .foregroundStyle(.white)
        }
        .background(SmokePalette.deep.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private enum SmokePalette {
    static let deep = Color(red: 3 / 255, green: 28 / 255, blue: 38 / 255)
    static let secondaryText = Color(red: 234 / 255, green: 249 / 255, blue: 1).opacity(0.84)
}

private struct SippedLandingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SippedTypography.onboardingCTA)
            .foregroundStyle(SmokePalette.deep)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.82 : 0.96),
                in: RoundedRectangle(cornerRadius: SippedTheme.controlRadius, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    SippedLandingView(onGetStarted: {})
}
