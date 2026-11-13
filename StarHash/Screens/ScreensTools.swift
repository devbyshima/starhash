import SwiftUI

/// What the project's own tools are set to (the tabs of Screens' Tools panel, written in
/// ScreensTools/ at the app's root), for the catalog's sample data to follow:
///
///     ScreensEntry(id: "list", title: "List", flow: "Home") { _ in
///         AnyView(ListView(items: Sample.items(ScreensTools.value("items", default: 3))))
///     }
///
/// Screens writes the values to tools.json in the project's workspace and draws the
/// screens again whenever a control moves. Outside Screens, and in release builds, each
/// call gives back its default.
public nonisolated enum ScreensTools {
    /// A slider's number, rounded (or a pad's, with `pair`).
    public static func value(_ id: String, default fallback: Int) -> Int {
        guard case let .number(number) = raw(id) else { return fallback }
        return Int(number.rounded())
    }

    /// A slider's number.
    public static func value(_ id: String, default fallback: Double) -> Double {
        guard case let .number(number) = raw(id) else { return fallback }
        return number
    }

    /// A switch.
    public static func bool(_ id: String, default fallback: Bool) -> Bool {
        guard case let .bool(on) = raw(id) else { return fallback }
        return on
    }

    /// A choice's or a list's option id, a line of text, the colour picked, or the
    /// button of a row pressed last.
    public static func string(_ id: String, default fallback: String) -> String {
        guard case let .string(text) = raw(id) else { return fallback }
        return text
    }

    /// A pad's two numbers.
    public static func pair(_ id: String, default fallback: (x: Double, y: Double)) -> (x: Double, y: Double) {
        guard case let .pair(values) = raw(id), values.count == 2 else { return fallback }
        return (values[0], values[1])
    }

    /// A colour control's pick: one of Screens' colours by name, or "#RRGGBB".
    public static func color(_ id: String, default fallback: SwiftUI.Color) -> SwiftUI.Color {
        guard case let .string(name) = raw(id) else { return fallback }
        let hex = named[name] ?? UInt32(name.hasPrefix("#") ? String(name.dropFirst()) : "", radix: 16)
        guard let hex else { return fallback }
        return SwiftUI.Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                             green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// Screens' colours, as Enclose names them.
    private static let named: [String: UInt32] = [
        "red": 0xF19C9A, "orange": 0xF7CD9E, "yellow": 0xFDF6A3, "lime": 0xCFFDA2, "green": 0xB0FCC2,
        "cyan": 0xB0FCFE, "blue": 0x9EB7F9, "indigo": 0xA398F8, "violet": 0xD69AF9, "pink": 0xF19CC9,
        "white": 0xFAFAFA, "grey": 0x4B4B4B,
    ]

    nonisolated enum Value: Decodable, Sendable {
        case number(Double), bool(Bool), string(String), pair([Double])

        init(from decoder: any Decoder) throws {
            let one = try decoder.singleValueContainer()
            if let on = try? one.decode(Bool.self) { self = .bool(on) }
            else if let number = try? one.decode(Double.self) { self = .number(number) }
            else if let text = try? one.decode(String.self) { self = .string(text) }
            else { self = .pair(try one.decode([Double].self)) }
        }
    }

    private nonisolated struct File: Decodable {
        var values: [String: Value]
    }

    #if DEBUG
    /// The values as last read, and the file's date then: a catalog reads them for every
    /// screen it stands up, and they change only when a control moves.
    nonisolated(unsafe) private static var read: (date: Date?, values: [String: Value]) = (nil, [:])
    private static let lock = NSLock()
    #endif

    private static func raw(_ id: String) -> Value? {
        #if DEBUG
        guard let out = ProcessInfo.processInfo.environment["SCREENS_OUT"] else { return nil }
        // In the project's workspace, the same whichever device's pictures are drawn:
        // above them, or above the folder of each device's.
        let pictures = URL(fileURLWithPath: out, isDirectory: true)
        let url = [pictures.deletingLastPathComponent(), pictures.deletingLastPathComponent().deletingLastPathComponent()]
            .map { $0.appendingPathComponent("tools.json") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        guard let url else { return nil }
        let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        lock.lock()
        defer { lock.unlock() }
        if date != read.date {
            let values = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(File.self, from: $0) }?.values
            read = (date, values ?? [:])
        }
        return read.values[id]
        #else
        return nil
        #endif
    }
}
