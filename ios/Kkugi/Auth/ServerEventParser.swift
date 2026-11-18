import Foundation

struct ServerEventParser {
    struct Frame {
        let name: String
        let data: String
    }
    private var name = ""
    private var line = Data()
    private var values: [String] = []
    private var size = 0
    private var skipLF = false

    mutating func consume(_ byte: UInt8) throws -> Frame? {
        if skipLF {
            skipLF = false
            if byte == 10 { return nil }
        }
        size += 1
        guard size <= 1_048_576 else { throw URLError(.dataLengthExceedsMaximum) }
        if byte != 10 && byte != 13 { line.append(byte); return nil }
        skipLF = byte == 13
        guard let text = String(data: line, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        line.removeAll(keepingCapacity: true)
        if text.isEmpty {
            defer { name = ""; values.removeAll(); size = 0 }
            return values.isEmpty ? nil : Frame(name: name, data: values.joined(separator: "\n"))
        }
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        var value = parts.count == 2 ? String(parts[1]) : ""
        if value.first == " " { value.removeFirst() }
        switch parts.first {
        case "event": name = value
        case "data": values.append(value)
        default: break
        }
        return nil
    }
}
