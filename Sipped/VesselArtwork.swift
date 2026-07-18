import SwiftUI

struct VesselBodyShape: Shape {
    let style: String

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        switch style {
        case "bottle":
            path.move(to: CGPoint(x: w * 0.40, y: h * 0.02))
            path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.02))
            path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.14))
            path.addCurve(to: CGPoint(x: w * 0.77, y: h * 0.29), control1: CGPoint(x: w * 0.62, y: h * 0.20), control2: CGPoint(x: w * 0.74, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.92))
            path.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.98), control: CGPoint(x: w * 0.72, y: h * 0.98))
            path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.98))
            path.addQuadCurve(to: CGPoint(x: w * 0.27, y: h * 0.92), control: CGPoint(x: w * 0.28, y: h * 0.98))
            path.addLine(to: CGPoint(x: w * 0.23, y: h * 0.29))
            path.addCurve(to: CGPoint(x: w * 0.39, y: h * 0.14), control1: CGPoint(x: w * 0.26, y: h * 0.22), control2: CGPoint(x: w * 0.38, y: h * 0.20))
            path.closeSubpath()
        case "can":
            path.addRoundedRect(in: CGRect(x: w * 0.22, y: h * 0.035, width: w * 0.56, height: h * 0.93), cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        case "wine":
            path.move(to: CGPoint(x: w * 0.25, y: h * 0.03))
            path.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.60), control1: CGPoint(x: w * 0.26, y: h * 0.38), control2: CGPoint(x: w * 0.34, y: h * 0.57))
            path.addCurve(to: CGPoint(x: w * 0.75, y: h * 0.03), control1: CGPoint(x: w * 0.66, y: h * 0.57), control2: CGPoint(x: w * 0.74, y: h * 0.38))
            path.closeSubpath()
        case "takeaway":
            path.move(to: CGPoint(x: w * 0.22, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.96))
            path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.96))
            path.closeSubpath()
        case "carton":
            path.move(to: CGPoint(x: w * 0.25, y: h * 0.20))
            path.addLine(to: CGPoint(x: w * 0.43, y: h * 0.03))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.20))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.97))
            path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.97))
            path.closeSubpath()
        case "carafe":
            path.move(to: CGPoint(x: w * 0.38, y: h * 0.03))
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.03))
            path.addCurve(to: CGPoint(x: w * 0.82, y: h * 0.93), control1: CGPoint(x: w * 0.61, y: h * 0.43), control2: CGPoint(x: w * 0.82, y: h * 0.55))
            path.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.98), control: CGPoint(x: w * 0.80, y: h * 0.98))
            path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.98))
            path.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.93), control: CGPoint(x: w * 0.20, y: h * 0.98))
            path.addCurve(to: CGPoint(x: w * 0.38, y: h * 0.03), control1: CGPoint(x: w * 0.18, y: h * 0.55), control2: CGPoint(x: w * 0.39, y: h * 0.43))
        case "pint":
            path.move(to: CGPoint(x: w * 0.22, y: h * 0.03))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.03))
            path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.97))
            path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.97))
            path.closeSubpath()
        case "shot":
            path.move(to: CGPoint(x: w * 0.28, y: h * 0.18))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.18))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.90))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.90))
            path.closeSubpath()
        case "jar":
            path.addRoundedRect(in: CGRect(x: w * 0.18, y: h * 0.10, width: w * 0.64, height: h * 0.87), cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        case "espresso":
            path.addRoundedRect(in: CGRect(x: w * 0.22, y: h * 0.30, width: w * 0.56, height: h * 0.48), cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        case "cup":
            path.addRoundedRect(in: CGRect(x: w * 0.18, y: h * 0.18, width: w * 0.64, height: h * 0.62), cornerSize: CGSize(width: w * 0.12, height: w * 0.12))
        case "mug", "stein":
            path.addRoundedRect(in: CGRect(x: w * 0.15, y: h * 0.12, width: w * 0.63, height: h * 0.72), cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        case "tumbler":
            path.move(to: CGPoint(x: w * 0.20, y: h * 0.15))
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.15))
            path.addLine(to: CGPoint(x: w * 0.71, y: h * 0.88))
            path.addQuadCurve(to: CGPoint(x: w * 0.29, y: h * 0.88), control: CGPoint(x: w * 0.50, y: h * 0.95))
            path.closeSubpath()
        default:
            let x = style == "tallGlass" ? w * 0.28 : w * 0.18
            let width = style == "tallGlass" ? w * 0.44 : w * 0.64
            path.addRoundedRect(in: CGRect(x: x, y: h * 0.05, width: width, height: h * 0.92), cornerSize: CGSize(width: w * 0.11, height: w * 0.11))
        }
        return path
    }
}

private struct FluidFillShape: Shape {
    var fraction: Double
    var slosh: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(fraction, slosh) }
        set { fraction = newValue.first; slosh = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let fill = max(0, min(1, fraction))
        let baseline = rect.maxY - rect.height * fill
        let amplitude = min(rect.height * 0.028, 7) * slosh
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: baseline))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: baseline),
            control1: CGPoint(x: rect.width * 0.16, y: baseline + amplitude),
            control2: CGPoint(x: rect.width * 0.34, y: baseline + amplitude)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: baseline),
            control1: CGPoint(x: rect.width * 0.66, y: baseline - amplitude),
            control2: CGPoint(x: rect.width * 0.84, y: baseline - amplitude)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct VesselArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: String
    let liquidColor: Color
    var fillFraction: Double
    var showDetails = true
    @State private var slosh = 0.0
    @State private var previousFraction = 0.0

    var body: some View {
        GeometryReader { proxy in
            let fraction = max(0, min(1, fillFraction))
            let body = VesselBodyShape(style: style)
            let strokeWidth = max(1.6, min(3.2, proxy.size.width * 0.028))
            ZStack {
                handle(in: proxy.size, width: strokeWidth)
                body.fill(SippedTheme.surface.opacity(0.92))
                FluidFillShape(fraction: fraction, slosh: reduceMotion ? 0 : slosh)
                    .fill(
                        LinearGradient(
                            colors: [liquidColor.opacity(0.82), liquidColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(body)
                if fraction > 0.015 {
                    Capsule()
                        .fill(Color.white.opacity(style == "pint" || style == "mug" ? 0.55 : 0.28))
                        .frame(width: proxy.size.width * surfaceWidth, height: max(2, min(7, proxy.size.height * 0.035)))
                        .rotationEffect(.degrees(reduceMotion ? 0 : slosh * 2.8))
                        .offset(y: proxy.size.height * (0.50 - fraction) + surfaceOffset)
                        .mask(body)
                }
                body.stroke(SippedTheme.ink.opacity(0.78), lineWidth: strokeWidth)
                if showDetails { details(in: proxy.size, width: strokeWidth) }
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width * 0.36, y: proxy.size.height * 0.22))
                    path.addCurve(to: CGPoint(x: proxy.size.width * 0.34, y: proxy.size.height * 0.56),
                                  control1: CGPoint(x: proxy.size.width * 0.31, y: proxy.size.height * 0.32),
                                  control2: CGPoint(x: proxy.size.width * 0.31, y: proxy.size.height * 0.46))
                }
                .stroke(Color.white.opacity(0.34), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .mask(body)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: fraction)
            .onAppear { previousFraction = fraction }
            .onChange(of: fraction) { oldValue, newValue in
                guard !reduceMotion, abs(newValue - oldValue) > 0.004 else {
                    previousFraction = newValue
                    return
                }
                slosh = newValue > previousFraction ? -1 : 1
                previousFraction = newValue
                Task { @MainActor in
                    await Task.yield()
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.62)) { slosh = 0 }
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var surfaceWidth: CGFloat {
        switch style {
        case "bottle": 0.42
        case "can": 0.48
        case "wine": 0.42
        case "tallGlass": 0.36
        default: 0.52
        }
    }

    private var surfaceOffset: CGFloat {
        switch style {
        case "espresso": 12
        case "cup", "mug", "stein", "tumbler": 5
        default: 0
        }
    }

    @ViewBuilder
    private func handle(in size: CGSize, width: CGFloat) -> some View {
        if ["mug", "cup", "espresso", "stein"].contains(style) {
            RoundedRectangle(cornerRadius: size.width * 0.16)
                .stroke(SippedTheme.ink.opacity(0.78), lineWidth: width)
                .frame(width: size.width * 0.31, height: size.height * (style == "espresso" ? 0.23 : 0.34))
                .offset(x: size.width * 0.34, y: size.height * (style == "espresso" ? 0.10 : 0.04))
        }
    }

    @ViewBuilder
    private func details(in size: CGSize, width: CGFloat) -> some View {
        if style == "wine" {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.60))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.91))
                path.move(to: CGPoint(x: size.width * 0.30, y: size.height * 0.93))
                path.addLine(to: CGPoint(x: size.width * 0.70, y: size.height * 0.93))
            }.stroke(SippedTheme.ink.opacity(0.78), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        if style == "takeaway" {
            Capsule().fill(SippedTheme.ink.opacity(0.78)).frame(width: size.width * 0.66, height: max(4, size.height * 0.055)).offset(y: -size.height * 0.41)
        }
        if style == "can" {
            Capsule().stroke(SippedTheme.ink.opacity(0.35), lineWidth: width * 0.75).frame(width: size.width * 0.26, height: max(3, size.height * 0.024)).offset(y: -size.height * 0.43)
        }
        if style == "jar" {
            VStack(spacing: max(2, size.height * 0.018)) {
                ForEach(0..<3, id: \.self) { _ in Capsule().fill(SippedTheme.ink.opacity(0.32)).frame(width: size.width * 0.58, height: width * 0.7) }
            }
            .offset(y: -size.height * 0.39)
        }
        if style == "carton" {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.43, y: size.height * 0.03))
                path.addLine(to: CGPoint(x: size.width * 0.43, y: size.height * 0.20))
                path.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.20))
            }.stroke(SippedTheme.ink.opacity(0.45), lineWidth: width)
        }
    }
}

private struct DrinkVisualProfile {
    let liquid: Color
    let accent: Color
    let symbol: String
    let foam: Double
    let bubbles: Int
    let ice: Int
    let band: Bool
    let symbolRotation: Double
}

struct DrinkArtwork: View {
    let category: DrinkCategory
    let artworkID: String
    var definitionID: String? = nil
    var fillFraction: Double = 0.78

    var body: some View {
        ZStack {
            VesselArtwork(style: artworkID, liquidColor: liquidColor, fillFraction: fillFraction)
                .padding(.horizontal, artworkID == "bottle" ? 2 : 7)
            signatureDetail
        }
    }

    var liquidColor: Color { profile.liquid }

    private var profile: DrinkVisualProfile {
        let pale = Color(red: 0.94, green: 0.91, blue: 0.80)
        let cream = Color(red: 0.97, green: 0.89, blue: 0.69)
        let white = Color.white.opacity(0.90)
        switch definitionID {
        case "water-still": return .init(liquid: .init(red: 0.20, green: 0.70, blue: 0.78), accent: white, symbol: "drop.fill", foam: 0, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "water-sparkling": return .init(liquid: .init(red: 0.33, green: 0.78, blue: 0.84), accent: white, symbol: "sparkles", foam: 0, bubbles: 5, ice: 0, band: false, symbolRotation: 0)
        case "coffee-espresso": return .init(liquid: .init(red: 0.25, green: 0.12, blue: 0.06), accent: cream, symbol: "circle.fill", foam: 0.08, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "coffee-long-black": return .init(liquid: .init(red: 0.31, green: 0.17, blue: 0.09), accent: cream, symbol: "line.3.horizontal", foam: 0.025, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "coffee-flat-white": return .init(liquid: .init(red: 0.55, green: 0.37, blue: 0.22), accent: white, symbol: "minus", foam: 0.13, bubbles: 0, ice: 0, band: true, symbolRotation: 0)
        case "coffee-latte": return .init(liquid: .init(red: 0.66, green: 0.46, blue: 0.27), accent: white, symbol: "leaf.fill", foam: 0.08, bubbles: 0, ice: 0, band: true, symbolRotation: -18)
        case "coffee-cappuccino": return .init(liquid: .init(red: 0.48, green: 0.29, blue: 0.16), accent: white, symbol: "cloud.fill", foam: 0.22, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "coffee-filter": return .init(liquid: .init(red: 0.36, green: 0.20, blue: 0.10), accent: cream, symbol: "triangle.fill", foam: 0.015, bubbles: 0, ice: 0, band: false, symbolRotation: 180)
        case "coffee-cold-brew": return .init(liquid: .init(red: 0.28, green: 0.16, blue: 0.10), accent: white, symbol: "snowflake", foam: 0, bubbles: 0, ice: 2, band: false, symbolRotation: 0)
        case "coffee-iced": return .init(liquid: .init(red: 0.57, green: 0.38, blue: 0.24), accent: white, symbol: "cube.fill", foam: 0.05, bubbles: 0, ice: 3, band: true, symbolRotation: 12)
        case "tea-black": return .init(liquid: .init(red: 0.52, green: 0.35, blue: 0.14), accent: cream, symbol: "leaf.fill", foam: 0, bubbles: 0, ice: 0, band: false, symbolRotation: 42)
        case "tea-green": return .init(liquid: .init(red: 0.58, green: 0.67, blue: 0.31), accent: white, symbol: "leaf.circle.fill", foam: 0, bubbles: 0, ice: 0, band: false, symbolRotation: -16)
        case "tea-chai": return .init(liquid: .init(red: 0.67, green: 0.47, blue: 0.27), accent: white, symbol: "sparkle", foam: 0.08, bubbles: 0, ice: 0, band: true, symbolRotation: 0)
        case "soft-cola": return .init(liquid: .init(red: 0.30, green: 0.10, blue: 0.07), accent: .init(red: 0.94, green: 0.33, blue: 0.24), symbol: "waveform.path", foam: 0.035, bubbles: 4, ice: 0, band: true, symbolRotation: -9)
        case "soft-lemonade": return .init(liquid: .init(red: 0.95, green: 0.73, blue: 0.16), accent: white, symbol: "sun.max.fill", foam: 0.025, bubbles: 4, ice: 0, band: false, symbolRotation: 0)
        case "energy-regular": return .init(liquid: .init(red: 0.67, green: 0.75, blue: 0.14), accent: .init(red: 0.10, green: 0.22, blue: 0.17), symbol: "bolt.fill", foam: 0, bubbles: 3, ice: 0, band: true, symbolRotation: -7)
        case "energy-sugarfree": return .init(liquid: .init(red: 0.36, green: 0.75, blue: 0.72), accent: white, symbol: "bolt.slash", foam: 0, bubbles: 3, ice: 0, band: false, symbolRotation: 7)
        case "juice-orange": return .init(liquid: .init(red: 0.97, green: 0.49, blue: 0.08), accent: white, symbol: "sun.max.fill", foam: 0.018, bubbles: 0, ice: 0, band: true, symbolRotation: 0)
        case "juice-apple": return .init(liquid: .init(red: 0.76, green: 0.69, blue: 0.18), accent: white, symbol: "apple.logo", foam: 0.018, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "milk-dairy": return .init(liquid: pale, accent: .init(red: 0.34, green: 0.55, blue: 0.72), symbol: "drop.circle.fill", foam: 0.035, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "milk-oat": return .init(liquid: .init(red: 0.82, green: 0.75, blue: 0.59), accent: .init(red: 0.28, green: 0.46, blue: 0.29), symbol: "leaf.fill", foam: 0.025, bubbles: 0, ice: 0, band: true, symbolRotation: 24)
        case "smoothie-fruit": return .init(liquid: .init(red: 0.74, green: 0.25, blue: 0.42), accent: white, symbol: "heart.fill", foam: 0.025, bubbles: 2, ice: 0, band: true, symbolRotation: -8)
        case "smoothie-green": return .init(liquid: .init(red: 0.31, green: 0.57, blue: 0.31), accent: white, symbol: "leaf.fill", foam: 0.025, bubbles: 2, ice: 0, band: false, symbolRotation: 22)
        case "kombucha-original": return .init(liquid: .init(red: 0.72, green: 0.52, blue: 0.20), accent: white, symbol: "sparkles", foam: 0.025, bubbles: 5, ice: 0, band: false, symbolRotation: 0)
        case "kombucha-ginger": return .init(liquid: .init(red: 0.79, green: 0.44, blue: 0.13), accent: white, symbol: "flame.fill", foam: 0.025, bubbles: 5, ice: 0, band: true, symbolRotation: 8)
        case "beer-lager": return .init(liquid: .init(red: 0.88, green: 0.60, blue: 0.11), accent: white, symbol: "circle.grid.3x3.fill", foam: 0.11, bubbles: 5, ice: 0, band: false, symbolRotation: 0)
        case "beer-ale": return .init(liquid: .init(red: 0.69, green: 0.34, blue: 0.08), accent: cream, symbol: "cloud.fill", foam: 0.16, bubbles: 3, ice: 0, band: true, symbolRotation: 0)
        case "wine-red": return .init(liquid: .init(red: 0.48, green: 0.08, blue: 0.16), accent: white, symbol: "scribble.variable", foam: 0, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "wine-white": return .init(liquid: .init(red: 0.88, green: 0.74, blue: 0.31), accent: white, symbol: "sparkles", foam: 0, bubbles: 0, ice: 0, band: false, symbolRotation: 0)
        case "spirits-whisky": return .init(liquid: .init(red: 0.66, green: 0.39, blue: 0.12), accent: cream, symbol: "diamond.fill", foam: 0, bubbles: 0, ice: 2, band: false, symbolRotation: 0)
        case "spirits-gin": return .init(liquid: .init(red: 0.73, green: 0.82, blue: 0.78), accent: white, symbol: "snowflake", foam: 0, bubbles: 0, ice: 3, band: true, symbolRotation: 8)
        case "other-broth": return .init(liquid: .init(red: 0.62, green: 0.39, blue: 0.20), accent: cream, symbol: "wind", foam: 0.02, bubbles: 0, ice: 0, band: false, symbolRotation: -90)
        case "other-custom": return .init(liquid: .init(red: 0.35, green: 0.54, blue: 0.49), accent: white, symbol: "drop.degreesign.fill", foam: 0, bubbles: 0, ice: 0, band: true, symbolRotation: 0)
        default: return fallbackProfile
        }
    }

    private var fallbackProfile: DrinkVisualProfile {
        let colors: [Color] = [.init(red: 0.20, green: 0.70, blue: 0.78), .init(red: 0.40, green: 0.23, blue: 0.12), .init(red: 0.58, green: 0.48, blue: 0.20), .init(red: 0.38, green: 0.15, blue: 0.10), .init(red: 0.73, green: 0.78, blue: 0.18), .init(red: 0.96, green: 0.52, blue: 0.11), .init(red: 0.91, green: 0.89, blue: 0.78), .init(red: 0.72, green: 0.27, blue: 0.43), .init(red: 0.72, green: 0.52, blue: 0.20), .init(red: 0.86, green: 0.56, blue: 0.10), .init(red: 0.48, green: 0.08, blue: 0.16), .init(red: 0.68, green: 0.58, blue: 0.37), .init(red: 0.35, green: 0.54, blue: 0.49)]
        let symbols = ["drop.fill", "line.3.horizontal", "leaf.fill", "bubble.left.fill", "bolt.fill", "sun.max.fill", "drop.circle.fill", "heart.fill", "sparkles", "circle.grid.3x3.fill", "scribble.variable", "diamond.fill", "drop.degreesign.fill"]
        let index = DrinkCategory.allCases.firstIndex(of: category) ?? 12
        let variation = (definitionID ?? artworkID).unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 7 }
        return .init(liquid: colors[index], accent: .white.opacity(0.86), symbol: symbols[index], foam: category == .coffee || category == .beer ? 0.08 : 0, bubbles: variation % 3, ice: variation == 5 ? 2 : 0, band: variation.isMultiple(of: 2), symbolRotation: Double(variation * 7 - 21))
    }

    @ViewBuilder private var signatureDetail: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let body = VesselBodyShape(style: artworkID)
            ZStack {
                if profile.band {
                    Capsule()
                        .fill(profile.accent.opacity(0.28))
                        .frame(width: proxy.size.width * 0.42, height: max(3, proxy.size.height * 0.055))
                        .offset(y: proxy.size.height * 0.15)
                }
                if profile.foam > 0 {
                    Capsule()
                        .fill(Color.white.opacity(0.78))
                        .frame(width: proxy.size.width * 0.48, height: max(3, proxy.size.height * profile.foam))
                        .offset(y: proxy.size.height * (0.47 - fillFraction))
                }
                ForEach(0..<profile.bubbles, id: \.self) { index in
                    Circle()
                        .stroke(profile.accent.opacity(0.70), lineWidth: max(0.8, size * 0.012))
                        .frame(width: max(3, size * (0.045 + Double(index % 2) * 0.02)))
                        .offset(x: proxy.size.width * (index.isMultiple(of: 2) ? -0.11 : 0.12),
                                y: proxy.size.height * (0.25 - Double(index) * 0.095))
                }
                ForEach(0..<profile.ice, id: \.self) { index in
                    RoundedRectangle(cornerRadius: max(1, size * 0.018))
                        .stroke(profile.accent.opacity(0.78), lineWidth: max(0.9, size * 0.012))
                        .frame(width: size * 0.15, height: size * 0.12)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? 16 : -13))
                        .offset(x: size * (index.isMultiple(of: 2) ? -0.12 : 0.12), y: size * (0.11 - Double(index) * 0.10))
                }
                Image(systemName: profile.symbol)
                    .font(.system(size: max(8, size * 0.13), weight: .semibold))
                    .foregroundStyle(profile.accent)
                    .rotationEffect(.degrees(profile.symbolRotation))
                    .offset(y: proxy.size.height * 0.12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(body)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
