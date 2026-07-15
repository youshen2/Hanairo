import CoreGraphics
import Foundation
import ImageIO

actor ArtworkPDFWriter {
    private static let maximumPageDimension: CGFloat = 4_096

    private let outputURL: URL
    private var context: CGContext?
    private var pageCount = 0
    private var isClosed = false

    init(outputURL: URL, title: String, author: String) throws {
        self.outputURL = outputURL
        let metadata = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextAuthor as String: author,
            kCGPDFContextCreator as String: "Hanairo"
        ] as CFDictionary
        guard let context = CGContext(outputURL as CFURL, mediaBox: nil, metadata) else {
            throw ArtworkExportError.cannotCreateOutput
        }
        self.context = context
    }

    func append(data: Data, pageIndex: Int) throws {
        try Task.checkCancellation()
        guard !isClosed,
              let context,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            throw ArtworkExportError.invalidImage(pageIndex)
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        let largestDimension = max(imageSize.width, imageSize.height)
        let scale = min(1, Self.maximumPageDimension / largestDimension)
        var mediaBox = CGRect(
            origin: .zero,
            size: CGSize(
                width: max(imageSize.width * scale, 1),
                height: max(imageSize.height * scale, 1)
            )
        )
        let mediaBoxData = withUnsafeBytes(of: &mediaBox) { Data($0) }
        let pageInfo = [
            kCGPDFContextMediaBox as String: mediaBoxData as CFData
        ] as CFDictionary

        context.beginPDFPage(pageInfo)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(mediaBox)
        context.interpolationQuality = .high
        context.draw(image, in: mediaBox)
        context.endPDFPage()
        pageCount += 1
    }

    func finish() throws {
        guard !isClosed, pageCount > 0, let context else {
            throw ArtworkExportError.cannotCreateOutput
        }
        context.closePDF()
        self.context = nil
        isClosed = true
    }

    func cancel() {
        if !isClosed {
            context?.closePDF()
            context = nil
            isClosed = true
        }
        try? FileManager.default.removeItem(at: outputURL)
    }
}
