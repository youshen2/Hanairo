import Foundation
import ImageIO

actor UgoiraFrameDecoder {
    private let frames: [UgoiraAnimationFrame]
    private var cache: [Int: CGImage] = [:]
    private var accessOrder: [Int] = []
    private let capacity: Int

    init(frames: [UgoiraAnimationFrame], capacity: Int = 12) {
        self.frames = frames
        self.capacity = max(capacity, 2)
    }

    func image(at index: Int) throws -> CGImage {
        guard frames.indices.contains(index) else {
            throw UgoiraError.invalidFrame("#\(index + 1)")
        }
        if let image = cache[index] {
            touch(index)
            return image
        }

        let frame = frames[index]
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(frame.data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, options)
        else {
            throw UgoiraError.invalidFrame(frame.filename)
        }

        if cache.count >= capacity, let oldest = accessOrder.first {
            cache[oldest] = nil
            accessOrder.removeFirst()
        }
        cache[index] = image
        accessOrder.append(index)
        return image
    }

    private func touch(_ index: Int) {
        accessOrder.removeAll { $0 == index }
        accessOrder.append(index)
    }
}
