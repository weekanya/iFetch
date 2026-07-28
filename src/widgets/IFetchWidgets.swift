import SwiftUI
import WidgetKit

struct IFetchEntry: TimelineEntry {
    let date: Date
    let battery: Double
    let memory: Double
    let storage: Double
    let uptime: String
    let device: String
    let system: String
    let crashes: Int
    let topProcess: String
    let topMemory: String
    let russian: Bool
    let accentName: String
    let primaryMetric: String
    let refreshMinutes: Int
    let deepLink: String

    var accent: Color {
        switch accentName {
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        default:
            return Color(red: 0.31, green: 0.91, blue: 1)
        }
    }

    var primaryValue: Double {
        switch primaryMetric {
        case "memory":
            return memory
        case "storage":
            return storage
        default:
            return battery
        }
    }

    var primaryTitle: String {
        switch primaryMetric {
        case "memory":
            return "RAM"
        case "storage":
            return russian ? "ДИСК" : "DISK"
        default:
            return russian ? "ЗАРЯД" : "BATTERY"
        }
    }
}

struct IFetchProvider: TimelineProvider {
    func placeholder(in context: Context) -> IFetchEntry {
        IFetchEntry(date: Date(), battery: 82, memory: 61, storage: 48, uptime: "2d 7h",
                    device: "iPhone", system: "iOS 17", crashes: 0,
                    topProcess: "SpringBoard", topMemory: "312 MB", russian: false,
                    accentName: "cyan", primaryMetric: "battery", refreshMinutes: 15,
                    deepLink: "ifetch://diagnostics")
    }

    func getSnapshot(in context: Context, completion: @escaping (IFetchEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IFetchEntry>) -> Void) {
        let current = entry()
        let refresh = Calendar.current.date(byAdding: .minute, value: current.refreshMinutes, to: current.date)
            ?? current.date.addingTimeInterval(TimeInterval(current.refreshMinutes * 60))
        completion(Timeline(entries: [current], policy: .after(refresh)))
    }

    private func entry() -> IFetchEntry {
        let values = IFWidgetMetrics.snapshot()
        func number(_ key: String) -> Double {
            (values[key] as? NSNumber)?.doubleValue ?? 0
        }
        return IFetchEntry(
            date: Date(),
            battery: number("battery"),
            memory: number("memory"),
            storage: number("storage"),
            uptime: values["uptime"] as? String ?? "—",
            device: values["device"] as? String ?? "iPhone",
            system: values["system"] as? String ?? "iOS",
            crashes: (values["crashes"] as? NSNumber)?.intValue ?? 0,
            topProcess: values["topProcess"] as? String ?? "",
            topMemory: values["topMemory"] as? String ?? "",
            russian: (values["russian"] as? NSNumber)?.boolValue ?? false,
            accentName: values["accent"] as? String ?? "cyan",
            primaryMetric: values["primaryMetric"] as? String ?? "battery",
            refreshMinutes: max(5, (values["refreshMinutes"] as? NSNumber)?.intValue ?? 15),
            deepLink: values["deepLink"] as? String ?? "ifetch://diagnostics"
        )
    }
}

struct IFetchProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(100, max(0, value)) / 100))
            }
        }
        .frame(height: 5)
    }
}

struct IFetchRing: View {
    let value: Double
    let color: Color
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(min(100, max(0, value)) / 100))
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value >= 0 ? "\(Int(value.rounded()))%" : "—")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 6, weight: .bold))
                    .opacity(0.58)
            }
            .foregroundColor(.white)
        }
    }
}

struct IFetchHeader: View {
    let entry: IFetchEntry
    let compact: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(entry.accent)
                .frame(width: 27, height: 27)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text("iFetch")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(entry.device)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            if !compact {
                Text(entry.system)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct IFetchMetricRow: View {
    let name: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.64))
                Spacer()
                Text("\(Int(value.rounded()))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            IFetchProgressBar(value: value, color: color)
        }
    }
}

struct IFetchSmallView: View {
    let entry: IFetchEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            IFetchHeader(entry: entry, compact: true)
            HStack(spacing: 10) {
                IFetchRing(value: entry.primaryValue, color: entry.accent, label: entry.primaryTitle)
                    .frame(width: 52, height: 52)
                    .accessibilityLabel(entry.primaryTitle)
                VStack(spacing: 9) {
                    IFetchMetricRow(name: "RAM", value: entry.memory, color: Color.purple)
                    IFetchMetricRow(name: entry.russian ? "ДИСК" : "DISK", value: entry.storage,
                                    color: entry.accent)
                }
            }
            HStack {
                Label(entry.uptime, systemImage: "clock")
                Spacer()
                Label("\(entry.crashes)", systemImage: "exclamationmark.triangle")
            }
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(12)
    }
}

struct IFetchMediumView: View {
    let entry: IFetchEntry

    var body: some View {
        VStack(spacing: 11) {
            IFetchHeader(entry: entry, compact: false)
            HStack(spacing: 12) {
                IFetchRing(value: entry.primaryValue, color: entry.accent, label: entry.primaryTitle)
                    .frame(width: 65, height: 65)
                    .accessibilityLabel(entry.primaryTitle)
                VStack(spacing: 10) {
                    IFetchMetricRow(name: "RAM", value: entry.memory, color: Color.purple)
                    IFetchMetricRow(name: entry.russian ? "ХРАНИЛИЩЕ" : "STORAGE", value: entry.storage,
                                    color: entry.accent)
                    HStack {
                        Label(entry.uptime, systemImage: "clock.fill")
                        Spacer()
                        Label("\(entry.crashes) / 24h", systemImage: "exclamationmark.triangle.fill")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(13)
    }
}

struct IFetchLargeView: View {
    let entry: IFetchEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            IFetchHeader(entry: entry, compact: false)
            HStack(spacing: 18) {
                IFetchRing(value: entry.primaryValue, color: entry.accent, label: entry.primaryTitle)
                    .frame(width: 88, height: 88)
                    .accessibilityLabel(entry.primaryTitle)
                VStack(spacing: 13) {
                    IFetchMetricRow(name: "RAM", value: entry.memory, color: Color.purple)
                    IFetchMetricRow(name: entry.russian ? "ХРАНИЛИЩЕ" : "STORAGE", value: entry.storage,
                                    color: entry.accent)
                }
            }
            VStack(spacing: 0) {
                infoRow(entry.russian ? "Время работы" : "Uptime", entry.uptime, "clock.fill")
                Divider().background(Color.white.opacity(0.12))
                infoRow(entry.russian ? "Сбои за 24 часа" : "Crashes in 24h", "\(entry.crashes)", "exclamationmark.triangle.fill")
                Divider().background(Color.white.opacity(0.12))
                infoRow(entry.russian ? "Больше всего ОЗУ" : "Highest memory",
                        entry.topProcess.isEmpty ? "—" : "\(entry.topProcess) · \(entry.topMemory)", "memorychip.fill")
            }
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            Spacer(minLength: 0)
            Text(entry.russian ? "Обновлено \(entry.date, style: .time)" : "Updated \(entry.date, style: .time)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.46))
        }
        .padding(16)
    }

    private func infoRow(_ name: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(entry.accent)
                .frame(width: 18)
            Text(name)
                .foregroundColor(.white.opacity(0.62))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 11)
        .frame(height: 40)
    }
}

struct IFetchWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: IFetchEntry

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.16, blue: 0.31),
                    Color(red: 0.02, green: 0.38, blue: 0.55)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if family == .systemSmall {
                IFetchSmallView(entry: entry)
            } else if family == .systemMedium {
                IFetchMediumView(entry: entry)
            } else {
                IFetchLargeView(entry: entry)
            }
        }
        .widgetURL(URL(string: entry.deepLink))
    }
}

struct IFetchSystemWidget: Widget {
    let kind = "com.wee1ka.ifetch.system"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IFetchProvider()) { entry in
            IFetchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("iFetch System")
        .description("Battery, memory, storage, uptime and crash status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct IFetchWidgets: WidgetBundle {
    var body: some Widget {
        IFetchSystemWidget()
    }
}
