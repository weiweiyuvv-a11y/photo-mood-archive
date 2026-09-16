import SwiftUI

struct MoodDoodleView: View {
    let theme: MonthTheme
    let moodLevel: Int?
    var colorOverride: Color? = nil

    private var level: Int {
        min(max(moodLevel ?? 3, 0), 8)
    }

    private var moodColor: Color {
        guard moodLevel != nil else { return theme.quietColor.opacity(0.55) }
        return colorOverride ?? theme.moodColor(level: level)
    }

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.13, dy: size.height * 0.13)
            drawBase(in: &context, rect: rect)
        }
        .accessibilityLabel("Mood color")
    }

    private func drawBase(in context: inout GraphicsContext, rect: CGRect) {
        let soften = CGFloat(level) / 8
        let blob = Path(
            roundedRect: rect,
            cornerSize: CGSize(
                width: rect.width * (0.24 + soften * 0.08),
                height: rect.height * (0.22 + soften * 0.10)
            )
        )

        context.fill(blob, with: .color(moodColor.opacity(moodLevel == nil ? 0.30 : 0.94)))

        let glint = CGRect(
            x: rect.minX + rect.width * 0.18,
            y: rect.minY + rect.height * 0.16,
            width: rect.width * 0.22,
            height: rect.height * 0.12
        )
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(moodLevel == nil ? 0.22 : 0.30)))

        context.stroke(
            blob,
            with: .color(.white.opacity(moodLevel == nil ? 0.34 : 0.58)),
            lineWidth: max(1, rect.width * 0.018)
        )
    }

    private func drawSignature(in context: inout GraphicsContext, rect: CGRect, stroke: StrokeStyle, ink: Color) {
        drawPrismRibs(in: &context, rect: rect, stroke: stroke, ink: ink)
    }

    private func drawPrismRibs(in context: inout GraphicsContext, rect: CGRect, stroke: StrokeStyle, ink: Color) {
        let ribCount = 8
        for index in 0..<ribCount {
            let fraction = CGFloat(index) / CGFloat(max(ribCount - 1, 1))
            let x = rect.minX + rect.width * (0.14 + fraction * 0.72)
            var rib = Path()
            rib.move(to: CGPoint(x: x, y: rect.minY + rect.height * 0.04))
            rib.addLine(to: CGPoint(x: x + rect.width * 0.015, y: rect.maxY - rect.height * 0.04))
            context.stroke(
                rib,
                with: .color(.white.opacity(0.30 + Double(fraction) * 0.18)),
                style: StrokeStyle(lineWidth: max(0.8, rect.width * 0.018), lineCap: .round)
            )
        }

        var glint = Path()
        glint.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.16))
        glint.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.10))
        context.stroke(glint, with: .color(.white.opacity(0.34)), style: stroke)

        let dot = CGRect(
            x: rect.maxX - rect.width * 0.24,
            y: rect.maxY - rect.height * 0.24,
            width: rect.width * 0.07,
            height: rect.width * 0.07
        )
        context.fill(Path(ellipseIn: dot), with: .color(ink.opacity(0.50)))
        context.fill(Path(ellipseIn: dot.offsetBy(dx: -rect.width * 0.42, dy: -rect.height * 0.38)), with: .color(.white.opacity(0.42)))
    }

    private func drawAccentDust(in context: inout GraphicsContext, rect: CGRect, ink: Color) {
        for index in 0..<5 {
            let x = rect.minX + rect.width * (0.18 + CGFloat(index) * 0.15)
            let line = CGRect(
                x: x,
                y: rect.minY + rect.height * 0.08,
                width: max(0.8, rect.width * 0.012),
                height: rect.height * 0.84
            )
            context.fill(Path(roundedRect: line, cornerRadius: line.width / 2), with: .color(.white.opacity(0.13)))
        }
    }

    private func drawHeart(in context: inout GraphicsContext, rect: CGRect, ink: Color) {
        let scale = 0.72 + CGFloat(level) * 0.018
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.02)
        let width = rect.width * scale
        let height = rect.height * scale
        var path = Path()

        path.move(to: CGPoint(x: center.x, y: center.y + height * 0.28))
        path.addCurve(
            to: CGPoint(x: center.x - width * 0.42, y: center.y - height * 0.08),
            control1: CGPoint(x: center.x - width * 0.22, y: center.y + height * 0.12),
            control2: CGPoint(x: center.x - width * 0.48, y: center.y + height * 0.10)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - height * 0.30),
            control1: CGPoint(x: center.x - width * 0.36, y: center.y - height * 0.32),
            control2: CGPoint(x: center.x - width * 0.10, y: center.y - height * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: center.x + width * 0.42, y: center.y - height * 0.08),
            control1: CGPoint(x: center.x + width * 0.10, y: center.y - height * 0.42),
            control2: CGPoint(x: center.x + width * 0.36, y: center.y - height * 0.32)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + height * 0.28),
            control1: CGPoint(x: center.x + width * 0.48, y: center.y + height * 0.10),
            control2: CGPoint(x: center.x + width * 0.22, y: center.y + height * 0.12)
        )
        context.fill(path, with: .color(.white.opacity(0.42)))
        context.stroke(path, with: .color(ink), lineWidth: max(1.2, rect.width * 0.028))
    }

    private func drawStar(in context: inout GraphicsContext, rect: CGRect, stroke: StrokeStyle, ink: Color) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        let points = 8
        for index in 0..<points {
            let angle = Double(index) * .pi * 2 / Double(points) - .pi / 2
            let inner = rect.width * 0.10
            let outer = rect.width * (0.29 + CGFloat(level) * 0.008)
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
        }

        context.stroke(path, with: .color(ink), style: stroke)
        context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(.white.opacity(0.46)))
    }

    private func drawLeaf(in context: inout GraphicsContext, rect: CGRect, stroke: StrokeStyle, ink: Color) {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.22, y: rect.midY + rect.height * 0.18))
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.28, y: rect.midY - rect.height * 0.26),
            control1: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.midY - rect.height * 0.26),
            control2: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.34)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.22, y: rect.midY + rect.height * 0.18),
            control1: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY + rect.height * 0.04),
            control2: CGPoint(x: rect.midX - rect.width * 0.02, y: rect.midY + rect.height * 0.26)
        )

        context.fill(path, with: .color(.white.opacity(0.34)))
        context.stroke(path, with: .color(ink), style: stroke)

        var vein = Path()
        vein.move(to: CGPoint(x: rect.midX - rect.width * 0.14, y: rect.midY + rect.height * 0.12))
        vein.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.16))
        context.stroke(vein, with: .color(ink.opacity(0.62)), style: stroke)
    }

    private func drawMoon(in context: inout GraphicsContext, rect: CGRect, stroke: StrokeStyle, ink: Color) {
        let moonRect = rect.insetBy(dx: rect.width * 0.24, dy: rect.height * 0.18)
        var crescent = Path()
        crescent.addArc(center: CGPoint(x: moonRect.midX + moonRect.width * 0.08, y: moonRect.midY), radius: moonRect.width * 0.38, startAngle: .degrees(88), endAngle: .degrees(276), clockwise: false)
        crescent.addArc(center: CGPoint(x: moonRect.midX + moonRect.width * 0.20, y: moonRect.midY), radius: moonRect.width * 0.31, startAngle: .degrees(274), endAngle: .degrees(92), clockwise: true)
        context.fill(crescent, with: .color(.white.opacity(0.42)))
        context.stroke(crescent, with: .color(ink), style: stroke)
    }

    private func drawWave(in context: inout GraphicsContext, rect: CGRect, stroke: StrokeStyle, ink: Color) {
        for offset in [0.42, 0.56, 0.70] {
            var path = Path()
            let y = rect.minY + rect.height * offset
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: y))
            path.addCurve(
                to: CGPoint(x: rect.maxX - rect.width * 0.18, y: y),
                control1: CGPoint(x: rect.midX - rect.width * 0.16, y: y - rect.height * 0.18),
                control2: CGPoint(x: rect.midX + rect.width * 0.16, y: y + rect.height * 0.18)
            )
            context.stroke(path, with: .color(ink.opacity(offset == 0.56 ? 0.78 : 0.42)), style: stroke)
        }
    }

    private func drawPetal(in context: inout GraphicsContext, rect: CGRect, ink: Color) {
        let centers: [CGPoint] = [
            CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.17),
            CGPoint(x: rect.midX - rect.width * 0.17, y: rect.midY + rect.height * 0.08),
            CGPoint(x: rect.midX + rect.width * 0.17, y: rect.midY + rect.height * 0.08)
        ]

        for center in centers {
            let petal = CGRect(x: center.x - rect.width * 0.13, y: center.y - rect.height * 0.20, width: rect.width * 0.26, height: rect.height * 0.40)
            var path = Path(ellipseIn: petal)
            path = path.applying(CGAffineTransform(rotationAngle: (center.x - rect.midX) / rect.width))
            context.fill(path, with: .color(.white.opacity(0.34)))
            context.stroke(path, with: .color(ink.opacity(0.72)), lineWidth: max(1.1, rect.width * 0.022))
        }
    }

    private func drawFacet(in context: inout GraphicsContext, rect: CGRect, stroke: StrokeStyle, ink: Color) {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.midY))
        path.closeSubpath()
        context.fill(path, with: .color(.white.opacity(0.34)))
        context.stroke(path, with: .color(ink), style: stroke)

        var cross = Path()
        cross.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18))
        cross.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.18))
        cross.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.midY))
        cross.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.midY))
        context.stroke(cross, with: .color(ink.opacity(0.46)), style: stroke)
    }
}
