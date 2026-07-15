import Foundation

@MainActor
enum ArtworkExportService {
    static func prepare(
        illustration: PixivIllustration,
        format: ArtworkExportFormat,
        imageRepository: ImageRepository,
        onProgress: (Int, Int) -> Void
    ) async throws -> PreparedArtworkExport {
        let pages = try availablePages(for: illustration)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HanairoExports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let outputURL = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(format.fileExtension)

        do {
            switch format {
            case .zip:
                try await writeZIP(
                    pages: pages,
                    outputURL: outputURL,
                    imageRepository: imageRepository,
                    onProgress: onProgress
                )
            case .pdf:
                try await writePDF(
                    pages: pages,
                    outputURL: outputURL,
                    title: illustration.title,
                    author: illustration.user.name,
                    imageRepository: imageRepository,
                    onProgress: onProgress
                )
            }

            let filename = "\(safeFilename(illustration.title, id: illustration.id)).\(format.fileExtension)"
            let document = try ArtworkExportDocument(
                fileURL: outputURL,
                contentType: format.contentType,
                filename: filename
            )
            return PreparedArtworkExport(
                fileURL: outputURL,
                format: format,
                document: document
            )
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    static func removeTemporaryFile(for export: PreparedArtworkExport?) {
        guard let export else { return }
        try? FileManager.default.removeItem(at: export.fileURL)
    }

    private static func availablePages(
        for illustration: PixivIllustration
    ) throws -> [(index: Int, url: URL)] {
        let urls = illustration.originalPageURLs
        guard !urls.isEmpty else {
            throw ArtworkExportError.noAvailablePages
        }
        return try urls.enumerated().map { index, url in
            guard let url else {
                throw ArtworkExportError.missingPage(index)
            }
            return (index, url)
        }
    }

    private static func writeZIP(
        pages: [(index: Int, url: URL)],
        outputURL: URL,
        imageRepository: ImageRepository,
        onProgress: (Int, Int) -> Void
    ) async throws {
        let writer = try ArtworkZIPWriter(outputURL: outputURL)
        do {
            let digits = max(2, String(pages.count).count)
            for (position, page) in pages.enumerated() {
                try Task.checkCancellation()
                let data = try await imageRepository.data(for: page.url)
                let number = String(page.index + 1)
                let paddedNumber = String(repeating: "0", count: max(0, digits - number.count)) + number
                let filename = "p\(paddedNumber).\(safeImageExtension(page.url.pathExtension))"
                try await writer.append(data: data, filename: filename)
                onProgress(position + 1, pages.count)
            }
            try await writer.finish()
        } catch {
            await writer.cancel()
            throw error
        }
    }

    private static func writePDF(
        pages: [(index: Int, url: URL)],
        outputURL: URL,
        title: String,
        author: String,
        imageRepository: ImageRepository,
        onProgress: (Int, Int) -> Void
    ) async throws {
        let writer = try ArtworkPDFWriter(
            outputURL: outputURL,
            title: title,
            author: author
        )
        do {
            for (position, page) in pages.enumerated() {
                try Task.checkCancellation()
                let data = try await imageRepository.data(for: page.url)
                try await writer.append(data: data, pageIndex: page.index)
                onProgress(position + 1, pages.count)
            }
            try await writer.finish()
        } catch {
            await writer.cancel()
            throw error
        }
    }

    private static func safeFilename(_ title: String, id: Int) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = title
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = cleaned.isEmpty ? "未命名作品" : cleaned
        return "\(id)_\(String(normalized.prefix(80)))"
    }

    private static func safeImageExtension(_ value: String) -> String {
        let normalized = value.lowercased()
        let allowed = ["jpg", "jpeg", "png", "gif", "webp"]
        return allowed.contains(normalized) ? normalized : "jpg"
    }
}
