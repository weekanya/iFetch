import Foundation

@objc(IFDisplayFormatter)
final class IFDisplayFormatter: NSObject {
    @objc(bytes:)
    static func bytes(_ value: UInt64) -> String {
        let russian = IFLanguageManager.isRussian()
        let tebibyte = 1_099_511_627_776.0
        let gibibyte = 1_073_741_824.0
        let mebibyte = 1_048_576.0

        if Double(value) >= tebibyte {
            return String(format: russian ? "%.1f ТБ" : "%.1f TB", Double(value) / tebibyte)
        }
        if Double(value) >= gibibyte {
            return String(format: russian ? "%.1f ГБ" : "%.1f GB", Double(value) / gibibyte)
        }
        return String(format: russian ? "%.1f МБ" : "%.1f MB", Double(value) / mebibyte)
    }

    @objc(rate:)
    static func rate(_ value: Double) -> String {
        let russian = IFLanguageManager.isRussian()
        if value < 1024 {
            return String(format: russian ? "%.0f Б/с" : "%.0f B/s", value)
        }
        if value < 1_048_576 {
            return String(format: russian ? "%.1f КБ/с" : "%.1f KB/s", value / 1024)
        }
        return String(format: russian ? "%.1f МБ/с" : "%.1f MB/s", value / 1_048_576)
    }

    @objc(percent:)
    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    @objc(roundedPercent:)
    static func roundedPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    @objc(temperature:)
    static func temperature(_ value: Double) -> String {
        String(format: "%.1f °C", value)
    }

    @objc(latency:)
    static func latency(_ value: Double) -> String {
        String(format: "%.0f ms", value)
    }
}
