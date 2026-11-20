import UIKit

/// Bounded image work, performed once when artwork identity changes. No file,
/// network or audio access; the caller supplies the already loaded real cover.
enum OneTapeArtworkColorSampler {
    static func color(from image: UIImage?) -> OneTapeTransportMaterial.RGB? {
        guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            UIGraphicsPushContext(context)
            defer { UIGraphicsPopContext() }
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        // Quantized dominant color avoids a red/blue cover averaging to grey.
        // Transparent pixels contribute no false black; all pointers stay in
        // their buffer lifetime above, never escaping into delayed CI work.
        var bins: [Int: (weight: Double, red: Double, green: Double, blue: Double)] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.1 else { continue }
            let red = min(1, Double(pixels[index]) / 255 / alpha)
            let green = min(1, Double(pixels[index + 1]) / 255 / alpha)
            let blue = min(1, Double(pixels[index + 2]) / 255 / alpha)
            let key = Int(red * 7) << 6 | Int(green * 7) << 3 | Int(blue * 7)
            let saturation = max(red, green, blue) - min(red, green, blue)
            let weight = alpha * (0.35 + saturation)
            var bin = bins[key] ?? (0, 0, 0, 0)
            bin.weight += weight
            bin.red += red * weight; bin.green += green * weight; bin.blue += blue * weight
            bins[key] = bin
        }
        guard let dominant = bins.sorted(by: { $0.key < $1.key }).max(by: {
            $0.value.weight < $1.value.weight
        })?.value, dominant.weight > 0 else { return nil }
        return .init(dominant.red / dominant.weight, dominant.green / dominant.weight,
                     dominant.blue / dominant.weight)
    }
}
