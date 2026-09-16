import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "PhotoMoodArchive/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
let size = 1024
let scale = CGFloat(size)
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Unable to create icon context")
}

func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawRoundedRect(_ rect: CGRect, radius: CGFloat, color: CGColor, alpha: CGFloat, rotation: CGFloat) {
    context.saveGState()
    context.translateBy(x: scale / 2, y: scale / 2)
    context.rotate(by: rotation)
    context.translateBy(x: -scale / 2, y: -scale / 2)
    context.setBlendMode(.multiply)
    context.setAlpha(alpha)
    context.setFillColor(color)

    let path = CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
    context.addPath(path)
    context.fillPath()
    context.restoreGState()
}

func drawCircle(_ center: CGPoint, radius: CGFloat, color: CGColor, alpha: CGFloat) {
    context.saveGState()
    context.setFillColor(color)
    context.setAlpha(alpha)
    context.fillEllipse(in: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    context.restoreGState()
}

let background = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        rgba(247, 242, 233).copy(alpha: 1)!,
        rgba(226, 218, 206).copy(alpha: 1)!
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    background,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: scale, y: scale),
    options: []
)

context.saveGState()
let iconMask = CGPath(roundedRect: CGRect(x: 52, y: 52, width: 920, height: 920), cornerWidth: 218, cornerHeight: 218, transform: nil)
context.addPath(iconMask)
context.clip()

drawCircle(CGPoint(x: 360, y: 275), radius: 210, color: rgba(196, 126, 112), alpha: 0.76)
drawCircle(CGPoint(x: 664, y: 275), radius: 210, color: rgba(210, 173, 106), alpha: 0.70)
drawCircle(CGPoint(x: 765, y: 510), radius: 215, color: rgba(151, 174, 120), alpha: 0.74)
drawCircle(CGPoint(x: 664, y: 750), radius: 210, color: rgba(107, 165, 159), alpha: 0.72)
drawCircle(CGPoint(x: 360, y: 750), radius: 210, color: rgba(133, 148, 183), alpha: 0.72)
drawCircle(CGPoint(x: 260, y: 510), radius: 215, color: rgba(177, 137, 166), alpha: 0.70)

let petalRect = CGRect(x: 386, y: 116, width: 252, height: 410)
let petalRadius: CGFloat = 126
let colors: [CGColor] = [
    rgba(198, 129, 111),
    rgba(209, 160, 96),
    rgba(193, 186, 105),
    rgba(143, 171, 122),
    rgba(106, 165, 157),
    rgba(111, 153, 184),
    rgba(144, 132, 178),
    rgba(181, 135, 165)
]

for index in 0..<8 {
    drawRoundedRect(
        petalRect,
        radius: petalRadius,
        color: colors[index],
        alpha: 0.74,
        rotation: CGFloat(index) * .pi / 4
    )
}

context.setBlendMode(.normal)
drawCircle(CGPoint(x: 512, y: 512), radius: 64, color: rgba(246, 241, 232), alpha: 0.94)
drawCircle(CGPoint(x: 512, y: 512), radius: 34, color: rgba(238, 229, 214), alpha: 0.72)
context.restoreGState()

context.setStrokeColor(rgba(255, 255, 255, 0.62))
context.setLineWidth(2)
context.addPath(iconMask)
context.strokePath()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outputPath) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Unable to create icon image")
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Unable to write icon image")
}
