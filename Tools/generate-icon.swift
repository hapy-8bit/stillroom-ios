import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// A native vector drawing exported for the asset catalog; no external icon or logo dependency.
let size = 1024.0
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.09, green: 0.15, blue: 0.13, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(CGColor(red: 0.04, green: 0.08, blue: 0.07, alpha: 1))
context.fillEllipse(in: CGRect(x: 145, y: 145, width: 734, height: 734))
for i in 0..<30 {
    let inset = 161.0 + Double(i) * 7
    context.setStrokeColor(CGColor(red: 0.78, green: 0.82, blue: 0.66, alpha: i.isMultiple(of: 3) ? 0.2 : 0.08))
    context.setLineWidth(1.8)
    context.strokeEllipse(in: CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2))
}
context.setFillColor(CGColor(red: 0.89, green: 0.87, blue: 0.74, alpha: 1))
context.fillEllipse(in: CGRect(x: 389, y: 389, width: 246, height: 246))
context.setFillColor(CGColor(red: 0.12, green: 0.20, blue: 0.16, alpha: 1))
context.fillEllipse(in: CGRect(x: 492, y: 492, width: 40, height: 40))
context.move(to: CGPoint(x: 792, y: 827))
context.addLine(to: CGPoint(x: 792, y: 409))
context.addCurve(to: CGPoint(x: 702, y: 290), control1: CGPoint(x: 792, y: 355), control2: CGPoint(x: 730, y: 328))
context.setLineWidth(20)
context.setLineCap(.round)
context.setStrokeColor(CGColor(red: 0.81, green: 0.84, blue: 0.72, alpha: 1))
context.strokePath()
context.fillEllipse(in: CGRect(x: 763, y: 798, width: 58, height: 58))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write icon") }
