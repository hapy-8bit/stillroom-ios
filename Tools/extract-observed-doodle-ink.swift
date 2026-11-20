#!/usr/bin/env swift
import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

// Extract only visible ink at the thumbnail's native resolution. This is a
// deterministic matte, not super-resolution: unavailable strokes stay absent.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("Stillroom/Resources/Assets.xcassets")
let names = ["Dog", "Caterpillar", "Seesaw", "City", "Wild"]
var records: [[String: Any]] = []

for name in names {
    let sourceName = "OneTapeDoodle\(name)Thumb"
    let targetName = "OneTapeDoodle\(name)ObservedInk"
    let sourceURL = catalog.appendingPathComponent("\(sourceName).imageset/\(sourceName).png")
    let sourceData = try Data(contentsOf: sourceURL)
    guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let decoded = image.dataProvider?.data else {
        fatalError("Cannot decode \(sourceName)")
    }
    // The source catalog PNGs are RGBX, 8 bits per channel, opaque, 288 × 192.
    // Fail instead of silently interpreting a different pixel representation.
    precondition(image.width == 288 && image.height == 192)
    precondition(image.bitsPerComponent == 8 && image.bitsPerPixel == 32)
    precondition(image.alphaInfo == .noneSkipLast)
    let pixels = decoded as Data
    let width = image.width
    let height = image.height
    var graphite = [Bool](repeating: false, count: width * height)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * image.bytesPerRow + x * 4
            let red = Int(pixels[offset])
            let blue = Int(pixels[offset + 2])
            graphite[y * width + x] = blue >= red + 2 && red < 110
        }
    }

    var output = [UInt8](repeating: 0, count: width * height * 4)
    var visiblePixels = 0
    for y in 0..<height {
        for x in 0..<width {
            // Remove the visible template and its antialiased boundary. A
            // one-pixel safety margin may discard tiny strokes beside holes;
            // it never guesses how missing artwork continues under a hole.
            var touchesTemplate = false
            for dy in -1...1 {
                for dx in -1...1 {
                    let xx = x + dx
                    let yy = y + dy
                    if xx < 0 || xx >= width || yy < 0 || yy >= height
                        || graphite[yy * width + xx] {
                        touchesTemplate = true
                    }
                }
            }
            if touchesTemplate { continue }
            let offset = y * image.bytesPerRow + x * 4
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            // Cream paper and its lighting are omitted. Black/neutral ink and
            // its warm paper antialiasing remain with proportional opacity.
            guard red < 210, red >= green, green >= blue else { continue }
            let alpha = UInt8(clamping: Int((1 - Double(red) / 224) * 255))
            let destination = (y * width + x) * 4
            output[destination] = alpha
            output[destination + 1] = alpha
            output[destination + 2] = alpha
            output[destination + 3] = alpha
            visiblePixels += alpha > 0 ? 1 : 0
        }
    }
    let data = Data(output)
    let provider = CGDataProvider(data: data as CFData)!
    let result = CGImage(width: width, height: height, bitsPerComponent: 8,
                         bitsPerPixel: 32, bytesPerRow: width * 4,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: true,
                         intent: .defaultIntent)!
    let targetFolder = catalog.appendingPathComponent("\(targetName).imageset")
    try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
    let targetURL = targetFolder.appendingPathComponent("\(targetName).png")
    let destination = CGImageDestinationCreateWithURL(targetURL as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, result, nil)
    precondition(CGImageDestinationFinalize(destination))
    let contents: [String: Any] = [
        "images": [["filename": "\(targetName).png", "idiom": "universal", "scale": "3x"]],
        "info": ["author": "xcode", "version": 1]
    ]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: targetFolder.appendingPathComponent("Contents.json"))
    records.append([
        "source": "\(sourceName).png",
        "sourceSHA256": SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined(),
        "output": "\(targetName).png",
        "nativePixelSize": [width, height],
        "nontransparentPixels": visiblePixels
    ])
}

let provenance: [String: Any] = [
    "method": "Native-resolution deterministic ink matte from the observed original thumbnail PNGs; graphite template and cream paper removed; no synthesized geometry or detail.",
    "display": "Linear interpolation when enlarged on the cassette's existing logical canvas. Source resolution remains 288 x 192.",
    "limits": "Not original full-resolution prints. Antialiasing and fine lines are limited by thumbnail resolution; a one-pixel template margin may remove strokes near holes. No unseen full-size composition is claimed.",
    "assets": records
]
try JSONSerialization.data(withJSONObject: provenance, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("Evidence/observed-doodle-ink-provenance.json"))
print("Extracted \(records.count) observed ink mattes at 288 x 192; no new detail generated.")
