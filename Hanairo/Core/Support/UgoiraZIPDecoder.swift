import Foundation
import zlib

nonisolated enum UgoiraZIPDecoder {
    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let maximumArchiveBytes = 1_024 * 1_024 * 1_024
    private static let maximumFrameBytes = 128 * 1_024 * 1_024

    static func decode(
        archiveData: Data,
        metadata: UgoiraMetadata,
        illustrationID: Int,
        archiveURL: URL
    ) throws -> UgoiraAnimation {
        guard !metadata.frames.isEmpty else { throw UgoiraError.emptyFrames }
        guard archiveData.count <= maximumArchiveBytes else { throw UgoiraError.archiveTooLarge }

        let entries = try centralDirectoryEntries(in: archiveData)
        var totalBytes = 0
        var frames: [UgoiraAnimationFrame] = []
        frames.reserveCapacity(metadata.frames.count)

        for metadataFrame in metadata.frames {
            guard let entry = matchingEntry(named: metadataFrame.file, in: entries) else {
                throw UgoiraError.missingFrame(metadataFrame.file)
            }
            guard entry.uncompressedSize <= maximumFrameBytes else {
                throw UgoiraError.archiveTooLarge
            }
            totalBytes += entry.uncompressedSize
            guard totalBytes <= maximumArchiveBytes else {
                throw UgoiraError.archiveTooLarge
            }

            let data = try frameData(for: entry, in: archiveData)
            frames.append(
                UgoiraAnimationFrame(
                    filename: metadataFrame.file,
                    delayMilliseconds: metadataFrame.delay,
                    data: data
                )
            )
        }

        return UgoiraAnimation(
            illustrationID: illustrationID,
            archiveURL: archiveURL,
            frames: frames
        )
    }

    private static func centralDirectoryEntries(in data: Data) throws -> [String: Entry] {
        let endOffset = try endOfCentralDirectoryOffset(in: data)
        let diskNumber = try data.uint16(at: endOffset + 4)
        let directoryDisk = try data.uint16(at: endOffset + 6)
        let entriesOnDisk = try data.uint16(at: endOffset + 8)
        let totalEntries = try data.uint16(at: endOffset + 10)
        let directorySize = try data.int32(at: endOffset + 12)
        let directoryOffset = try data.int32(at: endOffset + 16)

        guard
            diskNumber == 0,
            directoryDisk == 0,
            entriesOnDisk == totalEntries,
            directoryOffset <= data.count,
            directorySize <= data.count - directoryOffset
        else {
            throw UgoiraError.invalidArchive
        }

        var result: [String: Entry] = [:]
        var cursor = directoryOffset
        let directoryEnd = directoryOffset + directorySize

        for _ in 0..<Int(totalEntries) {
            guard
                cursor <= directoryEnd - 46,
                try data.uint32(at: cursor) == centralHeaderSignature
            else {
                throw UgoiraError.invalidArchive
            }

            let flags = try data.uint16(at: cursor + 8)
            let compressionMethod = try data.uint16(at: cursor + 10)
            let checksum = try data.uint32(at: cursor + 16)
            let compressedSize = try data.int32(at: cursor + 20)
            let uncompressedSize = try data.int32(at: cursor + 24)
            let filenameLength = Int(try data.uint16(at: cursor + 28))
            let extraLength = Int(try data.uint16(at: cursor + 30))
            let commentLength = Int(try data.uint16(at: cursor + 32))
            let localHeaderOffset = try data.int32(at: cursor + 42)
            let recordLength = 46 + filenameLength + extraLength + commentLength

            guard
                flags & 0x0001 == 0,
                compressedSize != Int(UInt32.max),
                uncompressedSize != Int(UInt32.max),
                localHeaderOffset != Int(UInt32.max),
                cursor <= directoryEnd - recordLength
            else {
                if flags & 0x0001 != 0 {
                    throw UgoiraError.encryptedArchive
                }
                throw UgoiraError.invalidArchive
            }

            let filenameRange = (cursor + 46)..<(cursor + 46 + filenameLength)
            guard let filename = String(data: data[filenameRange], encoding: .utf8), !filename.isEmpty else {
                throw UgoiraError.invalidArchive
            }

            result[filename] = Entry(
                filename: filename,
                flags: flags,
                compressionMethod: compressionMethod,
                checksum: checksum,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            )
            cursor += recordLength
        }

        guard cursor <= directoryEnd else { throw UgoiraError.invalidArchive }
        return result
    }

    private static func endOfCentralDirectoryOffset(in data: Data) throws -> Int {
        guard data.count >= 22 else { throw UgoiraError.invalidArchive }
        let lowerBound = max(0, data.count - 22 - Int(UInt16.max))

        for offset in stride(from: data.count - 22, through: lowerBound, by: -1) {
            guard (try? data.uint32(at: offset)) == endOfCentralDirectorySignature else { continue }
            let commentLength = Int(try data.uint16(at: offset + 20))
            guard offset + 22 + commentLength == data.count else { continue }
            return offset
        }
        throw UgoiraError.invalidArchive
    }

    private static func matchingEntry(named filename: String, in entries: [String: Entry]) -> Entry? {
        if let exact = entries[filename] {
            return exact
        }
        let suffix = "/" + filename
        let matches = entries.values.filter { $0.filename.hasSuffix(suffix) }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func frameData(for entry: Entry, in archive: Data) throws -> Data {
        let offset = entry.localHeaderOffset
        guard
            offset <= archive.count - 30,
            try archive.uint32(at: offset) == localHeaderSignature
        else {
            throw UgoiraError.invalidArchive
        }

        let localFlags = try archive.uint16(at: offset + 6)
        let localMethod = try archive.uint16(at: offset + 8)
        let filenameLength = Int(try archive.uint16(at: offset + 26))
        let extraLength = Int(try archive.uint16(at: offset + 28))
        let dataOffset = offset + 30 + filenameLength + extraLength

        guard
            localFlags & 0x0001 == 0,
            localMethod == entry.compressionMethod,
            dataOffset <= archive.count,
            entry.compressedSize <= archive.count - dataOffset
        else {
            if localFlags & 0x0001 != 0 {
                throw UgoiraError.encryptedArchive
            }
            throw UgoiraError.invalidArchive
        }

        let compressed = Data(archive[dataOffset..<(dataOffset + entry.compressedSize)])
        let result: Data
        switch entry.compressionMethod {
        case 0:
            guard compressed.count == entry.uncompressedSize else {
                throw UgoiraError.invalidArchive
            }
            result = compressed
        case 8:
            result = try inflateRaw(compressed, expectedSize: entry.uncompressedSize)
        default:
            throw UgoiraError.unsupportedCompression(Int(entry.compressionMethod))
        }

        guard checksum(of: result) == entry.checksum else {
            throw UgoiraError.invalidArchive
        }
        return result
    }

    private static func inflateRaw(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize >= 0, expectedSize <= maximumFrameBytes else {
            throw UgoiraError.archiveTooLarge
        }
        guard !data.isEmpty || expectedSize == 0 else {
            throw UgoiraError.invalidArchive
        }
        if expectedSize == 0 {
            return Data()
        }
        guard data.count <= Int(UInt32.max), expectedSize <= Int(UInt32.max) else {
            throw UgoiraError.archiveTooLarge
        }

        var stream = z_stream()
        let initialization = inflateInit2_(
            &stream,
            -MAX_WBITS,
            zlibVersion(),
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initialization == Z_OK else { throw UgoiraError.invalidArchive }
        defer { inflateEnd(&stream) }

        var output = Data(count: expectedSize)
        let status: Int32 = data.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                stream.next_in = UnsafeMutablePointer(
                    mutating: inputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self)
                )
                stream.avail_in = uInt(inputBuffer.count)
                stream.next_out = outputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self)
                stream.avail_out = uInt(outputBuffer.count)
                return inflate(&stream, Z_FINISH)
            }
        }

        guard status == Z_STREAM_END, Int(stream.total_out) == expectedSize else {
            throw UgoiraError.invalidArchive
        }
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

private nonisolated struct Entry {
    let filename: String
    let flags: UInt16
    let compressionMethod: UInt16
    let checksum: UInt32
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
}

private nonisolated extension Data {
    func uint16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset <= count - 2 else { throw UgoiraError.invalidArchive }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset <= count - 4 else { throw UgoiraError.invalidArchive }
        return UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }

    func int32(at offset: Int) throws -> Int {
        Int(try uint32(at: offset))
    }
}
