import CoreGraphics
import SwiftUI

enum ImageAccentColorExtractor {
    static func color(from image: CGImage) -> Color? {
        let width = 32
        let height = 32
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        let didDraw = pixels.withUnsafeMutableBytes { buffer in
            guard
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                )
            else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else { return nil }

        var buckets: [Int: ColorBucket] = [:]
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.7 else { continue }

            let red = min(Double(pixels[index]) / 255 / alpha, 1)
            let green = min(Double(pixels[index + 1]) / 255 / alpha, 1)
            let blue = min(Double(pixels[index + 2]) / 255 / alpha, 1)
            let hsv = hsv(red: red, green: green, blue: blue)
            guard hsv.brightness > 0.12, hsv.brightness < 0.94 else { continue }

            let hueBucket = Int(hsv.hue * 24) % 24
            let saturationBucket = min(Int(hsv.saturation * 4), 3)
            let brightnessBucket = min(Int(hsv.brightness * 4), 3)
            let key = hueBucket + saturationBucket * 24 + brightnessBucket * 96
            let exposureWeight = 1 - min(abs(hsv.brightness - 0.66), 0.5)
            let weight = (0.18 + hsv.saturation * 1.7) * exposureWeight
            buckets[key, default: .zero].add(
                red: red,
                green: green,
                blue: blue,
                weight: weight
            )
        }

        guard let bucket = buckets.values.max(by: { $0.weight < $1.weight }), bucket.weight > 0 else {
            return nil
        }
        let selected = hsv(
            red: bucket.red / bucket.weight,
            green: bucket.green / bucket.weight,
            blue: bucket.blue / bucket.weight
        )
        guard selected.saturation >= 0.08 else { return nil }

        let adjusted = rgb(
            hue: selected.hue,
            saturation: min(max(selected.saturation, 0.45), 0.88),
            brightness: min(max(selected.brightness, 0.58), 0.82)
        )
        return Color(red: adjusted.red, green: adjusted.green, blue: adjusted.blue)
    }

    private static func hsv(red: Double, green: Double, blue: Double) -> HSVColor {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let saturation = maximum == 0 ? 0 : delta / maximum

        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maximum == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maximum == green {
            hue = ((blue - red) / delta + 2) / 6
        } else {
            hue = ((red - green) / delta + 4) / 6
        }
        return HSVColor(
            hue: hue < 0 ? hue + 1 : hue,
            saturation: saturation,
            brightness: maximum
        )
    }

    private static func rgb(hue: Double, saturation: Double, brightness: Double) -> RGBColor {
        let sector = hue * 6
        let chroma = brightness * saturation
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let match = brightness - chroma

        let values: (Double, Double, Double)
        switch sector {
        case 0..<1: values = (chroma, x, 0)
        case 1..<2: values = (x, chroma, 0)
        case 2..<3: values = (0, chroma, x)
        case 3..<4: values = (0, x, chroma)
        case 4..<5: values = (x, 0, chroma)
        default: values = (chroma, 0, x)
        }
        return RGBColor(
            red: values.0 + match,
            green: values.1 + match,
            blue: values.2 + match
        )
    }
}

private struct ColorBucket {
    var red: Double
    var green: Double
    var blue: Double
    var weight: Double

    static let zero = ColorBucket(red: 0, green: 0, blue: 0, weight: 0)

    mutating func add(red: Double, green: Double, blue: Double, weight: Double) {
        self.red += red * weight
        self.green += green * weight
        self.blue += blue * weight
        self.weight += weight
    }
}

private struct HSVColor {
    let hue: Double
    let saturation: Double
    let brightness: Double
}

private struct RGBColor {
    let red: Double
    let green: Double
    let blue: Double
}
