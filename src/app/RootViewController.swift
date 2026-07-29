import UIKit

@objc(RootViewController)
final class RootViewController: IFStyledTableViewController {
    private enum Tab: Int {
        case overview
        case system
        case tools
    }

    private let segmentedControl = UISegmentedControl()
    private var selectedTab = Tab.overview
    private var device = IFDeviceInfo.currentDevice()
    private var jailbreak = IFetchCore.jailbreakInfo()
    private let networkMonitor = IFNetworkMonitor()
    private let alertMonitor = IFLiveMetricsMonitor()
    private var networkSnapshot = IFNetworkSnapshot()
    private var publicIPAddress = ""
    private var refreshTimer: Timer?
    private var refreshTick = 0

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "iFetch"
        networkSnapshot = networkMonitor.refresh()
        publicIPAddress = IFL("Loading…", "Загрузка…")
        tableView.rowHeight = 58
        tableView.estimatedRowHeight = 58
        tableView.cellLayoutMarginsFollowReadableWidth = true
        setupHeader()
        fetchPublicIPAddress()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "waveform.path.ecg"),
            style: .plain,
            target: self,
            action: #selector(showDiagnostics)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = IFL("Diagnostics", "Диагностика")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopLiveUpdates),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startLiveUpdates),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        startLiveUpdates()
    }

    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        device = IFDeviceInfo.currentDevice()
        jailbreak = IFetchCore.jailbreakInfo()
        tableView.reloadData()
    }

    @objc func openDeepLink(_ url: URL) {
        let destination = url.host?.lowercased()
        navigationController?.popToRootViewController(animated: false)
        if destination == "overview" {
            selectedTab = .overview
            segmentedControl.selectedSegmentIndex = Tab.overview.rawValue
            tableView.reloadData()
        } else if destination == "advanced" {
            navigationController?.pushViewController(IFAdvancedMenuViewController(), animated: true)
        } else {
            showDiagnostics()
        }
    }

    private func setupHeader() {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 68))
        let titles = [
            IFL("Overview", "Сводка"),
            IFL("System", "Система"),
            IFL("Tools", "Утилиты")
        ]
        for (index, title) in titles.enumerated() {
            segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = selectedTab.rawValue
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentTintColor = IFAppStyle.accent
        segmentedControl.backgroundColor = .tertiarySystemGroupedBackground
        segmentedControl.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.secondaryLabel,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ],
            for: .normal
        )
        segmentedControl.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 13, weight: .bold)
            ],
            for: .selected
        )
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        header.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),
            segmentedControl.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36)
        ])
        tableView.tableHeaderView = header
    }

    @objc private func segmentChanged() {
        selectedTab = Tab(rawValue: segmentedControl.selectedSegmentIndex) ?? .overview
        tableView.reloadData()
        tableView.setContentOffset(
            CGPoint(x: 0, y: -tableView.adjustedContentInset.top),
            animated: false
        )
    }

    @objc private func startLiveUpdates() {
        guard refreshTimer == nil else {
            return
        }
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refreshLiveData),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func stopLiveUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func refreshLiveData() {
        networkSnapshot = networkMonitor.refresh()
        refreshTick += 1
        if refreshTick.isMultiple(of: 15), IFAdvancedDiagnostics.alertsEnabled() {
            alertMonitor.refresh()
            IFAdvancedDiagnostics.evaluateAlerts(with: alertMonitor)
        }
        if selectedTab == .system {
            tableView.reloadData()
        }
    }

    private func fetchPublicIPAddress() {
        IFNetworkMonitor.fetchPublicIPAddress { [weak self] address in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.publicIPAddress = address
                if self.selectedTab == .system {
                    self.tableView.reloadData()
                }
            }
        }
    }

    @objc private func showDiagnostics() {
        navigationController?.pushViewController(IFDiagnosticsViewController(), animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        switch selectedTab {
        case .overview:
            return 3
        case .system:
            return 2
        case .tools:
            return 4
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch selectedTab {
        case .overview:
            return section == 0 ? 1 : 3
        case .system:
            return section == 0 ? 6 : 4
        case .tools:
            return [2, 3, 2, 1][section]
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch selectedTab {
        case .overview:
            return [
                IFL("Device", "Устройство"),
                IFL("System resources", "Ресурсы системы"),
                IFL("Jailbreak status", "Состояние jailbreak")
            ][section]
        case .system:
            return [
                IFL("Hardware", "Аппаратная часть"),
                IFL("Jailbreak environment", "Среда jailbreak")
            ][section]
        case .tools:
            return [
                IFL("Settings", "Настройки"),
                IFL("System actions", "Системные действия"),
                IFL("Confirmation required", "Требуют подтверждения"),
                IFL("Export", "Экспорт")
            ][section]
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if selectedTab == .system, section == 1, jailbreak.recentCrashCount > 0 {
            return IFL(
                "Crash logs modified within the last 24 hours were found.",
                "Найдены crash-логи, изменённые за последние 24 часа."
            )
        }
        if selectedTab == .tools, section == 2 {
            return IFL(
                "Safe Mode terminates SpringBoard; Userspace Reboot restarts the user environment.",
                "Safe Mode аварийно завершает SpringBoard; Userspace Reboot перезапускает пользовательское окружение."
            )
        }
        return nil
    }

    private func standardCell(title: String, value: String) -> UITableViewCell {
        let identifier = "IFRootValue"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .value1, reuseIdentifier: identifier)
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = value
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        cell.detailTextLabel?.minimumScaleFactor = 0.7
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cell.detailTextLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        cell.textLabel?.textAlignment = .natural
        cell.textLabel?.textColor = .label
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.accessoryType = .none
        cell.selectionStyle = .none
        cell.imageView?.image = nil
        cell.imageView?.tintColor = .label
        IFAppStyle.configure(cell)
        return cell
    }

    private func symbolCell(
        title: String,
        value: String,
        symbol: String,
        color: UIColor
    ) -> UITableViewCell {
        let cell = standardCell(title: title, value: value)
        cell.imageView?.image = IFAppStyle.symbol(symbol, color: color)
            ?? IFAppStyle.symbol("circle.fill", color: color)
        return cell
    }

    private func deviceCell() -> UITableViewCell {
        let identifier = "IFDevice"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        cell.textLabel?.text = device.modelName
        cell.textLabel?.font = .systemFont(ofSize: 21, weight: .bold)
        cell.detailTextLabel?.text = "iOS \(UIDevice.current.systemVersion) · \(jailbreak.environmentName)"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.clipsToBounds = true
        cell.imageView?.image = UIImage(named: device.imageName)
            ?? UIImage(named: "DevicePhotos/iphone-generic.png")
        cell.selectionStyle = .none
        IFAppStyle.configure(cell)
        return cell
    }

    private func actionCell(title: String, symbol: String, color: UIColor) -> UITableViewCell {
        let cell = standardCell(title: title, value: "")
        cell.textLabel?.textAlignment = .natural
        cell.textLabel?.textColor = color == .systemRed ? .systemRed : .label
        cell.imageView?.image = IFAppStyle.symbol(symbol, color: color)
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch selectedTab {
        case .overview:
            return overviewCell(at: indexPath)
        case .system:
            return systemCell(at: indexPath)
        case .tools:
            return toolsCell(at: indexPath)
        }
    }

    private func overviewCell(at indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return deviceCell()
        }
        if indexPath.section == 1 {
            let usedMemory = IFetchCore.usedMemoryBytes()
            let totalStorage = IFetchCore.totalStorageBytes()
            let usedStorage = IFetchCore.usedStorageBytes()
            let rows: [(String, String, String, UIColor)] = [
                (
                    IFL("Memory", "Оперативная память"),
                    usedMemory.map {
                        "\(IFDisplayFormatter.bytes($0.uint64Value)) / \(IFDisplayFormatter.bytes(IFetchCore.totalMemoryBytes()))"
                    } ?? IFL("Unavailable", "Недоступно"),
                    "memorychip",
                    .systemPurple
                ),
                (
                    IFL("Storage", "Накопитель"),
                    usedStorage.flatMap { used in
                        totalStorage.map {
                            "\(IFDisplayFormatter.bytes(used.uint64Value)) / \(IFDisplayFormatter.bytes($0.uint64Value))"
                        }
                    } ?? IFL("Unavailable", "Недоступно"),
                    "internaldrive",
                    .systemBlue
                ),
                (IFL("Uptime", "Аптайм"), IFetchCore.systemUptime(), "clock", .systemGreen)
            ]
            let row = rows[indexPath.row]
            return symbolCell(title: row.0, value: row.1, symbol: row.2, color: row.3)
        }
        let rows: [(String, String, String, UIColor)] = [
            (
                IFL("Installed packages", "Установлено пакетов"),
                "\(jailbreak.installedPackageCount)",
                "shippingbox.fill",
                .systemTeal
            ),
            (
                IFL("Active tweaks", "Активные твики"),
                "\(jailbreak.activeTweakCount)",
                "puzzlepiece.extension.fill",
                .systemOrange
            ),
            (
                IFL("Hook injector", "Хук-инжектор"),
                jailbreak.injectorDescription,
                "point.3.connected.trianglepath.dotted",
                .systemPink
            )
        ]
        let row = rows[indexPath.row]
        return symbolCell(title: row.0, value: row.1, symbol: row.2, color: row.3)
    }

    private func systemCell(at indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let rows: [(String, String, String, UIColor)] = [
                (IFL("Model", "Модель"), device.modelName, "iphone", .systemBlue),
                (IFL("Identifier", "Идентификатор"), device.identifier, "number", .systemIndigo),
                (IFL("Chip", "Чип"), device.chipName, "cpu", .systemOrange),
                (IFL("Architecture", "Архитектура"), device.architectureName, "rectangle.3.group", .systemPurple),
                (IFL("Darwin kernel", "Ядро Darwin"), IFetchCore.darwinVersion(), "terminal", .systemGray),
                (IFL("Thermal state", "Температура"), thermalStateDescription, "thermometer", .systemRed)
            ]
            let row = rows[indexPath.row]
            return symbolCell(title: row.0, value: row.1, symbol: row.2, color: row.3)
        }
        let crashes = jailbreak.recentCrashCount > 0
            ? IFL("\(jailbreak.recentCrashCount) new", "\(jailbreak.recentCrashCount) новых")
            : IFL("No new logs", "Нет новых")
        let rows: [(String, String, String, UIColor)] = [
            (IFL("Environment", "Окружение"), jailbreak.environmentName, "bolt.shield.fill", .systemGreen),
            (IFL("Root", "Корень"), jailbreak.rootPrefix.isEmpty ? "/" : jailbreak.rootPrefix, "folder.fill", .systemBlue),
            (IFL("Hook injector", "Хук-инжектор"), jailbreak.injectorDescription, "point.3.connected.trianglepath.dotted", .systemPink),
            (IFL("Crash logs (24h)", "Crash-логи (24ч)"), crashes, "exclamationmark.triangle.fill", .systemOrange)
        ]
        let row = rows[indexPath.row]
        let cell = symbolCell(title: row.0, value: row.1, symbol: row.2, color: row.3)
        if indexPath.row == 3, jailbreak.recentCrashCount > 0 {
            cell.detailTextLabel?.textColor = .systemOrange
        }
        return cell
    }

    private func toolsCell(at indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let titles = [IFL("Language", "Язык"), IFL("Notifications", "Уведомления")]
            let values = [
                IFLanguageManager.isRussian() ? "Русский" : "English",
                IFL("Configure", "Настроить")
            ]
            let cell = standardCell(title: titles[indexPath.row], value: values[indexPath.row])
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            cell.imageView?.image = indexPath.row == 0
                ? IFAppStyle.symbol("globe", color: .systemBlue)
                : IFAppStyle.symbol("bell.badge.fill", color: .systemOrange)
            return cell
        }
        if indexPath.section == 1 {
            let rows: [(String, String, UIColor)] = [
                ("Respring", "arrow.clockwise.circle.fill", .systemBlue),
                (IFL("Refresh widgets", "Обновить виджеты"), "rectangle.3.group.fill", .systemIndigo),
                (IFL("Refresh icon cache", "Обновить кэш иконок"), "square.grid.2x2.fill", .systemTeal)
            ]
            let row = rows[indexPath.row]
            return actionCell(title: row.0, symbol: row.1, color: row.2)
        }
        if indexPath.section == 2 {
            return actionCell(
                title: indexPath.row == 0 ? IFL("Enter Safe Mode", "Войти в Safe Mode") : "Userspace Reboot",
                symbol: indexPath.row == 0 ? "shield.lefthalf.filled" : "power.circle.fill",
                color: indexPath.row == 0 ? .systemOrange : .systemRed
            )
        }
        return actionCell(
            title: IFL("Copy system report", "Скопировать системный отчёт"),
            symbol: "doc.on.doc.fill",
            color: .systemBlue
        )
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        selectedTab == .overview && indexPath.section == 0 ? 100 : 58
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard selectedTab == .tools else {
            return
        }
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                showLanguagePicker()
            } else {
                navigationController?.pushViewController(IFPreferencesViewController(), animated: true)
            }
        } else if indexPath.section == 1, indexPath.row == 0 {
            confirmAction(
                title: IFL("Perform Respring?", "Выполнить Respring?"),
                message: IFL("SpringBoard will be restarted.", "SpringBoard будет перезапущен."),
                command: "sbreload",
                arguments: []
            )
        } else if indexPath.section == 1, indexPath.row == 1 {
            refreshWidgets()
        } else if indexPath.section == 1, indexPath.row == 2 {
            runCommand(
                "uicache",
                arguments: ["-a", "-r"],
                successMessage: IFL("The icon cache has been refreshed", "Кэш иконок обновлён")
            )
        } else if indexPath.section == 2, indexPath.row == 0 {
            confirmAction(
                title: IFL("Enter Safe Mode?", "Войти в Safe Mode?"),
                message: IFL(
                    "SpringBoard will be terminated with a SEGV signal.",
                    "SpringBoard будет аварийно завершён сигналом SEGV."
                ),
                command: "killall",
                arguments: ["-SEGV", "SpringBoard"]
            )
        } else if indexPath.section == 2, indexPath.row == 1 {
            confirmAction(
                title: IFL("Perform Userspace Reboot?", "Выполнить Userspace Reboot?"),
                message: IFL(
                    "All apps will close and the user environment will restart.",
                    "Все приложения закроются, пользовательское окружение будет перезапущено."
                ),
                command: "launchctl",
                arguments: ["reboot", "userspace"]
            )
        } else if indexPath.section == 3 {
            showExportOptions()
        }
    }

    private func refreshWidgets() {
        DispatchQueue.global(qos: .utility).async {
            do {
                try IFAdvancedDiagnostics.refreshWidgets()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    IFWidgetRefreshBridge.reload()
                    IFShowMessage(
                        on: self,
                        message: IFL(
                            "Widget cache was reset. WidgetKit will rebuild the widgets shortly.",
                            "Кэш виджетов сброшен. WidgetKit вскоре пересоздаст виджеты."
                        )
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    IFShowMessage(on: self, message: error.localizedDescription)
                }
            }
        }
    }

    private func showLanguagePicker() {
        let alert = UIAlertController(title: IFL("Language", "Язык"), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "English", style: .default) { [weak self] _ in
            if let language = IFLanguage(rawValue: 0) {
                IFLanguageManager.setCurrentLanguage(language)
            }
            self?.applySelectedLanguage()
        })
        alert.addAction(UIAlertAction(title: "Русский", style: .default) { [weak self] _ in
            if let language = IFLanguage(rawValue: 1) {
                IFLanguageManager.setCurrentLanguage(language)
            }
            self?.applySelectedLanguage()
        })
        alert.addAction(UIAlertAction(title: IFL("Cancel", "Отмена"), style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.maxY - 1,
            width: 1,
            height: 1
        )
        present(alert, animated: true)
    }

    private func applySelectedLanguage() {
        segmentedControl.setTitle(IFL("Overview", "Сводка"), forSegmentAt: 0)
        segmentedControl.setTitle(IFL("System", "Система"), forSegmentAt: 1)
        segmentedControl.setTitle(IFL("Tools", "Утилиты"), forSegmentAt: 2)
        device = IFDeviceInfo.currentDevice()
        jailbreak = IFetchCore.jailbreakInfo()
        networkSnapshot = networkMonitor.refresh()
        publicIPAddress = IFL("Loading…", "Загрузка…")
        navigationItem.rightBarButtonItem?.accessibilityLabel = IFL("Diagnostics", "Диагностика")
        tableView.reloadData()
        fetchPublicIPAddress()
    }

    private var thermalStateDescription: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return IFL("Nominal", "Норма")
        case .fair:
            return IFL("Fair", "Повышена")
        case .serious:
            return IFL("Serious", "Высокая")
        case .critical:
            return IFL("Critical", "Критическая")
        @unknown default:
            return IFL("Unavailable", "Недоступно")
        }
    }

    private func confirmAction(
        title: String,
        message: String,
        command: String,
        arguments: [String]
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: IFL("Cancel", "Отмена"), style: .cancel))
        alert.addAction(UIAlertAction(title: IFL("Continue", "Продолжить"), style: .destructive) { [weak self] _ in
            self?.runCommand(command, arguments: arguments, successMessage: nil)
        })
        present(alert, animated: true)
    }

    private func runCommand(_ command: String, arguments: [String], successMessage: String?) {
        IFSystemActions.runCommand(command, arguments: arguments) { [weak self] exitCode, signalNumber, error in
            guard let self else {
                return
            }
            if let error {
                IFShowMessage(on: self, message: error.localizedDescription)
            } else if signalNumber != 0 {
                IFShowMessage(
                    on: self,
                    message: IFL(
                        "\(command) was terminated by signal \(signalNumber)",
                        "\(command) завершилась по сигналу \(signalNumber)"
                    )
                )
            } else if exitCode != 0 {
                IFShowMessage(
                    on: self,
                    message: IFL(
                        "\(command) exited with code \(exitCode)",
                        "\(command) завершилась с кодом \(exitCode)"
                    )
                )
            } else if let successMessage {
                IFShowMessage(on: self, message: successMessage)
            }
        }
    }

    private func showExportOptions() {
        let sheet = UIAlertController(
            title: IFL("System report", "Системный отчёт"),
            message: IFL(
                "Choose whether network addresses should be hidden.",
                "Выберите, нужно ли скрыть сетевые адреса."
            ),
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(
            title: IFL("Copy private report", "Копировать приватный отчёт"),
            style: .default
        ) { [weak self] _ in
            self?.copyReport(redacted: true)
        })
        sheet.addAction(UIAlertAction(
            title: IFL("Copy full report", "Копировать полный отчёт"),
            style: .default
        ) { [weak self] _ in
            self?.copyReport(redacted: false)
        })
        sheet.addAction(UIAlertAction(title: IFL("Cancel", "Отмена"), style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.maxY,
            width: 1,
            height: 1
        )
        present(sheet, animated: true)
    }

    private func copyReport(redacted: Bool) {
        let unavailable = IFL("Unavailable", "Недоступно")
        let memory = IFetchCore.usedMemoryBytes().map {
            IFDisplayFormatter.bytes($0.uint64Value)
        } ?? unavailable
        let storage = IFetchCore.usedStorageBytes().map {
            IFDisplayFormatter.bytes($0.uint64Value)
        } ?? unavailable
        let localIP = redacted
            ? IFDiagnostics.redactedAddress(networkSnapshot.localIPAddress)
            : networkSnapshot.localIPAddress
        let publicIP = redacted
            ? IFDiagnostics.redactedAddress(publicIPAddress)
            : publicIPAddress
        let report = [
            "iFetch \(IFetchCore.versionString())",
            "\(IFL("Device", "Устройство")): \(device.modelName) (\(device.identifier))",
            "iOS: \(UIDevice.current.systemVersion)",
            "\(IFL("Architecture", "Архитектура")): \(device.architectureName)",
            "\(IFL("Kernel", "Ядро")): \(IFetchCore.darwinVersion())",
            "\(IFL("Uptime", "Аптайм")): \(IFetchCore.systemUptime())",
            "\(IFL("Memory used", "ОЗУ занято")): \(memory)",
            "\(IFL("Storage used", "Диск занято")): \(storage)",
            "Jailbreak: \(jailbreak.environmentName)",
            "\(IFL("Hook injector", "Хук-инжектор")): \(jailbreak.injectorDescription)",
            "\(IFL("Packages", "Пакеты")): \(jailbreak.installedPackageCount)",
            "\(IFL("Active tweaks", "Активные твики")): \(jailbreak.activeTweakCount)",
            "\(IFL("New crash logs", "Новые crash-логи")): \(jailbreak.recentCrashCount)",
            "\(IFL("Local IP", "Локальный IP")): \(localIP)",
            "\(IFL("Public IP", "Публичный IP")): \(publicIP)"
        ].joined(separator: "\n")
        UIPasteboard.general.string = report
        IFShowMessage(on: self, message: IFL("System report copied", "Системный отчёт скопирован"))
    }
}
