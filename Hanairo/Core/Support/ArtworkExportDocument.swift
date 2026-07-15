import SwiftUI
import UniformTypeIdentifiers

struct ArtworkExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip, .pdf] }

    let data: Data
    let filename: String

    init(fileURL: URL, contentType: UTType, filename: String) throws {
        data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        self.filename = Self.validFilename(filename, contentType: contentType)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        filename = Self.validFilename("", contentType: configuration.contentType)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = filename
        return wrapper
    }

    private static func validFilename(_ filename: String, contentType: UTType) -> String {
        let normalized = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            let filenameExtension = contentType.preferredFilenameExtension ?? "dat"
            return "Hanairo-export.\(filenameExtension)"
        }
        return normalized
    }
}
