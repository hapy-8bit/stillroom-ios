import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Rasterize the existing normalized studio grooves once, instead of redrawing 112 rings in flight.
let size = 1536
let side = Double(size)
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let bounds = CGRect(x: 0, y: 0, width: side, height: side)
context.addEllipse(in: bounds)
context.clip()
let colors = [0x19191C, 0x060608, 0x262629].map { hex in
    CGColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255, alpha: 1)
}
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: side / 2, y: side / 2), startRadius: 0,
                           endCenter: CGPoint(x: side / 2, y: side / 2), endRadius: side / 2, options: [])
for index in 0..<112 {
    let inset = side * (0.018 + Double(index) * 0.0027)
    context.setStrokeColor(index.isMultiple(of: 3) ? CGColor(gray: 1, alpha: 0.07) : CGColor(gray: 0, alpha: 0.6))
    context.setLineWidth(side * 0.001)
    context.strokeEllipse(in: bounds.insetBy(dx: inset, dy: inset))
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write vinyl surface") }
