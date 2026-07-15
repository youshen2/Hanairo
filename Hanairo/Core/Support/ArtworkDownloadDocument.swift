import SwiftUI
import UniformTypeIdentifiers

struct ArtworkDownloadDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.image] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ArtworkExport {
    let document: ArtworkDownloadDocument
    let contentType: UTType
    let filename: String

    init(data: Data, sourceURL: URL, illustrationID: Int, pageIndex: Int) {
        let filenameExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
        document = ArtworkDownloadDocument(data: data)
        contentType = UTType(filenameExtension: filenameExtension) ?? .data
        filename = "\(illustrationID)_p\(pageIndex + 1).\(filenameExtension)"
    }
}
