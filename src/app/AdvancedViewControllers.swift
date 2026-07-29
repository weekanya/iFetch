import UIKit

final class IFProcessConnectionsViewController: UITableViewController {
    private let process: IFProcessSample
    private var connections: [IFProcessConnection] = []

    init(process: IFProcessSample) {
        self.process = process
        super.init(style: .insetGrouped)
        title = IFL("Connections", "Соединения")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reloadConnections), for: .valueChanged)
        reloadConnections()
    }

    @objc private func reloadConnections() {
        connections = IFAdvancedDiagnostics.connections(forProcess: process)
        ifEmptyBackground(
            IFL("No visible network connections", "Видимые сетевые соединения не найдены"),
            visible: connections.isEmpty
        )
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        connections.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        IFL(
            "Includes the selected app and active processes from its .app bundle, including Network Extensions.",
            "Показывает выбранное приложение и активные процессы из его .app, включая Network Extension."
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let connection = connections[indexPath.row]
        let state = connection.state.isEmpty ? "" : " · \(connection.state)"
        let title = connection.processName.isEmpty
            ? connection.protocolName
            : "\(connection.processName) · \(connection.protocolName)"
        let cell = IFValueCell(
            tableView,
            identifier: "IFConnection",
            title: title,
            detail: "\(connection.localEndpoint) → \(connection.remoteEndpoint)\(state)",
            lines: 3
        )
        cell.imageView?.image = UIImage(systemName: "network")
        return cell
    }
}

final class IFInjectionMapViewController: UITableViewController, UISearchResultsUpdating {
    private var groups: [IFInjectionGroup] = []
    private var visibleGroups: [IFInjectionGroup] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Injection map", "Карта инъекций")
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reload)
        )
        reload()
    }

    @objc private func reload() {
        groups = IFAdvancedDiagnostics.injectionMap()
        visibleGroups = groups
        tableView.reloadData()
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.lowercased() ?? ""
        visibleGroups = query.isEmpty ? groups : groups.filter {
            $0.target.lowercased().contains(query)
                || $0.tweaks.joined(separator: " ").lowercased().contains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleGroups.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let group = visibleGroups[indexPath.row]
        let running = group.runningProcesses.isEmpty
            ? IFL("No matching running process", "Совпадающий процесс не запущен")
            : "\(IFL("Running", "Запущено")): \(group.runningProcesses.joined(separator: ", "))"
        let cell = IFValueCell(
            tableView,
            identifier: "IFInjection",
            title: group.target,
            detail: "\(group.tweaks.joined(separator: ", "))\n\(running)",
            lines: 3
        )
        cell.imageView?.image = UIImage(
            systemName: group.runningProcesses.isEmpty ? "bolt" : "bolt.fill"
        )
        cell.imageView?.tintColor = group.runningProcesses.isEmpty ? .secondaryLabel : .systemGreen
        return cell
    }
}

final class IFLaunchDaemonsViewController: UITableViewController, UISearchResultsUpdating {
    private var records: [IFLaunchDaemonRecord] = []
    private var visibleRecords: [IFLaunchDaemonRecord] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "LaunchDaemons"
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reload)
        )
        reload()
    }

    @objc private func reload() {
        records = IFAdvancedDiagnostics.launchDaemons()
        visibleRecords = records
        tableView.reloadData()
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.lowercased() ?? ""
        visibleRecords = query.isEmpty ? records : records.filter {
            $0.label.lowercased().contains(query)
                || $0.program.lowercased().contains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleRecords.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = visibleRecords[indexPath.row]
        let state = record.isLoaded
            ? "\(IFL("Loaded", "Загружен")) · PID \(record.pid)"
            : IFL("Not running", "Не запущен")
        let path = record.program.isEmpty ? record.path : record.program
        let cell = IFValueCell(
            tableView,
            identifier: "IFDaemon",
            title: record.label,
            detail: "\(state)\n\(path)",
            lines: 3
        )
        cell.imageView?.image = UIImage(systemName: record.isLoaded ? "checkmark.circle.fill" : "circle")
        cell.imageView?.tintColor = record.isLoaded ? .systemGreen : .secondaryLabel
        return cell
    }
}

final class IFIntegrityViewController: UITableViewController {
    private var issues: [IFIntegrityIssue] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Jailbreak integrity", "Целостность jailbreak")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reload)
        )
        reload()
    }

    @objc private func reload() {
        navigationItem.rightBarButtonItem?.isEnabled = false
        DispatchQueue.global(qos: .utility).async {
            let issues = IFAdvancedDiagnostics.integrityIssues()
            DispatchQueue.main.async {
                self.issues = issues
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                self.tableView.reloadData()
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        issues.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let issue = issues[indexPath.row]
        let symbols = ["checkmark.circle.fill", "exclamationmark.triangle.fill", "xmark.octagon.fill"]
        let colors: [UIColor] = [.systemGreen, .systemOrange, .systemRed]
        let severity = min(max(0, issue.severity.rawValue), symbols.count - 1)
        let cell = IFValueCell(
            tableView,
            identifier: "IFIntegrity",
            title: issue.title,
            detail: issue.detail,
            lines: 3
        )
        cell.imageView?.image = UIImage(systemName: symbols[severity])
        cell.imageView?.tintColor = colors[severity]
        return cell
    }
}

final class IFSnapshotsViewController: UITableViewController {
    private var snapshots: [[String: Any]] = []
    private lazy var compareButton = UIBarButtonItem(
        title: IFL("Compare last 2", "Сравнить 2"),
        style: .plain,
        target: self,
        action: #selector(compare)
    )

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("System snapshots", "Снимки системы")
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addSnapshot)
        )
        navigationItem.rightBarButtonItems = [addButton, compareButton]
        reload()
    }

    private func reload() {
        snapshots = IFAdvancedDiagnostics.systemSnapshots()
        compareButton.isEnabled = snapshots.count >= 2
        ifEmptyBackground(
            IFL(
                "Create two snapshots to compare system changes.",
                "Создайте два снимка, чтобы сравнить изменения системы."
            ),
            visible: snapshots.isEmpty
        )
        tableView.reloadData()
    }

    @objc private func addSnapshot() {
        let alert = UIAlertController(
            title: IFL("New snapshot", "Новый снимок"),
            message: IFL(
                "A list of processes, packages, tweaks and daemons will be saved.",
                "Будут сохранены процессы, пакеты, твики и демоны."
            ),
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = IFL("Name", "Название")
        }
        alert.addAction(UIAlertAction(title: IFL("Cancel", "Отмена"), style: .cancel))
        alert.addAction(UIAlertAction(title: IFL("Create", "Создать"), style: .default) { [weak self, weak alert] _ in
            let name = alert?.textFields?.first?.text ?? ""
            DispatchQueue.global(qos: .utility).async {
                do {
                    _ = try IFAdvancedDiagnostics.captureSystemSnapshotNamed(name)
                    DispatchQueue.main.async {
                        self?.reload()
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        IFShowMessage(on: self, message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func compare() {
        guard snapshots.count >= 2 else {
            return
        }
        let newer = snapshots[0]
        let older = snapshots[1]
        let difference = IFAdvancedDiagnostics.compareSnapshot(older, with: newer)
        let sections = [
            ("processes", IFL("Processes", "Процессы")),
            ("packages", IFL("Packages", "Пакеты")),
            ("tweaks", IFL("Tweaks", "Твики")),
            ("daemons", "LaunchDaemons")
        ]
        var text = "\(snapshotTitle(older)) → \(snapshotTitle(newer))\n\n"
        for section in sections {
            let added = difference["\(section.0)Added"] ?? []
            let removed = difference["\(section.0)Removed"] ?? []
            text += "\(section.1)\n"
            text += "+ \(added.isEmpty ? "—" : added.joined(separator: ", "))\n"
            text += "− \(removed.isEmpty ? "—" : removed.joined(separator: ", "))\n\n"
        }
        let controller = UIViewController()
        controller.title = IFL("Changes", "Изменения")
        controller.view.backgroundColor = .systemBackground
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.text = text
        controller.view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
        ])
        navigationController?.pushViewController(controller, animated: true)
    }

    private func snapshotTitle(_ snapshot: [String: Any]) -> String {
        snapshot["name"] as? String
            ?? snapshot["createdAt"] as? String
            ?? IFL("Snapshot", "Снимок")
    }

    private func values(_ snapshot: [String: Any], key: String) -> [Any] {
        snapshot[key] as? [Any] ?? []
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        snapshots.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        IFL(
            "The newest snapshots are shown first. Compare uses the latest two. Swipe left to delete.",
            "Сначала показаны новые снимки. Сравнение использует два последних. Смахните влево для удаления."
        )
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete, snapshots.indices.contains(indexPath.row) else {
            return
        }
        do {
            try IFAdvancedDiagnostics.deleteSystemSnapshot(snapshots[indexPath.row])
            reload()
        } catch {
            IFShowMessage(on: self, message: error.localizedDescription)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let snapshot = snapshots[indexPath.row]
        let created = snapshot["createdAt"] as? String ?? ""
        let detail = [
            created,
            "\(values(snapshot, key: "packages").count) \(IFL("packages", "пакетов"))",
            "\(values(snapshot, key: "processes").count) \(IFL("processes", "процессов"))",
            "\(values(snapshot, key: "tweaks").count) \(IFL("tweaks", "твиков"))",
            "\(values(snapshot, key: "daemons").count) \(IFL("daemons", "демонов"))"
        ]
        let cell = IFValueCell(
            tableView,
            identifier: "IFSnapshot",
            title: snapshotTitle(snapshot),
            detail: "\(detail[0])\n\(detail.dropFirst().joined(separator: " · "))",
            lines: 2
        )
        cell.imageView?.image = UIImage(systemName: "square.stack.3d.up.fill")
        cell.imageView?.tintColor = .systemIndigo
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard snapshots.indices.contains(indexPath.row) else {
            return
        }
        let snapshot = snapshots[indexPath.row]
        let message = [
            "\(IFL("Created", "Создан")): \(snapshot["createdAt"] as? String ?? "—")",
            "\(IFL("Device", "Устройство")): \(snapshot["device"] as? String ?? "—")",
            "iFetch: \(snapshot["version"] as? String ?? "—")",
            "",
            "\(IFL("Processes", "Процессы")): \(values(snapshot, key: "processes").count)",
            "\(IFL("Packages", "Пакеты")): \(values(snapshot, key: "packages").count)",
            "\(IFL("Tweaks", "Твики")): \(values(snapshot, key: "tweaks").count)",
            "\(IFL("Daemons", "Демоны")): \(values(snapshot, key: "daemons").count)"
        ].joined(separator: "\n")
        IFShowMessage(on: self, title: snapshotTitle(snapshot), message: message)
    }
}

final class IFDiagnosticModeViewController: UITableViewController {
    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Diagnostic mode", "Режим диагностики")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1 else {
            return nil
        }
        return IFL(
            "Third-party tweak dylibs are renamed safely. Critical injectors and iFetch are not changed. The original names are saved for one-tap restore.",
            "Dylib сторонних твиков безопасно переименовываются. Хук-инжекторы и iFetch не изменяются. Исходные имена сохраняются для восстановления."
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let enabled = IFAdvancedDiagnostics.diagnosticModeEnabled()
        if indexPath.section == 0 {
            let detail = enabled
                ? "\(IFL("Enabled", "Включён")) · \(IFAdvancedDiagnostics.diagnosticModeDisabledCount()) \(IFL("tweaks disabled", "твиков отключено"))"
                : IFL("Disabled", "Выключен")
            return IFValueCell(
                tableView,
                identifier: "IFDiagnosticState",
                title: IFL("State", "Состояние"),
                detail: detail
            )
        }
        let cell = IFValueCell(
            tableView,
            identifier: "IFDiagnosticAction",
            title: enabled
                ? IFL("Restore tweaks", "Вернуть твики")
                : IFL("Disable third-party tweaks", "Отключить сторонние твики"),
            detail: ""
        )
        cell.textLabel?.textColor = enabled ? .systemBlue : .systemOrange
        cell.textLabel?.textAlignment = .center
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else {
            return
        }
        let enabled = IFAdvancedDiagnostics.diagnosticModeEnabled()
        let alert = UIAlertController(
            title: title,
            message: enabled
                ? IFL(
                    "Restore every tweak changed by iFetch and Respring?",
                    "Вернуть все изменённые iFetch твики и выполнить Respring?"
                )
                : IFL(
                    "Temporarily disable third-party tweaks and Respring? You can restore them from this screen.",
                    "Временно отключить сторонние твики и выполнить Respring? Их можно вернуть на этом экране."
                ),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: IFL("Cancel", "Отмена"), style: .cancel))
        alert.addAction(UIAlertAction(
            title: IFL("Continue", "Продолжить"),
            style: enabled ? .default : .destructive
        ) { [weak self] _ in
            self?.applyDiagnosticMode(wasEnabled: enabled)
        })
        present(alert, animated: true)
    }

    private func applyDiagnosticMode(wasEnabled: Bool) {
        do {
            if wasEnabled {
                try IFAdvancedDiagnostics.restoreDiagnosticMode()
            } else {
                try IFAdvancedDiagnostics.enableDiagnosticMode()
            }
            tableView.reloadData()
            respring()
        } catch {
            IFShowMessage(on: self, message: error.localizedDescription)
        }
    }

    private func respring() {
        IFSystemActions.runCommand("sbreload", arguments: []) { [weak self] exitCode, signalNumber, error in
            guard let self, let error else {
                return
            }
            IFSystemActions.runCommand("killall", arguments: ["SpringBoard"]) { _, _, fallbackError in
                if let fallbackError {
                    IFShowMessage(
                        on: self,
                        message: IFL(
                            "Changes saved. Respring manually to apply them. \(error.localizedDescription) \(fallbackError.localizedDescription)",
                            "Изменения сохранены. Выполните Respring вручную. \(error.localizedDescription) \(fallbackError.localizedDescription)"
                        )
                    )
                }
            }
            _ = exitCode
            _ = signalNumber
        }
    }
}

final class IFPreferencesViewController: UITableViewController {
    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Notifications", "Уведомления")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        IFAdvancedDiagnostics.refreshAlertsAuthorization { [weak self] _ in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        IFL("System alerts", "Системные уведомления")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        IFL(
            "Alerts are generated during active iFetch monitoring for high memory, CPU, temperature and new crashes.",
            "Во время активного мониторинга iFetch сообщает о высокой загрузке ОЗУ, CPU, температуре и новых сбоях."
        )
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = IFValueCell(
            tableView,
            identifier: "IFAlerts",
            title: IFL("Health alerts", "Уведомления о состоянии"),
            detail: ""
        )
        let toggle = UISwitch()
        toggle.isOn = IFAdvancedDiagnostics.alertsEnabled()
        toggle.addTarget(self, action: #selector(alertsChanged), for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    @objc private func alertsChanged(_ toggle: UISwitch) {
        let requested = toggle.isOn
        toggle.isEnabled = false
        IFAdvancedDiagnostics.setAlertsEnabled(requested) { [weak self, weak toggle] granted in
            DispatchQueue.main.async {
                guard let self, let toggle else {
                    return
                }
                toggle.isOn = granted
                toggle.isEnabled = true
                if requested, !granted {
                    self.showNotificationSettingsAlert()
                }
            }
        }
    }

    private func showNotificationSettingsAlert() {
        let alert = UIAlertController(
            title: "iFetch",
            message: IFL(
                "Notifications are disabled for iFetch. Enable them in iOS Settings.",
                "Уведомления для iFetch отключены. Включите их в настройках iOS."
            ),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: IFL("Cancel", "Отмена"), style: .cancel))
        alert.addAction(UIAlertAction(title: IFL("Open Settings", "Открыть настройки"), style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }
}

final class IFAdvancedMenuViewController: UITableViewController {
    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "iFetch 4.0"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let titles = [
            IFL("System snapshots", "Снимки системы"),
            IFL("Injection map", "Карта инъекций"),
            "LaunchDaemons",
            IFL("Diagnostic mode", "Режим диагностики")
        ]
        let details = [
            IFL("Compare processes, packages, tweaks and daemons", "Сравнение процессов, пакетов, твиков и демонов"),
            IFL("Tweak filters grouped by target process", "Фильтры твиков по целевым процессам"),
            IFL("Bootstrap daemon state and executable paths", "Состояние демонов и пути запуска"),
            IFL("Temporarily disable and restore third-party tweaks", "Временное отключение и возврат сторонних твиков")
        ]
        let symbols = [
            "square.stack.3d.up",
            "point.3.connected.trianglepath.dotted",
            "gearshape.2",
            "stethoscope"
        ]
        let cell = IFValueCell(
            tableView,
            identifier: "IFAdvancedMenu",
            title: titles[indexPath.row],
            detail: details[indexPath.row],
            lines: 3
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
            controller = IFSnapshotsViewController()
        case 1:
            controller = IFInjectionMapViewController()
        case 2:
            controller = IFLaunchDaemonsViewController()
        default:
            controller = IFDiagnosticModeViewController()
        }
        navigationController?.pushViewController(controller, animated: true)
    }
}
