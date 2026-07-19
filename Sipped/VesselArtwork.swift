import SwiftUI

private enum VesselPrimitive {
    case svg(String, evenOdd: Bool = false)
    case rect(CGRect)
    case roundedRect(CGRect, radius: CGFloat)

    var evenOdd: Bool {
        if case let .svg(_, evenOdd) = self { return evenOdd }
        return false
    }

    func path(in size: CGSize) -> Path {
        let designPath: Path
        switch self {
        case let .svg(data, _):
            var parser = SVGPathParser(data)
            designPath = parser.path()
        case let .rect(rect):
            designPath = Path(rect)
        case let .roundedRect(rect, radius):
            designPath = Path(roundedRect: rect, cornerRadius: radius)
        }
        return designPath.applying(VesselCanvas.transform(in: size))
    }
}

private struct VesselStrokePart {
    let primitive: VesselPrimitive
    let width: CGFloat
    var lineCap: CGLineCap = .round
    var lineJoin: CGLineJoin = .round
}

private struct VesselSpec {
    let body: VesselPrimitive
    var filledParts: [VesselPrimitive] = []
    var strokeParts: [VesselStrokePart] = []
    let interiorTop: CGFloat
    let interiorBottom: CGFloat
    var liquidFloor: CGFloat = 160
    let wallWidth: CGFloat
    let referenceWidth: CGFloat
}

private enum VesselCanvas {
    static let designSize = CGSize(width: 120, height: 160)

    static func scale(in size: CGSize) -> CGFloat {
        min(size.width / designSize.width, size.height / designSize.height)
    }

    static func frame(in size: CGSize) -> CGRect {
        let scale = scale(in: size)
        let fitted = CGSize(width: designSize.width * scale, height: designSize.height * scale)
        return CGRect(
            x: (size.width - fitted.width) / 2,
            y: (size.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    static func transform(in size: CGSize) -> CGAffineTransform {
        let frame = frame(in: size)
        let scale = scale(in: size)
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: frame.minX, ty: frame.minY)
    }
}

enum VesselStyleRegistry {
    static let supportedArtworkIDs: Set<String> = [
        "glass", "tallGlass", "cup", "mug", "espresso", "takeawaySmall", "takeawayLarge",
        "smallWaterBottle", "bottle", "largeBottle", "stanley", "sports", "juiceBox",
        "juiceBottle", "shake", "slimCan", "can", "tallCan", "softBottle", "beerBottle",
        "schooner", "pint", "stein", "wine", "wineBottle", "shot", "lowball", "party",
        "martini", "flute"
    ]

    static func resolves(_ artworkID: String) -> Bool {
        supportedArtworkIDs.contains(canonicalID(for: artworkID))
    }

    fileprivate static func canonicalID(for artworkID: String) -> String {
        switch artworkID {
        case "takeaway": "takeawaySmall"
        case "carton": "juiceBox"
        case "tumbler": "lowball"
        case "jar": "glass"
        case "carafe": "largeBottle"
        default: artworkID
        }
    }

    fileprivate static func spec(for artworkID: String) -> VesselSpec {
        let id = canonicalID(for: artworkID)
        switch id {
        case "espresso":
            return VesselSpec(
                body: .svg("M40 106 L82 106 L78.5 142 Q77.5 150 69 150 L53 150 Q44.5 150 43.5 142 Z"),
                strokeParts: [.init(primitive: .svg("M80 114 C89.5 112 93.5 117.5 93.5 123 C93.5 129.5 89 133.5 80.5 132"), width: 6.5)],
                interiorTop: 106, interiorBottom: 150, liquidFloor: 158, wallWidth: 6.3, referenceWidth: 48
            )
        case "mug":
            return VesselSpec(
                body: .svg("M20 58 L86 58 L86 144 Q86 150 80 150 L26 150 Q20 150 20 144 Z"),
                strokeParts: [.init(primitive: .svg("M84 78 C101 74 109 84 109 95 C109 107 99 116 84 112"), width: 11)],
                interiorTop: 58, interiorBottom: 150, liquidFloor: 158, wallWidth: 8, referenceWidth: 74
            )
        case "takeawaySmall":
            return VesselSpec(
                body: .svg("M35 67 L85 67 L79 144 Q78 150 70 150 L50 150 Q42 150 41 144 Z"),
                filledParts: [
                    .svg("M38 46 L82 42.5 L84.5 56 L35.5 58 Z"),
                    .roundedRect(CGRect(x: 30, y: 56, width: 60, height: 11), radius: 2.5)
                ],
                interiorTop: 67, interiorBottom: 150, liquidFloor: 158, wallWidth: 5, referenceWidth: 58
            )
        case "takeawayLarge":
            return VesselSpec(
                body: .svg("M33 44 L87 44 L80 144 Q79 150 70 150 L50 150 Q41 150 40 144 Z"),
                filledParts: [
                    .svg("M36 22 L84 18.5 L86.5 33 L33.5 35 Z"),
                    .roundedRect(CGRect(x: 28, y: 33, width: 64, height: 12), radius: 2.5)
                ],
                interiorTop: 44, interiorBottom: 150, liquidFloor: 158, wallWidth: 5, referenceWidth: 62
            )
        case "glass":
            return VesselSpec(
                body: .svg("M36 66 L84 66 L78 144 Q77 150 69 150 L51 150 Q44 150 42 144 Z"),
                interiorTop: 66, interiorBottom: 150, liquidFloor: 158, wallWidth: 5.5, referenceWidth: 56
            )
        case "tallGlass":
            return VesselSpec(
                body: .svg("M38 30 L82 30 L77 144 Q76 150 69 150 L51 150 Q44 150 43 144 Z"),
                interiorTop: 30, interiorBottom: 150, liquidFloor: 158, wallWidth: 5.5, referenceWidth: 52
            )
        case "bottle":
            let body = "M51 6 L69 6 L71 18 C76 26 86 34 87 48 L87 54 C87 57.5 82.5 57.5 82.5 61 C82.5 64.5 87 64.5 87 68 C87 71.5 82.5 71.5 82.5 75 C82.5 78.5 87 78.5 87 82 L87 96 C87 102 84 104 84 110 C84 116 87 118 87 124 L87 134 Q87 150 71 150 L49 150 Q33 150 33 134 L33 124 C33 118 36 116 36 110 C36 104 33 102 33 96 L33 82 C33 78.5 37.5 78.5 37.5 75 C37.5 71.5 33 71.5 33 68 C33 64.5 37.5 64.5 37.5 61 C37.5 57.5 33 57.5 33 54 L33 48 C34 34 44 26 49 18 Z"
            return VesselSpec(body: .svg(body), interiorTop: 6, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.2, referenceWidth: 60)
        case "largeBottle":
            return VesselSpec(
                body: .svg("M48 27 L72 27 C82 32 88 44 88 62 L88 140 Q88 150 78 150 L42 150 Q32 150 32 140 L32 62 C32 44 38 32 48 27 Z"),
                filledParts: [
                    .roundedRect(CGRect(x: 46, y: 8, width: 28, height: 16), radius: 4),
                    .roundedRect(CGRect(x: 48, y: 23, width: 24, height: 4.5), radius: 2)
                ],
                interiorTop: 27, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.6, referenceWidth: 62
            )
        case "slimCan":
            return VesselSpec(
                body: .svg("M44 50 L76 50 L79 58 L79 141 L76 150 L44 150 L41 141 L41 58 Z"),
                interiorTop: 50, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.5, referenceWidth: 44
            )
        case "can":
            return VesselSpec(
                body: .svg("M40 30 L80 30 L86 44 L86 136 L80 150 L40 150 L34 136 L34 44 Z"),
                interiorTop: 30, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.8, referenceWidth: 58
            )
        case "tallCan":
            return VesselSpec(
                body: .svg("M40 6 L80 6 L86 20 L86 136 L80 150 L40 150 L34 136 L34 20 Z"),
                interiorTop: 6, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.8, referenceWidth: 58
            )
        case "softBottle":
            return VesselSpec(
                body: .svg("M53 10 L67 10 L68 20 C73 27 82 33 83 46 L83 92 C83 98 80 100 80 106 C80 112 83 114 83 120 L83 136 Q83 150 69 150 L51 150 Q37 150 37 136 L37 120 C37 114 40 112 40 106 C40 100 37 98 37 92 L37 46 C38 33 47 27 52 20 Z"),
                interiorTop: 10, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.2, referenceWidth: 52
            )
        case "beerBottle":
            return VesselSpec(
                body: .svg("M55 24 C54.5 38 53 50 52 58 C50 76 41 80 41 94 L41 141 Q41 150 50 150 L70 150 Q79 150 79 141 L79 94 C79 80 70 76 68 58 C67 50 65.5 38 65 24 Z"),
                filledParts: [.roundedRect(CGRect(x: 51, y: 18, width: 18, height: 6.5), radius: 2)],
                interiorTop: 24, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.6, referenceWidth: 44
            )
        case "schooner":
            return VesselSpec(
                body: .svg("M35 44 L85 44 L78 144 Q77 150 69 150 L51 150 Q43 150 42 144 Z"),
                interiorTop: 44, interiorBottom: 150, liquidFloor: 158, wallWidth: 5, referenceWidth: 58
            )
        case "pint":
            return VesselSpec(
                body: .svg("M31 14 L89 14 L81 142 Q80 150 70 150 L50 150 Q40 150 39 142 Z"),
                interiorTop: 14, interiorBottom: 150, liquidFloor: 158, wallWidth: 5.5, referenceWidth: 66
            )
        case "stein":
            return VesselSpec(
                body: .svg("M22 46 L84 46 L84 144 Q84 150 78 150 L28 150 Q22 150 22 144 Z"),
                strokeParts: [.init(primitive: .svg("M82 68 C100 64 108 76 108 89 C108 104 97 114 82 110"), width: 11)],
                interiorTop: 46, interiorBottom: 150, liquidFloor: 158, wallWidth: 8, referenceWidth: 70
            )
        case "wine":
            return VesselSpec(
                body: .svg("M42 48 C40 68 46 84 60 88 C74 84 80 68 78 48 Z"),
                filledParts: [
                    .rect(CGRect(x: 58.2, y: 86, width: 3.6, height: 57)),
                    .roundedRect(CGRect(x: 42, y: 143, width: 36, height: 5), radius: 2.5)
                ],
                interiorTop: 48, interiorBottom: 88, liquidFloor: 94, wallWidth: 3.4, referenceWidth: 44
            )
        case "wineBottle":
            return VesselSpec(
                body: .svg("M55 13 L65 13 L65 50 C65 61 82 63 82 80 L82 140 Q82 150 71 150 L49 150 Q38 150 38 140 L38 80 C38 63 55 61 55 50 Z"),
                filledParts: [.roundedRect(CGRect(x: 52, y: 6, width: 16, height: 8), radius: 2)],
                interiorTop: 13, interiorBottom: 150, liquidFloor: 158, wallWidth: 5, referenceWidth: 50
            )
        case "shake":
            return VesselSpec(
                body: .svg("M35 53 L85 53 L78 146 Q77 152 69 152 L51 152 Q43 152 42 146 Z"),
                filledParts: [
                    .svg("M28 41 L35.5 21 L33.3 10.5 Q32.9 8.2 35.5 7.7 L50.8 5.8 Q53.3 5.5 53.9 7.9 L56.5 12.5 C66 13 76 16.5 82.5 21 C86.5 24 88 28.5 86 31 L92.5 41 Z M58.5 17.5 C65.5 18.3 72.5 20.5 78 24.5 Q80 26.4 77.8 28.2 C71.5 26.8 64 24.3 58.6 22.6 Q56.3 20 58.5 17.5 Z", evenOdd: true),
                    .roundedRect(CGRect(x: 26, y: 41, width: 68, height: 12), radius: 2.5)
                ],
                interiorTop: 53, interiorBottom: 152, liquidFloor: 160, wallWidth: 5, referenceWidth: 56
            )
        case "cup":
            return VesselSpec(
                body: .svg("M30 84 L90 84 L84 138 Q83 144 76 144 L44 144 Q37 144 36 138 Z"),
                strokeParts: [.init(primitive: .svg("M88 94 C101 92 105 100 104 106 C103 114 96 120 87 118"), width: 9)],
                interiorTop: 84, interiorBottom: 144, liquidFloor: 152, wallWidth: 7, referenceWidth: 66
            )
        case "juiceBox":
            return VesselSpec(
                body: .roundedRect(CGRect(x: 38, y: 52, width: 44, height: 98), radius: 4),
                strokeParts: [.init(primitive: .svg("M70 55 L70 32 L57 36"), width: 5.5)],
                interiorTop: 52, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.8, referenceWidth: 50
            )
        case "juiceBottle":
            return VesselSpec(
                body: .svg("M50 33 L70 33 L70 44 C70 50 84 52 85 64 L85 136 Q85 150 71 150 L49 150 Q35 150 35 136 L35 64 C36 52 50 50 50 44 Z"),
                filledParts: [
                    .roundedRect(CGRect(x: 46, y: 18, width: 28, height: 10), radius: 3),
                    .roundedRect(CGRect(x: 48, y: 27, width: 24, height: 6), radius: 2.5)
                ],
                interiorTop: 33, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.6, referenceWidth: 56
            )
        case "party":
            return VesselSpec(
                body: .svg("M34 46 L86 46 L76 146 Q75 152 68 152 L52 152 Q45 152 44 146 Z"),
                filledParts: [.roundedRect(CGRect(x: 30, y: 36, width: 60, height: 11), radius: 3.5)],
                interiorTop: 46, interiorBottom: 152, liquidFloor: 160, wallWidth: 5, referenceWidth: 58
            )
        case "stanley":
            return VesselSpec(
                body: .svg("M33 40 L87 40 L82 144 Q81.5 150 74 150 L46 150 Q38.5 150 38 144 Z"),
                filledParts: [
                    .roundedRect(CGRect(x: 50, y: 6, width: 5, height: 24), radius: 2.5),
                    .roundedRect(CGRect(x: 30, y: 26, width: 60, height: 6), radius: 2),
                    .roundedRect(CGRect(x: 32, y: 31, width: 56, height: 10), radius: 2.5)
                ],
                strokeParts: [.init(primitive: .svg("M85 58 L98 58 Q104 58 104 64 L104 92 Q104 98 98 98 L86 98"), width: 8.5)],
                interiorTop: 40, interiorBottom: 150, liquidFloor: 158, wallWidth: 6.3, referenceWidth: 60
            )
        case "sports":
            return VesselSpec(
                body: .svg("M40 39 C32 40 29 44 30 49 C31 55 39 56 39 62 C39 68 30 67 30 77 L30 138 Q30 150 43 150 L77 150 Q90 150 90 138 L90 77 C90 67 81 68 81 62 C81 56 89 55 90 49 C91 44 88 40 80 39 Z"),
                filledParts: [
                    .roundedRect(CGRect(x: 55, y: 12, width: 10, height: 10), radius: 2),
                    .svg("M51 14 Q51 5 60 5 Q69 5 69 14 Z"),
                    .roundedRect(CGRect(x: 36, y: 21, width: 48, height: 18), radius: 4)
                ],
                interiorTop: 39, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.8, referenceWidth: 66
            )
        case "smallWaterBottle":
            let body = "M50 21 C50 30 35 36 33 52 L33 60 C33 63.5 29.5 63.5 29.5 67 C29.5 70.5 33 70.5 33 74 L33 104 C33 107.5 29.5 107.5 29.5 111 C29.5 114.5 33 114.5 33 118 L33 136 Q33 150 47 150 L73 150 Q87 150 87 136 L87 118 C87 114.5 90.5 114.5 90.5 111 C90.5 107.5 87 107.5 87 104 L87 74 C87 70.5 90.5 70.5 90.5 67 C90.5 63.5 87 63.5 87 60 L87 52 C85 36 70 30 70 21 Z"
            return VesselSpec(
                body: .svg(body),
                filledParts: [.roundedRect(CGRect(x: 50, y: 10, width: 20, height: 12), radius: 3)],
                interiorTop: 21, interiorBottom: 150, liquidFloor: 158, wallWidth: 4.2, referenceWidth: 68
            )
        case "martini":
            return VesselSpec(
                body: .svg("M24 40 L96 40 L63 79 L63 82 L57 82 L57 79 Z"),
                filledParts: [
                    .rect(CGRect(x: 58.3, y: 80, width: 3.4, height: 58)),
                    .roundedRect(CGRect(x: 42, y: 138, width: 36, height: 5), radius: 2.5)
                ],
                interiorTop: 40, interiorBottom: 82, liquidFloor: 88, wallWidth: 3.4, referenceWidth: 78
            )
        case "flute":
            return VesselSpec(
                body: .svg("M47 16 C46 46 48 64 60 68 C72 64 74 46 73 16 Z"),
                filledParts: [
                    .rect(CGRect(x: 58.3, y: 66, width: 3.4, height: 72)),
                    .roundedRect(CGRect(x: 42, y: 138, width: 36, height: 5), radius: 2.5)
                ],
                interiorTop: 16, interiorBottom: 68, liquidFloor: 74, wallWidth: 3.2, referenceWidth: 32
            )
        case "lowball":
            return VesselSpec(
                body: .svg("M34 96 L86 96 L84 145 Q84 152 76 152 L44 152 Q36 152 36 145 Z"),
                interiorTop: 96, interiorBottom: 152, liquidFloor: 160, wallWidth: 6, referenceWidth: 58
            )
        case "shot":
            return VesselSpec(
                body: .svg("M44 116 L76 116 L72 148 Q71 152 66 152 L54 152 Q49 152 48 148 Z"),
                interiorTop: 116, interiorBottom: 152, liquidFloor: 160, wallWidth: 5.5, referenceWidth: 38
            )
        default:
            return spec(for: "glass")
        }
    }
}

private struct SVGPathParser {
    private let characters: [Character]
    private var index = 0

    init(_ data: String) { characters = Array(data) }

    mutating func path() -> Path {
        var result = Path()
        var command: Character?
        while true {
            skipSeparators()
            guard index < characters.count else { break }
            if characters[index].isLetter {
                command = characters[index]
                index += 1
            }
            guard let command else { break }
            switch command {
            case "M":
                guard let x = number(), let y = number() else { return result }
                result.move(to: CGPoint(x: x, y: y))
            case "L":
                guard let x = number(), let y = number() else { return result }
                result.addLine(to: CGPoint(x: x, y: y))
            case "C":
                guard let x1 = number(), let y1 = number(), let x2 = number(), let y2 = number(),
                      let x = number(), let y = number() else { return result }
                result.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            case "Q":
                guard let x1 = number(), let y1 = number(), let x = number(), let y = number() else { return result }
                result.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x1, y: y1))
            case "Z", "z":
                result.closeSubpath()
            default:
                return result
            }
        }
        return result
    }

    private mutating func skipSeparators() {
        while index < characters.count, characters[index].isWhitespace || characters[index] == "," { index += 1 }
    }

    private mutating func number() -> CGFloat? {
        skipSeparators()
        let start = index
        if index < characters.count, (characters[index] == "-" || characters[index] == "+") { index += 1 }
        while index < characters.count, characters[index].isNumber { index += 1 }
        if index < characters.count, characters[index] == "." {
            index += 1
            while index < characters.count, characters[index].isNumber { index += 1 }
        }
        guard start < index, let value = Double(String(characters[start..<index])) else { return nil }
        return CGFloat(value)
    }
}

private struct VesselBodyShape: Shape {
    let style: String
    func path(in rect: CGRect) -> Path { VesselStyleRegistry.spec(for: style).body.path(in: rect.size) }
}

private struct FluidFillShape: Shape {
    let spec: VesselSpec
    var fraction: Double
    var slosh: Double
    var slopeDegrees: Double = 0

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(fraction, slosh) }
        set { fraction = newValue.first; slosh = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let frame = VesselCanvas.frame(in: rect.size)
        let scale = VesselCanvas.scale(in: rect.size)
        let fill = FillAmountMath.clampedFraction(fraction)
        let top = frame.minY + spec.interiorTop * scale
        let bottom = frame.minY + spec.interiorBottom * scale
        let floor = frame.minY + spec.liquidFloor * scale
        let baseline = bottom - (bottom - top) * fill
        let amplitude = min((bottom - top) * 0.018, 5) * slosh
        let slopeDelta = tan(slopeDegrees * .pi / 180) * frame.width
        func surfaceY(_ position: CGFloat) -> CGFloat {
            baseline + (position - 0.5) * slopeDelta
        }
        var path = Path()
        path.move(to: CGPoint(x: frame.minX, y: surfaceY(0)))
        path.addCurve(
            to: CGPoint(x: frame.midX, y: surfaceY(0.5)),
            control1: CGPoint(x: frame.minX + frame.width * 0.16, y: surfaceY(0.16) + amplitude),
            control2: CGPoint(x: frame.minX + frame.width * 0.34, y: surfaceY(0.34) + amplitude)
        )
        path.addCurve(
            to: CGPoint(x: frame.maxX, y: surfaceY(1)),
            control1: CGPoint(x: frame.minX + frame.width * 0.66, y: surfaceY(0.66) - amplitude),
            control2: CGPoint(x: frame.minX + frame.width * 0.84, y: surfaceY(0.84) - amplitude)
        )
        path.addLine(to: CGPoint(x: frame.maxX, y: floor))
        path.addLine(to: CGPoint(x: frame.minX, y: floor))
        path.closeSubpath()
        return path
    }
}

private struct FluidSurfaceBandShape: Shape {
    let spec: VesselSpec
    let relativeHeight: CGFloat
    var fraction: Double
    var slosh: Double
    var slopeDegrees: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(fraction, slosh) }
        set { fraction = newValue.first; slosh = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let frame = VesselCanvas.frame(in: rect.size)
        let scale = VesselCanvas.scale(in: rect.size)
        let fill = FillAmountMath.clampedFraction(fraction)
        let top = frame.minY + spec.interiorTop * scale
        let bottom = frame.minY + spec.interiorBottom * scale
        let baseline = bottom - (bottom - top) * fill
        let amplitude = min((bottom - top) * 0.018, 5) * slosh
        let bandHeight = max(1.5, spec.referenceWidth * relativeHeight * scale)
        let slopeDelta = tan(slopeDegrees * .pi / 180) * frame.width
        func surfaceY(_ position: CGFloat) -> CGFloat {
            baseline + (position - 0.5) * slopeDelta
        }

        var path = Path()
        path.move(to: CGPoint(x: frame.minX, y: surfaceY(0)))
        path.addCurve(
            to: CGPoint(x: frame.midX, y: surfaceY(0.5)),
            control1: CGPoint(x: frame.minX + frame.width * 0.16, y: surfaceY(0.16) + amplitude),
            control2: CGPoint(x: frame.minX + frame.width * 0.34, y: surfaceY(0.34) + amplitude)
        )
        path.addCurve(
            to: CGPoint(x: frame.maxX, y: surfaceY(1)),
            control1: CGPoint(x: frame.minX + frame.width * 0.66, y: surfaceY(0.66) - amplitude),
            control2: CGPoint(x: frame.minX + frame.width * 0.84, y: surfaceY(0.84) - amplitude)
        )
        path.addLine(to: CGPoint(x: frame.maxX, y: surfaceY(1) + bandHeight))
        path.addCurve(
            to: CGPoint(x: frame.midX, y: surfaceY(0.5) + bandHeight),
            control1: CGPoint(x: frame.minX + frame.width * 0.84, y: surfaceY(0.84) - amplitude + bandHeight),
            control2: CGPoint(x: frame.minX + frame.width * 0.66, y: surfaceY(0.66) - amplitude + bandHeight)
        )
        path.addCurve(
            to: CGPoint(x: frame.minX, y: surfaceY(0) + bandHeight),
            control1: CGPoint(x: frame.minX + frame.width * 0.34, y: surfaceY(0.34) + amplitude + bandHeight),
            control2: CGPoint(x: frame.minX + frame.width * 0.16, y: surfaceY(0.16) + amplitude + bandHeight)
        )
        path.closeSubpath()
        return path
    }
}

struct SurfaceBandSpec {
    let color: Color
    let relativeHeight: CGFloat
    var slopeDegrees: Double = 0
}

struct DrinkVisualSpec {
    let liquid: Color
    let band: SurfaceBandSpec?
    let isCarbonated: Bool
    let prefersDarkText: Bool

    static let carbonatedIDs: Set<String> = [
        "water-sparkling", "soft-cola", "soft-lemonade", "energy-regular", "energy-sugarfree",
        "kombucha-original", "kombucha-ginger", "beer-lager", "beer-ale"
    ]

    static func profile(definitionID: String?, category: DrinkCategory) -> DrinkVisualSpec {
        func color(_ hex: UInt32) -> Color {
            Color(
                red: Double((hex >> 16) & 0xff) / 255,
                green: Double((hex >> 8) & 0xff) / 255,
                blue: Double(hex & 0xff) / 255
            )
        }
        func profile(_ liquid: UInt32, _ band: UInt32? = nil, _ height: CGFloat = 0.08, slope: Double = 0) -> DrinkVisualSpec {
            let id = definitionID ?? ""
            let red = Double((liquid >> 16) & 0xff) / 255
            let green = Double((liquid >> 8) & 0xff) / 255
            let blue = Double(liquid & 0xff) / 255
            let relativeLuminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            return DrinkVisualSpec(
                liquid: color(liquid),
                band: band.map { SurfaceBandSpec(color: color($0), relativeHeight: height, slopeDegrees: slope) },
                isCarbonated: carbonatedIDs.contains(id),
                prefersDarkText: relativeLuminance > 0.56
            )
        }

        switch definitionID {
        case "water-still": return profile(0x3cc9f7)
        case "water-sparkling": return profile(0x5ed4f9)
        case "coffee-espresso": return profile(0x52301a, 0xe8c194)
        case "coffee-long-black": return profile(0x4a2b16, 0xd9a86b, 0.04)
        case "coffee-flat-white": return profile(0xecc28d, 0xfbe7c6)
        case "coffee-latte": return profile(0xecc28d, 0xfbe7c6)
        case "coffee-cappuccino": return profile(0xecc28d, 0xfbe7c6, 0.12)
        case "coffee-filter": return profile(0x5a3620)
        case "coffee-cold-brew": return profile(0x3f2413)
        case "coffee-iced": return profile(0xc99a63, 0xecd9bd)
        case "tea-black": return profile(0xb3702c)
        case "tea-green": return profile(0xa8b558)
        case "tea-chai": return profile(0xc9945a, 0xe8cba3)
        case "soft-cola": return profile(0x1b120e, 0xb8b193, 0.04, slope: -1.5)
        case "soft-lemonade": return profile(0xf2d16b, 0xf9e9b8, 0.04)
        case "energy-regular": return profile(0xcddc4e)
        case "energy-sugarfree": return profile(0x7fd8d2)
        case "juice-orange": return profile(0xe8a548, 0xf4c886)
        case "juice-apple": return profile(0xd9b45a, 0xefdca3)
        case "milk-dairy": return profile(0xf2ead8)
        case "milk-oat": return profile(0xe3d3b4)
        case "smoothie-fruit": return profile(0xc2517c, 0xde7ea3)
        case "smoothie-green": return profile(0x7da05a, 0xa8c284)
        case "kombucha-original": return profile(0xc78f3f)
        case "kombucha-ginger": return profile(0xd07a2e)
        case "beer-lager": return profile(0xe9b23c, 0xf7ecd4, 0.11)
        case "beer-ale": return profile(0xc07a2a, 0xf3e3c2, 0.11)
        case "wine-red": return profile(0x7c1a2b)
        case "wine-white": return profile(0xd9b45a)
        case "spirits-whisky": return profile(0xb98336)
        case "spirits-gin": return profile(0xcfe0da)
        case "other-custom": return profile(0x7fa89f)
        default:
            switch category {
            case .water: return profile(0x3cc9f7)
            case .coffee: return profile(0x5a3620, 0xe8c194)
            case .tea: return profile(0xb3702c)
            case .softDrinks: return profile(0x1b120e, 0xb8b193, 0.04)
            case .energyDrinks: return profile(0xcddc4e)
            case .juice: return profile(0xe8a548, 0xf4c886)
            case .milk: return profile(0xf2ead8)
            case .smoothies: return profile(0xc2517c, 0xde7ea3)
            case .kombucha: return profile(0xc78f3f)
            case .beer: return profile(0xe9b23c, 0xf7ecd4, 0.11)
            case .wine: return profile(0x7c1a2b)
            case .spirits: return profile(0xb98336)
            case .other: return profile(0x7fa89f)
            }
        }
    }
}

struct VesselArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: String
    let liquidColor: Color
    var fillFraction: Double
    var showDetails = true
    var surfaceBand: SurfaceBandSpec? = nil
    var showsParticles = false
    @State private var slosh = 0.0
    @State private var previousFraction = 0.0

    private var motionReduced: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("--force-reduce-motion")
    }

    var body: some View {
        GeometryReader { proxy in
            let spec = VesselStyleRegistry.spec(for: style)
            let fraction = FillAmountMath.clampedFraction(fillFraction)
            let scale = VesselCanvas.scale(in: proxy.size)
            let bodyShape = VesselBodyShape(style: style)
            ZStack {
                ForEach(Array(spec.strokeParts.enumerated()), id: \.offset) { _, part in
                    part.primitive.path(in: proxy.size)
                        .stroke(
                            SippedTheme.vessel,
                            style: StrokeStyle(
                                lineWidth: part.width * scale,
                                lineCap: part.lineCap,
                                lineJoin: part.lineJoin
                            )
                        )
                }
                bodyShape.fill(SippedTheme.vessel)
                ForEach(Array(spec.filledParts.enumerated()), id: \.offset) { _, part in
                    part.path(in: proxy.size)
                        .fill(SippedTheme.vessel, style: FillStyle(eoFill: part.evenOdd))
                }

                if fraction > 0.001 {
                    FluidFillShape(
                        spec: spec,
                        fraction: fraction,
                        slosh: motionReduced ? 0 : slosh,
                        slopeDegrees: surfaceBand?.slopeDegrees ?? 0
                    )
                        .fill(liquidColor)
                        .mask(bodyShape.fill(.white))

                    if showDetails, let surfaceBand {
                        FluidSurfaceBandShape(
                            spec: spec,
                            relativeHeight: surfaceBand.relativeHeight,
                            fraction: fraction,
                            slosh: motionReduced ? 0 : slosh,
                            slopeDegrees: surfaceBand.slopeDegrees
                        )
                            .fill(surfaceBand.color)
                            .mask(
                                FluidFillShape(
                                    spec: spec,
                                    fraction: fraction,
                                    slosh: motionReduced ? 0 : slosh,
                                    slopeDegrees: surfaceBand.slopeDegrees
                                ).fill(.white)
                            )
                            .mask(bodyShape.fill(.white))
                    }

                    if showsParticles, !motionReduced {
                        BubbleLayer(spec: spec, fraction: fraction)
                            .mask(
                                FluidFillShape(
                                    spec: spec,
                                    fraction: fraction,
                                    slosh: slosh,
                                    slopeDegrees: surfaceBand?.slopeDegrees ?? 0
                                ).fill(.white)
                            )
                            .mask(bodyShape.fill(.white))
                    }
                }

                bodyShape.stroke(
                    SippedTheme.vessel,
                    style: StrokeStyle(lineWidth: spec.wallWidth * scale, lineJoin: .round)
                )
            }
            .onAppear { previousFraction = fraction }
            .onChange(of: fraction) { oldValue, newValue in
                guard !motionReduced, abs(newValue - oldValue) > 0.004 else {
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
}

private struct BubbleLayer: View {
    let spec: VesselSpec
    let fraction: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let frame = VesselCanvas.frame(in: size)
                let scale = VesselCanvas.scale(in: size)
                let top = frame.minY + spec.interiorTop * scale
                let bottom = frame.minY + spec.interiorBottom * scale
                let surface = bottom - (bottom - top) * FillAmountMath.clampedFraction(fraction)
                let filledHeight = max(0, bottom - surface)
                guard filledHeight > 1 else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<8 {
                    let speed = 0.16 + Double(index % 3) * 0.035
                    let phase = (time * speed + Double(index) * 0.137).truncatingRemainder(dividingBy: 1)
                    let drift = sin(time * 0.9 + Double(index) * 1.7) * frame.width * 0.035
                    let x = frame.midX + (Double(index % 4) - 1.5) * frame.width * 0.11 + drift
                    let y = bottom - filledHeight * phase
                    let diameter = max(2.5, min(6, frame.width * (0.022 + Double(index % 3) * 0.005)))
                    let fade = min(1, phase / 0.12) * min(1, (1 - phase) / 0.22)
                    context.opacity = 0.52 * fade
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DrinkArtwork: View {
    let category: DrinkCategory
    let artworkID: String
    var definitionID: String? = nil
    var fillFraction: Double = 0.76
    var showsParticles = false

    var visualSpec: DrinkVisualSpec { DrinkVisualSpec.profile(definitionID: definitionID, category: category) }
    var liquidColor: Color { visualSpec.liquid }

    var body: some View {
        VesselArtwork(
            style: artworkID,
            liquidColor: visualSpec.liquid,
            fillFraction: fillFraction,
            showDetails: true,
            surfaceBand: visualSpec.band,
            showsParticles: showsParticles && visualSpec.isCarbonated
        )
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }
}
