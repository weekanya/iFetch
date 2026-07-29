import UIKit

private func IFCCText(_ english: String, _ russian: String) -> String {
    IFLanguageManager.english(english, russian: russian)
}

private final class IFCCMetricView: UIView {
    private let metricIconView: UIImageView
    private let valueLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)

    init(symbol: String, color: UIColor) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        metricIconView = UIImageView(image: UIImage(systemName: symbol, withConfiguration: configuration))
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 0.96)
        layer.cornerRadius = 11
        layer.borderWidth = 0.5
        layer.borderColor = UIColor(white: 1, alpha: 0.10).cgColor

        metricIconView.translatesAutoresizingMaskIntoConstraints = false
        metricIconView.tintColor = color
        metricIconView.contentMode = .scaleAspectFit

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        valueLabel.numberOfLines = 1
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = color
        progressView.trackTintColor = UIColor(white: 1, alpha: 0.14)

        addSubview(metricIconView)
        addSubview(valueLabel)
        addSubview(progressView)

        NSLayoutConstraint.activate([
            metricIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            metricIconView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            metricIconView.widthAnchor.constraint(equalToConstant: 14),
            metricIconView.heightAnchor.constraint(equalToConstant: 14),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            valueLabel.centerYAnchor.constraint(equalTo: metricIconView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: metricIconView.trailingAnchor, constant: 4),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            progressView.topAnchor.constraint(equalTo: metricIconView.bottomAnchor, constant: 5),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setValue(_ value: Double) {
        let normalized = min(100, max(0, value))
        valueLabel.text = String(format: "%.0f%%", normalized)
        progressView.setProgress(Float(normalized / 100), animated: true)
    }
}

@objc(IFetchModuleViewController)
final class IFetchModuleViewController: UIViewController, CCUIContentModuleContentViewController {
    private let gradient = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let temperatureLabel = UILabel()
    private let networkLabel = UILabel()
    private let iconView = UIImageView(image: UIImage(systemName: "waveform.path.ecg.rectangle.fill"))
    private let cpuView = IFCCMetricView(symbol: "cpu", color: .systemOrange)
    private let memoryView = IFCCMetricView(
        symbol: "memorychip",
        color: UIColor(red: 0.70, green: 0.48, blue: 1, alpha: 1)
    )
    private let monitor = IFLiveMetricsMonitor()
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.clipsToBounds = true
        view.layer.cornerRadius = 20
        gradient.colors = [
            UIColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1).cgColor,
            UIColor(red: 0.065, green: 0.085, blue: 0.13, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradient, at: 0)

        let iconBackground = UIView()
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.backgroundColor = UIColor(red: 0.08, green: 0.11, blue: 0.17, alpha: 1)
        iconBackground.layer.cornerRadius = 12

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = UIColor(red: 0.28, green: 0.62, blue: 1, alpha: 1)
        iconBackground.addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "iFetch"
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 8, weight: .medium)
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.64)

        temperatureLabel.translatesAutoresizingMaskIntoConstraints = false
        temperatureLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        temperatureLabel.textColor = .white
        temperatureLabel.textAlignment = .right

        let networkBackground = UIView()
        networkBackground.translatesAutoresizingMaskIntoConstraints = false
        networkBackground.backgroundColor = UIColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 0.96)
        networkBackground.layer.cornerRadius = 10
        networkBackground.layer.borderWidth = 0.5
        networkBackground.layer.borderColor = UIColor(white: 1, alpha: 0.10).cgColor

        let networkIcon = UIImageView(image: UIImage(systemName: "arrow.up.arrow.down"))
        networkIcon.translatesAutoresizingMaskIntoConstraints = false
        networkIcon.tintColor = UIColor(red: 0.28, green: 0.62, blue: 1, alpha: 1)

        networkLabel.translatesAutoresizingMaskIntoConstraints = false
        networkLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
        networkLabel.textColor = .white
        networkLabel.adjustsFontSizeToFitWidth = true
        networkLabel.minimumScaleFactor = 0.7

        networkBackground.addSubview(networkIcon)
        networkBackground.addSubview(networkLabel)
        view.addSubview(iconBackground)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(temperatureLabel)
        view.addSubview(cpuView)
        view.addSubview(memoryView)
        view.addSubview(networkBackground)

        NSLayoutConstraint.activate([
            iconBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            iconBackground.topAnchor.constraint(equalTo: view.topAnchor, constant: 9),
            iconBackground.widthAnchor.constraint(equalToConstant: 24),
            iconBackground.heightAnchor.constraint(equalToConstant: 24),
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 7),
            titleLabel.topAnchor.constraint(equalTo: iconBackground.topAnchor, constant: -1),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: -1),
            temperatureLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            temperatureLabel.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            temperatureLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 5),
            cpuView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 9),
            cpuView.topAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: 7),
            cpuView.heightAnchor.constraint(equalToConstant: 39),
            memoryView.leadingAnchor.constraint(equalTo: cpuView.trailingAnchor, constant: 6),
            memoryView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -9),
            memoryView.topAnchor.constraint(equalTo: cpuView.topAnchor),
            memoryView.widthAnchor.constraint(equalTo: cpuView.widthAnchor),
            memoryView.heightAnchor.constraint(equalTo: cpuView.heightAnchor),
            networkBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 9),
            networkBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -9),
            networkBackground.topAnchor.constraint(equalTo: cpuView.bottomAnchor, constant: 6),
            networkBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -9),
            networkIcon.leadingAnchor.constraint(equalTo: networkBackground.leadingAnchor, constant: 8),
            networkIcon.centerYAnchor.constraint(equalTo: networkBackground.centerYAnchor),
            networkIcon.widthAnchor.constraint(equalToConstant: 13),
            networkIcon.heightAnchor.constraint(equalToConstant: 13),
            networkLabel.leadingAnchor.constraint(equalTo: networkIcon.trailingAnchor, constant: 6),
            networkLabel.trailingAnchor.constraint(equalTo: networkBackground.trailingAnchor, constant: -7),
            networkLabel.centerYAnchor.constraint(equalTo: networkBackground.centerYAnchor)
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openIFetch)))
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
    }

    var preferredExpandedContentHeight: CGFloat {
        190
    }

    var preferredExpandedContentWidth: CGFloat {
        360
    }

    var providesOwnPlatter: Bool {
        true
    }

    @objc func controlCenterWillPresent() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc func controlCenterDidDismiss() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        monitor.refresh()
        guard let sample = monitor.history.last else {
            return
        }

        let battery = IFDiagnostics.batteryDetails()
        cpuView.setValue(sample.cpuPercent)
        memoryView.setValue(sample.memoryPercent)
        subtitleLabel.text = IFCCText("LIVE SYSTEM", "СИСТЕМА")
        if let temperature = battery.temperatureCelsius {
            temperatureLabel.text = String(format: "%.1f°C", temperature.doubleValue)
        } else {
            temperatureLabel.text = "—"
        }
        networkLabel.text = "↓ \(IFetchCore.formatRate(sample.downloadBytesPerSecond))   ↑ \(IFetchCore.formatRate(sample.uploadBytesPerSecond))"
    }

    @objc private func openIFetch() {
        IFCCOpenApplication("com.wee1ka.ifetch")
    }

    deinit {
        timer?.invalidate()
    }
}

@objc(IFetchModule)
final class IFetchModule: NSObject, CCUIContentModule {
    private let controller = IFetchModuleViewController()

    var contentViewController: (UIViewController & CCUIContentModuleContentViewController) {
        controller
    }

    var backgroundViewController: UIViewController? {
        nil
    }
}
