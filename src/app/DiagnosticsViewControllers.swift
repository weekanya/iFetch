import CoreLocation
import Darwin
import UIKit

final class IFChartsViewController: UIViewController {
    private let monitor = IFLiveMetricsMonitor()
    private var timer: Timer?
    private var charts: [IFLineChartView] = []
    private var valueLabels: [UILabel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Live charts", "Графики")
        view.backgroundColor = .systemGroupedBackground

        let scrollView = UIScrollView()
        let stackView = UIStackView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        let titles = [
            IFL("CPU usage", "Загрузка CPU"),
            IFL("Memory usage", "Использование ОЗУ"),
            IFL("Download speed", "Скорость скачивания"),
            IFL("Upload speed", "Скорость отдачи"),
            IFL("Battery temperature", "Температура батареи"),
            IFL("Battery level", "Уровень заряда")
        ]
        let colors: [UIColor] = [
            .systemOrange, .systemPurple, .systemBlue,
            .systemTeal, .systemRed, .systemGreen
        ]

        for index in titles.indices {
            let heading = UILabel()
            heading.text = titles[index]
            heading.font = .preferredFont(forTextStyle: .headline)
            let value = UILabel()
            value.textColor = .secondaryLabel
            value.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
            let chart = IFLineChartView()
            chart.lineColor = colors[index]
            chart.fixedMaximum = index < 2 || index == 5 ? 100 : (index == 4 ? 60 : 0)
            chart.unit = index < 2 || index == 5 ? "%" : (index == 4 ? "°" : "")
            chart.rateValues = index == 2 || index == 3
            chart.translatesAutoresizingMaskIntoConstraints = false
            chart.heightAnchor.constraint(equalToConstant: 120).isActive = true
            stackView.addArrangedSubview(heading)
            stackView.addArrangedSubview(value)
            stackView.addArrangedSubview(chart)
            charts.append(chart)
            valueLabels.append(value)
        }

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    @objc private func refresh() {
        monitor.refresh()
        let history = monitor.history
        charts[0].values = history.map(\.cpuPercent)
        charts[1].values = history.map(\.memoryPercent)
        charts[2].values = history.map(\.downloadBytesPerSecond)
        charts[3].values = history.map(\.uploadBytesPerSecond)
        charts[4].values = history.map(\.batteryTemperature)
        charts[5].values = history.map(\.batteryLevel)
        guard let latest = history.last else {
            return
        }
        valueLabels[0].text = IFDisplayFormatter.percent(latest.cpuPercent)
        valueLabels[1].text = IFDisplayFormatter.percent(latest.memoryPercent)
        valueLabels[2].text = "↓ \(IFDisplayFormatter.rate(latest.downloadBytesPerSecond))"
        valueLabels[3].text = "↑ \(IFDisplayFormatter.rate(latest.uploadBytesPerSecond))"
        valueLabels[4].text = latest.batteryTemperature > 0
            ? IFDisplayFormatter.temperature(latest.batteryTemperature)
            : IFL("Unavailable", "Недоступно")
        valueLabels[5].text = latest.batteryLevel > 0
            ? IFDisplayFormatter.roundedPercent(latest.batteryLevel)
            : IFL("Unavailable", "Недоступно")
    }
}

final class IFBatteryViewController: UITableViewController {
    private var battery = IFDiagnostics.batteryDetails()
    private var lastUpdated: Date?

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Battery diagnostics", "Диагностика батареи")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refresh)
        )
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    @objc private func refresh() {
        navigationItem.rightBarButtonItem?.isEnabled = false
        battery = IFDiagnostics.batteryDetails()
        lastUpdated = Date()
        tableView.reloadData()
        refreshControl?.endRefreshing()
        navigationItem.rightBarButtonItem?.isEnabled = true
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let lastUpdated else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return "\(IFL("Updated", "Обновлено")) \(formatter.string(from: lastUpdated))"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        9
    }

    private func value(_ number: NSNumber?, suffix: String) -> String {
        guard let number else {
            return IFL("Unavailable", "Недоступно")
        }
        return String(format: "%.1f%@", number.doubleValue, suffix)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let rows: [(String, String)] = [
            (
                IFL("Health", "Здоровье"),
                battery.healthPercent > 0
                    ? IFDisplayFormatter.roundedPercent(battery.healthPercent)
                    : IFL("Unavailable", "Недоступно")
            ),
            (IFL("Current capacity", "Текущая ёмкость"), value(battery.currentCapacity, suffix: " mAh")),
            (IFL("Maximum capacity", "Максимальная ёмкость"), value(battery.maximumCapacity, suffix: " mAh")),
            (IFL("Design capacity", "Проектная ёмкость"), value(battery.designCapacity, suffix: " mAh")),
            (IFL("Cycles", "Циклы"), battery.cycleCount?.stringValue ?? IFL("Unavailable", "Недоступно")),
            (IFL("Temperature", "Температура"), value(battery.temperatureCelsius, suffix: " °C")),
            (IFL("Voltage", "Напряжение"), value(battery.voltageMillivolts, suffix: " mV")),
            (IFL("Current", "Ток"), value(battery.amperageMilliamps, suffix: " mA")),
            (
                IFL("Charging power", "Мощность зарядки"),
                battery.externalConnected
                    ? String(format: "%.1f W%@", battery.chargingWatts, battery.chargingWatts >= 15 ? " · Fast" : "")
                    : IFL("Not connected", "Не подключена")
            )
        ]
        let row = rows[indexPath.row]
        return IFValueCell(tableView, identifier: "IFBatteryValue", title: row.0, detail: row.1)
    }
}

final class IFProcessDetailViewController: UIViewController {
    private let pid: pid_t
    private let processName: String
    private let executablePath: String
    private let processMonitor = IFProcessMonitor()
    private let chart = IFLineChartView()
    private let detailsLabel = UILabel()
    private let terminateButton = UIButton(type: .system)
    private var cpuHistory: [Double] = []
    private var timer: Timer?
    private var relatedTweaks: [String]?

    init(process: IFProcessSample) {
        pid = process.pid
        processName = process.name
        executablePath = process.executablePath
        super.init(nibName: nil, bundle: nil)
        title = process.name
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let heading = UILabel()
        heading.translatesAutoresizingMaskIntoConstraints = false
        heading.text = IFL("CPU history", "История CPU")
        heading.font = .preferredFont(forTextStyle: .headline)

        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.fixedMaximum = 100
        chart.lineColor = .systemOrange

        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.numberOfLines = 0
        detailsLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        terminateButton.translatesAutoresizingMaskIntoConstraints = false
        terminateButton.backgroundColor = .systemRed
        terminateButton.tintColor = .white
        terminateButton.layer.cornerRadius = 12
        terminateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        terminateButton.setTitle(IFL("Terminate process", "Завершить процесс"), for: .normal)
        terminateButton.addTarget(self, action: #selector(confirmTermination), for: .touchUpInside)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "network"),
            style: .plain,
            target: self,
            action: #selector(showConnections)
        )

        view.addSubview(heading)
        view.addSubview(chart)
        view.addSubview(detailsLabel)
        view.addSubview(terminateButton)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            heading.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            heading.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            chart.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            chart.trailingAnchor.constraint(equalTo: heading.trailingAnchor),
            chart.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 10),
            chart.heightAnchor.constraint(equalToConstant: 150),
            detailsLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: heading.trailingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: chart.bottomAnchor, constant: 18),
            terminateButton.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            terminateButton.trailingAnchor.constraint(equalTo: heading.trailingAnchor),
            terminateButton.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: 18),
            terminateButton.heightAnchor.constraint(equalToConstant: 50),
            terminateButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -18
            )
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func currentProcess() -> IFProcessSample? {
        processMonitor.refresh()
        return processMonitor.allProcesses().first { $0.pid == pid }
    }

    @objc private func refresh() {
        guard let process = currentProcess() else {
            detailsLabel.text = IFL("The process has exited.", "Процесс завершился.")
            terminateButton.isEnabled = false
            terminateButton.alpha = 0.45
            terminateButton.setTitle(IFL("Process exited", "Процесс завершён"), for: .normal)
            timer?.invalidate()
            timer = nil
            return
        }
        cpuHistory.append(process.cpuPercent)
        if cpuHistory.count > 300 {
            cpuHistory.removeFirst()
        }
        chart.values = cpuHistory
        if relatedTweaks == nil {
            relatedTweaks = IFDiagnostics.installedTweaks()
                .filter { $0.targetExecutables.contains(process.name) }
                .map(\.name)
        }
        let hours = Int(process.runningTime / 3600)
        let minutes = Int(process.runningTime.truncatingRemainder(dividingBy: 3600)) / 60
        let path = process.executablePath.isEmpty
            ? IFL("Path unavailable", "Путь недоступен")
            : process.executablePath
        let tweaks = relatedTweaks?.isEmpty == false
            ? relatedTweaks?.joined(separator: ", ") ?? ""
            : IFL("Not detected", "Не обнаружены")
        detailsLabel.text = [
            "PID: \(process.pid)",
            "CPU: \(IFDisplayFormatter.percent(process.cpuPercent))",
            "RAM: \(IFDisplayFormatter.bytes(process.residentBytes))",
            "\(IFL("Threads", "Потоки")): \(process.threadCount)",
            "\(IFL("Running", "Работает")): \(hours)h \(minutes)m",
            "",
            path,
            "",
            "\(IFL("Injected tweaks", "Внедряемые твики")): \(tweaks)"
        ].joined(separator: "\n")
    }

    @objc private func showConnections() {
        guard let process = currentProcess() else {
            return
        }
        navigationController?.pushViewController(
            IFProcessConnectionsViewController(process: process),
            animated: true
        )
    }

    private func isProtected(_ process: IFProcessSample?) -> Bool {
        guard let process else {
            return true
        }
        return process.pid <= 1
            || process.pid == getpid()
            || ["kernel_task", "launchd"].contains(process.name.lowercased())
    }

    private func isSame(_ process: IFProcessSample?) -> Bool {
        guard let process, process.pid == pid else {
            return false
        }
        if !executablePath.isEmpty, !process.executablePath.isEmpty {
            return executablePath == process.executablePath
        }
        return !processName.isEmpty && processName == process.name
    }

    @objc private func confirmTermination() {
        guard let process = currentProcess(), isSame(process) else {
            refresh()
            return
        }
        guard !isProtected(process) else {
            IFShowMessage(
                on: self,
                title: IFL("Protected process", "Защищённый процесс"),
                message: IFL(
                    "iFetch will not terminate launchd, kernel_task or itself.",
                    "iFetch не завершает launchd, kernel_task и собственный процесс."
                )
            )
            return
        }
        let alert = UIAlertController(
            title: IFL("Terminate process", "Завершить процесс"),
            message: IFL(
                "Send SIGTERM to \(process.name) (PID \(process.pid))? System daemons may restart the interface.",
                "Отправить SIGTERM процессу \(process.name) (PID \(process.pid))? Системные демоны могут перезапустить интерфейс."
            ),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: IFL("Terminate", "Завершить"), style: .destructive) { [weak self] _ in
            self?.terminateCurrentProcess()
        })
        alert.addAction(UIAlertAction(title: IFL("Cancel", "Отмена"), style: .cancel))
        alert.popoverPresentationController?.sourceView = terminateButton
        alert.popoverPresentationController?.sourceRect = terminateButton.bounds
        present(alert, animated: true)
    }

    private func terminateCurrentProcess() {
        guard let process = currentProcess(), isSame(process), !isProtected(process) else {
            refresh()
            return
        }
        do {
            try IFSystemActions.terminateProcess(process.pid)
            terminateButton.isEnabled = false
            terminateButton.alpha = 0.45
            terminateButton.setTitle(IFL("Termination requested", "Завершение запрошено"), for: .normal)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refresh()
            }
        } catch {
            IFShowMessage(
                on: self,
                title: IFL("Could not terminate process", "Не удалось завершить процесс"),
                message: error.localizedDescription
            )
        }
    }
}

final class IFProcessesViewController: UITableViewController {
    private let monitor = IFLiveMetricsMonitor()
    private let mode = UISegmentedControl(items: ["CPU", "RAM"])
    private var timer: Timer?
    private var samples: [IFProcessSample] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Processes", "Процессы")
        mode.selectedSegmentIndex = 0
        mode.addTarget(self, action: #selector(reload), for: .valueChanged)
        navigationItem.titleView = mode
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tick()
        timer = Timer.scheduledTimer(
            timeInterval: 2,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    @objc private func tick() {
        monitor.refresh()
        reload()
    }

    @objc private func reload() {
        samples = mode.selectedSegmentIndex == 0
            ? monitor.processes.topProcesses(byCPU: 50)
            : monitor.processes.topProcesses(byMemory: 50)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        samples.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let process = samples[indexPath.row]
        let cell = IFValueCell(
            tableView,
            identifier: "IFProcess",
            title: process.name,
            detail: "PID \(process.pid) · \(IFDisplayFormatter.percent(process.cpuPercent)) · \(IFDisplayFormatter.bytes(process.residentBytes))"
        )
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        if monitor.sustainedHighCPUProcesses().contains(where: { $0.pid == process.pid }) {
            cell.textLabel?.textColor = .systemOrange
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(
            IFProcessDetailViewController(process: samples[indexPath.row]),
            animated: true
        )
    }
}

final class IFCrashDetailViewController: UIViewController {
    private let log: IFCrashLog

    init(log: IFCrashLog) {
        self.log = log
        super.init(nibName: nil, bundle: nil)
        title = log.name
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let analysis = IFAdvancedDiagnostics.analysis(forCrashLog: log)
        textView.text = "\(analysis.summary)\n\n————————————\n\n\(log.preview)"
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(share)
        )
    }

    @objc private func share() {
        guard !log.path.isEmpty else {
            return
        }
        let controller = UIActivityViewController(
            activityItems: [URL(fileURLWithPath: log.path)],
            applicationActivities: nil
        )
        controller.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(controller, animated: true)
    }
}

final class IFCrashLogsViewController: UITableViewController {
    private var logs: [IFCrashLog] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Crash Logs", "Журнал сбоев")
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reloadLogs), for: .valueChanged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadLogs),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        reloadLogs()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadLogs()
    }

    @objc private func reloadLogs() {
        logs = IFDiagnostics.recentCrashLogs(withLimit: 200)
        ifEmptyBackground(IFL("No crash reports found", "Отчёты о сбоях не найдены"), visible: logs.isEmpty)
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        logs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let log = logs[indexPath.row]
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let cell = IFValueCell(
            tableView,
            identifier: "IFCrash",
            title: log.name,
            detail: "\(log.kind) · \(formatter.string(from: log.date))"
        )
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(IFCrashDetailViewController(log: logs[indexPath.row]), animated: true)
    }
}

final class IFTweaksViewController: UITableViewController, UISearchResultsUpdating {
    private var allTweaks: [IFTweakRecord] = []
    private var visibleTweaks: [IFTweakRecord] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Installed tweaks", "Установленные твики")
        allTweaks = IFDiagnostics.installedTweaks()
        visibleTweaks = allTweaks
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.lowercased() ?? ""
        visibleTweaks = query.isEmpty ? allTweaks : allTweaks.filter {
            $0.name.lowercased().contains(query)
                || $0.packageIdentifier.lowercased().contains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleTweaks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tweak = visibleTweaks[indexPath.row]
        let state = tweak.isEnabled ? IFL("Enabled", "Включён") : IFL("Disabled", "Отключён")
        let cell = IFValueCell(
            tableView,
            identifier: "IFTweak",
            title: tweak.name,
            detail: "\(tweak.packageIdentifier) \(tweak.packageVersion) · \(state)"
        )
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        cell.textLabel?.textColor = tweak.isEnabled ? .label : .secondaryLabel
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let tweak = visibleTweaks[indexPath.row]
        let combinedTargets = tweak.targetBundles + tweak.targetExecutables
        let targets = combinedTargets.isEmpty
            ? IFL("All processes / unspecified", "Все процессы / не указано")
            : combinedTargets.joined(separator: "\n")
        let state = tweak.isEnabled ? IFL("Enabled", "Включён") : IFL("Disabled", "Отключён")
        let message = [
            tweak.dylibPath,
            "\(tweak.packageIdentifier) \(tweak.packageVersion)",
            "",
            "\(IFL("Targets", "Цели")):",
            targets,
            "",
            "\(IFL("State", "Состояние")):",
            state
        ].joined(separator: "\n")
        let alert = UIAlertController(title: tweak.name, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: IFL("Copy", "Копировать"), style: .default) { _ in
            UIPasteboard.general.string = message
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}

final class IFHealthViewController: UITableViewController {
    private let monitor = IFLiveMetricsMonitor()
    private var items: [IFHealthItem] = []
    private var samplingTimer: Timer?
    private var refreshTimer: Timer?
    private var sampleCount = 0

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Jailbreak Health"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refresh)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(refreshStatus),
            userInfo: nil,
            repeats: true
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        samplingTimer?.invalidate()
        samplingTimer = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func refresh() {
        samplingTimer?.invalidate()
        sampleCount = 0
        sampleHealth()
        samplingTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(sampleHealth),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func refreshStatus() {
        monitor.refresh()
        items = IFDiagnostics.healthItems(
            withJailbreak: IFetchCore.jailbreakInfo(),
            battery: IFDiagnostics.batteryDetails(),
            processes: monitor.sustainedHighCPUProcesses()
        )
        tableView.reloadData()
    }

    @objc private func sampleHealth() {
        refreshStatus()
        sampleCount += 1
        if sampleCount >= 5 {
            samplingTimer?.invalidate()
            samplingTimer = nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == items.count {
            let cell = IFValueCell(
                tableView,
                identifier: "IFIntegrityLink",
                title: IFL("Jailbreak integrity", "Целостность jailbreak"),
                detail: IFL(
                    "Bootstrap files, packages, injection filters and symlinks",
                    "Файлы bootstrap, пакеты, фильтры инъекции и символические ссылки"
                )
            )
            cell.imageView?.image = UIImage(systemName: "checkmark.shield")
            cell.imageView?.tintColor = .systemBlue
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell
        }
        let item = items[indexPath.row]
        let symbols = ["checkmark.circle.fill", "exclamationmark.triangle.fill", "xmark.octagon.fill"]
        let colors: [UIColor] = [.systemGreen, .systemOrange, .systemRed]
        let state = min(max(0, item.state.rawValue), symbols.count - 1)
        let cell = IFValueCell(
            tableView,
            identifier: "IFHealth",
            title: item.title,
            detail: item.detail
        )
        cell.imageView?.image = UIImage(systemName: symbols[state])
        cell.imageView?.tintColor = colors[state]
        if item.identifier == "recent_crashes" {
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == items.count {
            navigationController?.pushViewController(IFIntegrityViewController(), animated: true)
        } else if items[indexPath.row].identifier == "recent_crashes" {
            navigationController?.pushViewController(IFCrashLogsViewController(), animated: true)
        }
    }
}

final class IFNetworkDetailsViewController: UITableViewController, CLLocationManagerDelegate {
    private var details: [String: Any] = [:]
    private let locationManager = CLLocationManager()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Network details", "Сетевые детали")
        locationManager.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(loadDetails)
        )
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            loadDetails()
        }
    }

    @objc private func loadDetails() {
        navigationItem.rightBarButtonItem?.isEnabled = false
        DispatchQueue.global(qos: .utility).async {
            let details = IFDiagnostics.extendedNetworkDetails()
            DispatchQueue.main.async {
                self.details = details
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                self.tableView.reloadData()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus != .notDetermined {
            loadDetails()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 9
        }
        return (details["interfaces"] as? [String: Any])?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0
            ? IFL("Connection", "Подключение")
            : IFL("Traffic totals by interface", "Трафик по интерфейсам")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let locationAllowed = locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways
            let wifiUnavailable = locationAllowed
                ? IFL("Unavailable", "Недоступно")
                : IFL("Location permission required", "Требуется доступ к геолокации")
            let internetAvailable = (details["internetAvailable"] as? NSNumber)?.boolValue ?? false
            let internetError = details["internetError"] as? String ?? ""
            let internetValue = internetAvailable
                ? IFL("Available", "Доступен")
                : (internetError.isEmpty ? IFL("Unavailable", "Недоступен") : internetError)
            let latency = (details["dnsLatency"] as? NSNumber)?.doubleValue ?? -1
            let httpsLatency = (details["internetLatency"] as? NSNumber)?.doubleValue ?? -1
            let string = { (key: String) -> String in self.details[key] as? String ?? "" }
            let rows: [(String, String)] = [
                ("IPv4", string("ipv4")),
                ("IPv6", string("ipv6")),
                ("Wi-Fi SSID", string("ssid").isEmpty ? wifiUnavailable : string("ssid")),
                ("BSSID", string("bssid").isEmpty ? wifiUnavailable : string("bssid")),
                (
                    IFL("Cellular", "Сотовая сеть"),
                    string("radio").isEmpty
                        ? IFL("No active cellular service", "Нет активной сотовой сети")
                        : string("radio")
                ),
                ("VPN", string("vpn").isEmpty ? IFL("None", "Нет") : string("vpn")),
                (
                    IFL("DNS latency", "Задержка DNS"),
                    latency >= 0 ? IFDisplayFormatter.latency(latency) : IFL("Unavailable", "Недоступно")
                ),
                (IFL("Internet", "Интернет"), internetValue),
                (
                    IFL("HTTPS latency", "Задержка HTTPS"),
                    httpsLatency >= 0
                        ? IFDisplayFormatter.latency(httpsLatency)
                        : IFL("Unavailable", "Недоступно")
                )
            ]
            let row = rows[indexPath.row]
            return IFValueCell(tableView, identifier: "IFNetworkValue", title: row.0, detail: row.1)
        }

        let interfaces = details["interfaces"] as? [String: [String: NSNumber]] ?? [:]
        let names = interfaces.keys.sorted()
        let name = names[indexPath.row]
        let traffic = interfaces[name] ?? [:]
        return IFValueCell(
            tableView,
            identifier: "IFNetworkTraffic",
            title: name,
            detail: "↓ \(IFDisplayFormatter.bytes(traffic["received"]?.uint64Value ?? 0))  ↑ \(IFDisplayFormatter.bytes(traffic["sent"]?.uint64Value ?? 0))"
        )
    }
}

@objc(IFDiagnosticsViewController)
final class IFDiagnosticsViewController: UITableViewController {
    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Diagnostics", "Диагностика")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        8
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let titles = [
            IFL("Live charts", "Графики в реальном времени"),
            IFL("Battery diagnostics", "Диагностика батареи"),
            IFL("Process explorer", "Диспетчер процессов"),
            "Crash Logs",
            IFL("Installed tweaks", "Установленные твики"),
            "Jailbreak Health",
            IFL("Network details", "Сетевые детали"),
            IFL("Advanced diagnostics", "Расширенная диагностика")
        ]
        let details = [
            IFL("CPU, RAM, network and temperature history", "История CPU, ОЗУ, сети и температуры"),
            IFL("Capacity, health, current and charging power", "Ёмкость, здоровье, ток и мощность зарядки"),
            IFL("Top-50, path, PID and sustained load alerts", "Top-50, путь, PID и длительная нагрузка"),
            IFL("View, copy and share diagnostic reports", "Просмотр и отправка диагностических отчётов"),
            IFL("Packages, dylibs and injection filters", "Пакеты, dylib и фильтры инъекции"),
            IFL("Rootless bootstrap and system status", "Состояние bootstrap и системы"),
            IFL("IPv4/IPv6, Wi-Fi, cellular and traffic", "IPv4/IPv6, Wi-Fi, сотовая сеть и трафик"),
            IFL("Snapshots, injection, daemons and diagnostic mode", "Снимки, инъекции, демоны и режим диагностики")
        ]
        let symbols = [
            "chart.xyaxis.line", "battery.100", "cpu", "doc.text.magnifyingglass",
            "puzzlepiece.extension", "heart.text.square", "network", "waveform.badge.magnifyingglass"
        ]
        let cell = IFValueCell(
            tableView,
            identifier: "IFDiagnosticsMenu",
            title: titles[indexPath.row],
            detail: details[indexPath.row]
        )
        cell.imageView?.image = UIImage(systemName: symbols[indexPath.row])
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller: UIViewController
        switch indexPath.row {
        case 0:
            controller = IFChartsViewController()
        case 1:
            controller = IFBatteryViewController()
        case 2:
            controller = IFProcessesViewController()
        case 3:
            controller = IFCrashLogsViewController()
        case 4:
            controller = IFTweaksViewController()
        case 5:
            controller = IFHealthViewController()
        case 6:
            controller = IFNetworkDetailsViewController()
        default:
            controller = IFAdvancedMenuViewController()
        }
        navigationController?.pushViewController(controller, animated: true)
    }
}
