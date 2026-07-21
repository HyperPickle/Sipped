import SwiftUI

// Custom liquid-themed replacements for the generic Swift Charts graphs.
// ReservoirGraph shows today's cumulative intake as a static liquid level
// through the day; LiquidColumnsChart shows the last seven days as glass
// columns with motion disabled when Reduce Motion is on.

private enum LiquidMotion {
    static func surfaceOffset(x: CGFloat, time: TimeInterval, amplitude: CGFloat) -> CGFloat {
        let primary = sin(x / 34 + CGFloat(time) * 1.5)
        let secondary = sin(x / 13 - CGFloat(time) * 2.2 + 1.2)
        return amplitude * (0.72 * primary + 0.28 * secondary)
    }

    static func riseProgress(since start: Date, at now: Date) -> CGFloat {
        let t = min(max(now.timeIntervalSince(start) / 0.7, 0), 1)
        return CGFloat(1 - pow(1 - t, 3))
    }

    static func niceCeil(_ value: Double) -> Double {
        guard value > 0 else { return 1 }
        let exponent = floor(log10(value))
        let base = pow(10, exponent)
        let mantissa = value / base
        let stepped: Double = mantissa <= 1 ? 1 : mantissa <= 2 ? 2 : mantissa <= 2.5 ? 2.5 : mantissa <= 5 ? 5 : 10
        return stepped * base
    }
}

struct ReservoirPoint: Identifiable, Equatable {
    let id: String
    let time: Date
    let level: Double
    let category: DrinkCategory
    let artworkID: String
    let definitionID: String?
}

struct ReservoirGraph: View {
    let points: [ReservoirPoint]
    let now: Date
    let color: Color
    let valueLabel: (Double) -> String

    private var sortedPoints: [ReservoirPoint] { points.sorted { $0.time < $1.time } }

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        } symbols: {
            ForEach(points) { point in
                DrinkArtwork(
                    category: point.category,
                    artworkID: point.artworkID,
                    definitionID: point.definitionID,
                    showsParticles: false,
                    fit: .visibleBounds
                )
                .frame(width: 18, height: 22)
                .tag(point.id)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let last = sortedPoints.last else { return "No drinks logged" }
        return "Level rose to \(valueLabel(last.level)) across \(sortedPoints.count) drink\(sortedPoints.count == 1 ? "" : "s") today"
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let points = sortedPoints
        guard let first = points.first, let last = points.last else { return }
        let bottomGutter: CGFloat = 20
        let topPad: CGFloat = 16
        let plot = CGRect(x: 0, y: topPad, width: size.width, height: size.height - topPad - bottomGutter)
        guard plot.height > 20, plot.width > 40 else { return }

        // Time domain: first drink to now (or the last drink if it is later),
        // with a small lead-in so the first rise is visible.
        let domainEnd = max(now, last.time)
        let span = max(domainEnd.timeIntervalSince(first.time), 300)
        let domainStart = first.time.addingTimeInterval(-span * 0.05)
        let total = domainEnd.timeIntervalSince(domainStart)
        func xPos(_ date: Date) -> CGFloat {
            plot.minX + CGFloat(date.timeIntervalSince(domainStart) / total) * plot.width
        }

        let maxDisplay = LiquidMotion.niceCeil(last.level * 1.12)
        func yPos(_ value: Double) -> CGFloat {
            plot.maxY - CGFloat(value / maxDisplay) * plot.height
        }

        // Cumulative level through time, smoothed into short ramps that end at
        // each drink's logged moment.
        let rampSeconds = span * 0.045
        func level(at date: Date) -> Double {
            var previousLevel = 0.0
            var previousTime = domainStart
            for point in points {
                let rampStart = max(point.time.addingTimeInterval(-rampSeconds), previousTime)
                if date < rampStart { return previousLevel }
                if date < point.time {
                    let u = date.timeIntervalSince(rampStart) / point.time.timeIntervalSince(rampStart)
                    let eased = u * u * (3 - 2 * u)
                    return previousLevel + (point.level - previousLevel) * eased
                }
                previousLevel = point.level
                previousTime = point.time
            }
            return previousLevel
        }

        func surfaceY(atX x: CGFloat) -> CGFloat {
            let date = domainStart.addingTimeInterval(TimeInterval(x / plot.width) * total)
            return min(max(yPos(level(at: date)), plot.minY), plot.maxY)
        }

        // Gridlines and y labels.
        for fraction in [0.5, 1.0] {
            let y = yPos(maxDisplay * fraction)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(line, with: .color(SippedTheme.line), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            context.draw(
                Text(valueLabel(maxDisplay * fraction)).font(.caption2).foregroundStyle(SippedTheme.secondaryInk),
                at: CGPoint(x: plot.minX + 2, y: y - 8), anchor: .leading)
        }
        var baseline = Path()
        baseline.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        baseline.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(baseline, with: .color(SippedTheme.line), lineWidth: 1)

        // Liquid body.
        var surface = Path()
        let step: CGFloat = 3
        var x = plot.minX
        surface.move(to: CGPoint(x: x, y: surfaceY(atX: x)))
        while x < plot.maxX {
            x = min(x + step, plot.maxX)
            surface.addLine(to: CGPoint(x: x, y: surfaceY(atX: x)))
        }
        var body = surface
        body.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        body.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(colors: [color.opacity(0.30), color.opacity(0.05)]),
            startPoint: CGPoint(x: plot.midX, y: plot.minY),
            endPoint: CGPoint(x: plot.midX, y: plot.maxY)))
        context.stroke(surface, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        // Drink markers riding the surface.
        var lastSymbolX = -CGFloat.greatestFiniteMagnitude
        for point in points {
            let mx = xPos(point.time)
            let my = surfaceY(atX: mx)
            let dot = CGRect(x: mx - 5, y: my - 5, width: 10, height: 10)
            context.stroke(Path(ellipseIn: dot.insetBy(dx: -1, dy: -1)), with: .color(SippedTheme.surface), lineWidth: 2)
            context.fill(Path(ellipseIn: dot), with: .color(color))
            if mx - lastSymbolX >= 22, let symbol = context.resolveSymbol(id: point.id) {
                context.draw(symbol, at: CGPoint(x: mx, y: max(my - 19, plot.minY + 11)))
                lastSymbolX = mx
            }
        }

        // Time labels.
        let labelY = size.height - 8
        context.draw(
            Text(first.time.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(SippedTheme.secondaryInk),
            at: CGPoint(x: plot.minX + 2, y: labelY), anchor: .leading)
        if span > 3 * 3600 {
            let mid = domainStart.addingTimeInterval(total / 2)
            context.draw(
                Text(mid.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(SippedTheme.secondaryInk),
                at: CGPoint(x: plot.midX, y: labelY))
        }
        context.draw(
            Text("Now").font(.caption2.weight(.semibold)).foregroundStyle(SippedTheme.secondaryInk),
            at: CGPoint(x: plot.maxX - 2, y: labelY), anchor: .trailing)
    }
}

struct LiquidColumn: Identifiable, Equatable {
    let id: Date
    let label: String
    let value: Double
    let isToday: Bool
    let percentage: Double?
    let isOverGoal: Bool
    let accessibilityDateLabel: String?

    init(id: Date, label: String, value: Double, isToday: Bool,
         percentage: Double? = nil, isOverGoal: Bool = false,
         accessibilityDateLabel: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.isToday = isToday
        self.percentage = percentage
        self.isOverGoal = isOverGoal
        self.accessibilityDateLabel = accessibilityDateLabel
    }
}

struct LiquidColumnsChart: View {
    let columns: [LiquidColumn]
    let color: Color
    let valueLabel: (Double) -> String
    let scaleMaximum: Double?
    let selectedID: Date?
    let onSelect: ((Date) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = Date.distantPast

    init(columns: [LiquidColumn], color: Color, valueLabel: @escaping (Double) -> String,
         scaleMaximum: Double? = nil, selectedID: Date? = nil,
         onSelect: ((Date) -> Void)? = nil) {
        self.columns = columns
        self.color = color
        self.valueLabel = valueLabel
        self.scaleMaximum = scaleMaximum
        self.selectedID = selectedID
        self.onSelect = onSelect
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
                    Canvas { context, size in
                        draw(in: &context, size: size, at: timeline.date)
                    }
                    .accessibilityHidden(true)
                }

                HStack(spacing: 10) {
                    ForEach(columns) { column in
                        Button { onSelect?(column.id) } label: {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(for: column))
                        .accessibilityAddTraits(selectedID == column.id ? .isSelected : [])
                        .accessibilityIdentifier("history.day.\(column.id.timeIntervalSinceReferenceDate)")
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear { appeared = .now }
        .onChange(of: columns) { appeared = .now }
    }

    private func accessibilityLabel(for column: LiquidColumn) -> String {
        let date = column.accessibilityDateLabel ?? (column.isToday ? "Today" : column.label)
        let value = column.value.isFinite ? max(0, column.value) : 0
        var result = "\(date), \(valueLabel(value))"
        if let percentage = column.percentage, percentage.isFinite {
            result += ", \(percentage.formatted(.number.precision(.fractionLength(0...1)))) percent of daily fluid goal"
            if column.isOverGoal { result += ", over goal" }
        }
        if selectedID == column.id { result += ", selected" }
        return result
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, at frameTime: Date) {
        guard !columns.isEmpty else { return }
        let topGutter: CGFloat = 20
        let bottomGutter: CGFloat = 20
        let plot = CGRect(x: 0, y: topGutter, width: size.width, height: size.height - topGutter - bottomGutter)
        guard plot.height > 30 else { return }

        let progress = reduceMotion ? 1 : LiquidMotion.riseProgress(since: appeared, at: frameTime)
        let wavePhase = reduceMotion ? 0 : frameTime.timeIntervalSinceReferenceDate
        let automaticMaximum = columns.map { $0.value.isFinite ? max(0, $0.value) : 0 }.max() ?? 0
        let maxValue = scaleMaximum.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? automaticMaximum
        let effectiveMaximum = max(maxValue, 1)
        let maxIndex = columns.lastIndex { ($0.value.isFinite ? max(0, $0.value) : 0) == automaticMaximum }

        let spacing: CGFloat = 10
        let slotWidth = (plot.width - spacing * CGFloat(columns.count - 1)) / CGFloat(columns.count)
        let vesselWidth = min(slotWidth, 46)

        for (index, column) in columns.enumerated() {
            let slotMinX = plot.minX + CGFloat(index) * (slotWidth + spacing)
            let vessel = CGRect(x: slotMinX + (slotWidth - vesselWidth) / 2, y: plot.minY,
                                width: vesselWidth, height: plot.height)
            let vesselPath = Path(roundedRect: vessel, cornerRadius: 12, style: .continuous)
            context.fill(vesselPath, with: .color(SippedTheme.raisedSurface.opacity(0.45)))
            let selected = selectedID == column.id
            context.stroke(vesselPath, with: .color(SippedTheme.line), lineWidth: 1)

            let value = column.value.isFinite ? max(0, column.value) : 0
            if value > 0 {
                let inner = vessel.insetBy(dx: 3, dy: 3)
                let fillHeight = max(inner.height * min(CGFloat(value / effectiveMaximum), 1) * progress, 6)
                let surfaceLevel = inner.maxY - fillHeight
                var liquid = Path()
                if column.isToday, !reduceMotion {
                    let amplitude = min(3, fillHeight * 0.3)
                    var x = inner.minX
                    liquid.move(to: CGPoint(x: x, y: surfaceLevel + LiquidMotion.surfaceOffset(x: x + vessel.minX, time: wavePhase, amplitude: amplitude)))
                    while x < inner.maxX {
                        x = min(x + 3, inner.maxX)
                        liquid.addLine(to: CGPoint(x: x, y: surfaceLevel + LiquidMotion.surfaceOffset(x: x + vessel.minX, time: wavePhase, amplitude: amplitude)))
                    }
                } else {
                    liquid.move(to: CGPoint(x: inner.minX, y: surfaceLevel))
                    liquid.addLine(to: CGPoint(x: inner.maxX, y: surfaceLevel))
                }
                liquid.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY))
                liquid.addLine(to: CGPoint(x: inner.minX, y: inner.maxY))
                liquid.closeSubpath()
                var clipped = context
                clipped.clip(to: Path(roundedRect: inner, cornerRadius: 9, style: .continuous))
                clipped.fill(liquid, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.88), color.opacity(0.62)]),
                    startPoint: CGPoint(x: inner.midX, y: surfaceLevel),
                    endPoint: CGPoint(x: inner.midX, y: inner.maxY)))
            }

            if value > 0, column.isToday || index == maxIndex || selected || column.isOverGoal {
                context.draw(
                    Text(valueLabel(value)).font(.caption2.bold().monospacedDigit()).foregroundStyle(SippedTheme.secondaryInk),
                    at: CGPoint(x: vessel.midX, y: plot.minY - 10))
            }
            if column.isOverGoal {
                context.draw(
                    Text(Image(systemName: "exclamationmark.circle.fill"))
                        .font(.caption2.weight(.bold)).foregroundStyle(.orange),
                    at: CGPoint(x: vessel.midX, y: plot.minY - 25))
            }
            context.draw(
                Text(column.label)
                    .font(column.isToday ? .caption2.weight(.bold) : .caption2)
                    .foregroundStyle(column.isToday ? SippedTheme.ink : SippedTheme.secondaryInk),
                at: CGPoint(x: vessel.midX, y: size.height - 8))
        }
    }
}
