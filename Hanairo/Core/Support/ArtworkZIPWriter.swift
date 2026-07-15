import Foundation
import zlib

actor ArtworkZIPWriter {
    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let version: UInt16 = 20
    private static let utf8Flag: UInt16 = 0x0800
    private static let deflateMethod: UInt16 = 8
    private static let minimumDOSDate: UInt16 = 0x0021

    private let outputURL: URL
    private let handle: FileHandle
    private var entries: [CentralEntry] = []
    private var offset: UInt64 = 0
    private var isClosed = false

    init(outputURL: URL) throws {
        self.outputURL = outputURL
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw ArtworkExportError.cannotCreateOutput
        }
        do {
            handle = try FileHandle(forWritingTo: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    func append(data: Data, filename: String) throws {
        try Task.checkCancellation()
        guard !isClosed,
              data.count <= Int(UInt32.max),
              offset <= UInt64(UInt32.max) else {
            throw ArtworkExportError.archiveTooLarge
        }

        let filenameData = Data(filename.utf8)
        guard !filenameData.isEmpty, filenameData.count <= Int(UInt16.max) else {
            throw ArtworkExportError.invalidFilename
        }

        let compressed = try Self.compress(data)
        guard compressed.count <= Int(UInt32.max) else {
            throw ArtworkExportError.archiveTooLarge
        }

        let checksum = Self.checksum(of: data)
        let localOffset = UInt32(offset)
        let dataSize = UInt32(data.count)
        let compressedSize = UInt32(compressed.count)

        var header = Data()
        header.appendLittleEndian(Self.localHeaderSignature)
        header.appendLittleEndian(Self.version)
        header.appendLittleEndian(Self.utf8Flag)
        header.appendLittleEndian(Self.deflateMethod)
        header.appendLittleEndian(UInt16(0))
        header.appendLittleEndian(Self.minimumDOSDate)
        header.appendLittleEndian(checksum)
        header.appendLittleEndian(compressedSize)
        header.appendLittleEndian(dataSize)
        header.appendLittleEndian(UInt16(filenameData.count))
        header.appendLittleEndian(UInt16(0))

        try write(header)
        try write(filenameData)
        try write(compressed)
        entries.append(
            CentralEntry(
                filename: filenameData,
                checksum: checksum,
                compressedSize: compressedSize,
                uncompressedSize: dataSize,
                localHeaderOffset: localOffset
            )
        )
    }

    func finish() throws {
        guard !isClosed, !entries.isEmpty, entries.count <= Int(UInt16.max) else {
            throw ArtworkExportError.cannotCreateOutput
        }
        let directoryOffset = offset

        for entry in entries {
            var header = Data()
            header.appendLittleEndian(Self.centralHeaderSignature)
            header.appendLittleEndian(Self.version)
            header.appendLittleEndian(Self.version)
            header.appendLittleEndian(Self.utf8Flag)
            header.appendLittleEndian(Self.deflateMethod)
            header.appendLittleEndian(UInt16(0))
            header.appendLittleEndian(Self.minimumDOSDate)
            header.appendLittleEndian(entry.checksum)
            header.appendLittleEndian(entry.compressedSize)
            header.appendLittleEndian(entry.uncompressedSize)
            header.appendLittleEndian(UInt16(entry.filename.count))
            header.appendLittleEndian(UInt16(0))
            header.appendLittleEndian(UInt16(0))
            header.appendLittleEndian(UInt16(0))
            header.appendLittleEndian(UInt16(0))
            header.appendLittleEndian(UInt32(0))
            header.appendLittleEndian(entry.localHeaderOffset)
            try write(header)
            try write(entry.filename)
        }

        let directorySize = offset - directoryOffset
        guard directoryOffset <= UInt64(UInt32.max), directorySize <= UInt64(UInt32.max) else {
            throw ArtworkExportError.archiveTooLarge
        }

        var footer = Data()
        footer.appendLittleEndian(Self.endOfCentralDirectorySignature)
        footer.appendLittleEndian(UInt16(0))
        footer.appendLittleEndian(UInt16(0))
        footer.appendLittleEndian(UInt16(entries.count))
        footer.appendLittleEndian(UInt16(entries.count))
        footer.appendLittleEndian(UInt32(directorySize))
        footer.appendLittleEndian(UInt32(directoryOffset))
        footer.appendLittleEndian(UInt16(0))
        try write(footer)
        try handle.close()
        isClosed = true
    }

    func cancel() {
        if !isClosed {
            try? handle.close()
            isClosed = true
        }
        try? FileManager.default.removeItem(at: outputURL)
    }

    private func write(_ data: Data) throws {
        try handle.write(contentsOf: data)
        offset += UInt64(data.count)
        guard offset <= UInt64(UInt32.max) else {
            throw ArtworkExportError.archiveTooLarge
        }
    }

    private static func compress(_ data: Data) throws -> Data {
        guard data.count <= Int(UInt32.max) else {
            throw ArtworkExportError.archiveTooLarge
        }

        var stream = z_stream()
        let initialization = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            -MAX_WBITS,
            8,
            Z_DEFAULT_STRATEGY,
            zlibVersion(),
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initialization == Z_OK else {
            throw ArtworkExportError.compressionFailed
        }
        defer { deflateEnd(&stream) }

        let capacity = deflateBound(&stream, uLong(data.count))
        guard capacity <= uLong(UInt32.max) else {
            throw ArtworkExportError.archiveTooLarge
        }

        var output = Data(count: Int(capacity))
        let status: Int32 = data.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                stream.next_in = UnsafeMutablePointer(
                    mutating: inputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self)
                )
                stream.avail_in = uInt(inputBuffer.count)
                stream.next_out = outputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self)
                stream.avail_out = uInt(outputBuffer.count)
                return deflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END else {
            throw ArtworkExportError.compressionFailed
        }
        output.count = Int(stream.total_out)
        return output
    }

    private static func checksum(of data: Data) -> UInt32 {
        let value = data.withUnsafeBytes { buffer in
            crc32(
                crc32(0, nil, 0),
                buffer.baseAddress?.assumingMemoryBound(to: Bytef.self),
                uInt(buffer.count)
            )
        }
        return UInt32(truncatingIfNeeded: value)
    }
}

private struct CentralEntry: Sendable {
    let filename: Data
    let checksum: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let localHeaderOffset: UInt32
}

private nonisolated extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
