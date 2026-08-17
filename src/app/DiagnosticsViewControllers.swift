import AVFoundation
import CoreLocation
import Darwin
import UIKit

enum IFSpeakerChannel: Int {
    case top = 0
    case bottom = 1
    case both = 2

    var title: String {
        switch self {
        case .top:
            return IFL("Top speaker (Earpiece)", "Верхний динамик (Разговорный)")
        case .bottom:
            return IFL("Bottom speaker (Main)", "Нижний динамик (Основной)")
        case .both:
            return IFL("Both speakers (Stereo)", "Оба динамика (Стерео)")
        }
    }

    var shortTitle: String {
        switch self {
        case .top:
            return IFL("Top", "Верхний")
        case .bottom:
            return IFL("Bottom", "Нижний")
        case .both:
            return IFL("Both", "Оба")
        }
    }

    var subtitle: String {
        switch self {
        case .top:
            return IFL("Testing top earpiece receiver only", "Проверка только верхнего разговорного динамика")
        case .bottom:
            return IFL("Testing bottom main acoustic speaker only", "Проверка только нижнего основного динамика")
        case .both:
            return IFL("Testing full stereo output across both speakers", "Проверка стереобаланса и обоих динамиков")
        }
    }
}

enum IFSpeakerFrequency: Int {
    case bass250 = 0
    case speech440 = 1
    case standard1000 = 2
    case treble4000 = 3
    case sweep = 4

    var title: String {
        switch self {
        case .bass250: return "250 Hz"
        case .speech440: return "440 Hz"
        case .standard1000: return "1 kHz"
        case .treble4000: return "4 kHz"
        case .sweep: return IFL("Sweep", "Свип")
        }
    }

    var detail: String {
        switch self {
        case .bass250:
            return IFL("Bass tone · Checks membrane rattle and low frequencies", "Бас 250 Гц · Проверка дребезга мембраны и низких частот")
        case .speech440:
            return IFL("Mid tone · A4 musical reference and speech band", "Средние 440 Гц · Эталонная нота Ля и речевой диапазон")
        case .standard1000:
            return IFL("Standard 1 kHz tone · Calibration test frequency", "Стандарт 1 кГц · Калибровочный измерительный тон")
        case .treble4000:
            return IFL("High treble 4 kHz · Checks high-frequency clarity", "Высокие 4 кГц · Проверка четкости высоких частот")
        case .sweep:
            return IFL("Frequency sweep · Continuous glide from 200 Hz to 8 kHz", "Частотный свип · Плавное нарастание от 200 Гц до 8 кГц")
        }
    }
}

final class IFSpeakerTester: NSObject {
    private var player: AVAudioPlayer?
    private(set) var isPlaying = false
    private(set) var currentChannel: IFSpeakerChannel = .top
    private(set) var currentFrequency: IFSpeakerFrequency = .standard1000

    func play(channel: IFSpeakerChannel, frequency: IFSpeakerFrequency) {
        stop()
        currentChannel = channel
        currentFrequency = frequency

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let wavData = generateStereoWav(channel: channel, frequency: frequency)
            player = try AVAudioPlayer(data: wavData)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            print("IFSpeakerTester error: \(error)")
            isPlaying = false
        }
    }

    func stop() {
        if let p = player {
            p.stop()
            player = nil
        }
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func generateStereoWav(channel: IFSpeakerChannel, frequency: IFSpeakerFrequency) -> Data {
        let sampleRate: Double = 44100.0
        let isSweep = frequency == .sweep
        let duration: Double = isSweep ? 2.5 : 1.0
        let totalSamples = Int(sampleRate * duration)
        let bytesPerSample = 2
        let channels: UInt16 = 2
        let dataSize = totalSamples * Int(channels) * bytesPerSample
        let fileSize = 36 + dataSize

        var data = Data(capacity: 44 + dataSize)

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        var chunkSize = UInt32(fileSize).littleEndian
        data.append(Data(bytes: &chunkSize, count: 4))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])

        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        var subchunk1Size = UInt32(16).littleEndian
        data.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat = UInt16(1).littleEndian
        data.append(Data(bytes: &audioFormat, count: 2))
        var numChannels = channels.littleEndian
        data.append(Data(bytes: &numChannels, count: 2))
        var sRate = UInt32(sampleRate).littleEndian
        data.append(Data(bytes: &sRate, count: 4))
        var byteRate = UInt32(sampleRate * Double(channels) * Double(bytesPerSample)).littleEndian
        data.append(Data(bytes: &byteRate, count: 4))
        var blockAlign = UInt16(channels * UInt16(bytesPerSample)).littleEndian
        data.append(Data(bytes: &blockAlign, count: 2))
        var bitsPerSample = UInt16(16).littleEndian
        data.append(Data(bytes: &bitsPerSample, count: 2))

        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        var s2Size = UInt32(dataSize).littleEndian
        data.append(Data(bytes: &s2Size, count: 4))

        let freqValue: Double
        switch frequency {
        case .bass250: freqValue = 250.0
        case .speech440: freqValue = 440.0
        case .standard1000: freqValue = 1000.0
        case .treble4000: freqValue = 4000.0
        case .sweep: freqValue = 200.0
        }

        let fadeLength = 441
        let maxAmp: Double = 22000.0

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let wave: Double
            if isSweep {
                let f0: Double = 200.0
                let f1: Double = 8000.0
                let phase = 2.0 * .pi * (f0 * t + ((f1 - f0) / (2.0 * duration)) * t * t)
                wave = sin(phase)
            } else {
                wave = sin(2.0 * .pi * freqValue * t)
            }

            var env: Double = 1.0
            if i < fadeLength {
                env = Double(i) / Double(fadeLength)
            } else if i > totalSamples - fadeLength {
                env = Double(totalSamples - i) / Double(fadeLength)
            }

            let sampleVal = Int16(clamping: Int(wave * env * maxAmp))

            var leftVal: Int16 = 0
            var rightVal: Int16 = 0

            switch channel {
            case .top:
                leftVal = sampleVal
                rightVal = 0
            case .bottom:
                leftVal = 0
                rightVal = sampleVal
            case .both:
                leftVal = sampleVal
                rightVal = sampleVal
            }

            var leftLE = leftVal.littleEndian
            var rightLE = rightVal.littleEndian
            data.append(Data(bytes: &leftLE, count: 2))
            data.append(Data(bytes: &rightLE, count: 2))
        }

        return data
    }
}

final class IFSpeakerDiagnosticsViewController: UIViewController {
    private let tester = IFSpeakerTester()
    private var visualTimer: Timer?
    private var animTick: Int = 0

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let phoneFrameView = UIView()
    private let topSpeakerBar = UIView()
    private let topSpeakerIcon = UIImageView()
    private let topSpeakerLabel = UILabel()

    private let bottomSpeakerBar = UIView()
    private let bottomSpeakerIcon = UIImageView()
    private let bottomSpeakerLabel = UILabel()

    private let visualizerStack = UIStackView()
    private var visualizerBars: [UIView] = []
    private var visualizerBarConstraints: [NSLayoutConstraint] = []

    private let channelSegment = UISegmentedControl(items: [
        IFL("Top", "Верхний"),
        IFL("Bottom", "Нижний"),
        IFL("Both", "Оба")
    ])
    private let channelInfoLabel = UILabel()

    private let frequencySegment = UISegmentedControl(items: [
        "250 Hz", "440 Hz", "1 kHz", "4 kHz", IFL("Sweep", "Свип")
    ])
    private let frequencyInfoLabel = UILabel()

    private let playButton = UIButton(type: .system)
    private let tipsCard = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Speaker diagnostics", "Диагностика динамиков")
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        updateVisualState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTest()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 28, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

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

        setupPhoneVisualCard()
        setupChannelControls()
        setupFrequencyControls()
        setupPlayButton()
        setupTipsCard()
    }

    private func setupPhoneVisualCard() {
        phoneFrameView.translatesAutoresizingMaskIntoConstraints = false
        phoneFrameView.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.12, alpha: 0.96)
        phoneFrameView.layer.cornerRadius = 24
        phoneFrameView.layer.borderWidth = 1
        phoneFrameView.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
        phoneFrameView.heightAnchor.constraint(equalToConstant: 220).isActive = true

        let topContainer = UIView()
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        topSpeakerBar.translatesAutoresizingMaskIntoConstraints = false
        topSpeakerBar.layer.cornerRadius = 3.5
        topSpeakerBar.backgroundColor = .systemOrange

        topSpeakerIcon.translatesAutoresizingMaskIntoConstraints = false
        topSpeakerIcon.image = UIImage(systemName: "speaker.wave.2.fill")
        topSpeakerIcon.tintColor = .systemOrange
        topSpeakerIcon.contentMode = .scaleAspectFit

        topSpeakerLabel.translatesAutoresizingMaskIntoConstraints = false
        topSpeakerLabel.font = .systemFont(ofSize: 13, weight: .bold)
        topSpeakerLabel.textColor = .white
        topSpeakerLabel.text = IFL("TOP / EARPIECE SPEAKER", "ВЕРХНИЙ ДИНАМИК")

        topContainer.addSubview(topSpeakerBar)
        topContainer.addSubview(topSpeakerIcon)
        topContainer.addSubview(topSpeakerLabel)

        visualizerStack.translatesAutoresizingMaskIntoConstraints = false
        visualizerStack.axis = .horizontal
        visualizerStack.distribution = .fillEqually
        visualizerStack.alignment = .center
        visualizerStack.spacing = 5

        for _ in 0..<12 {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.layer.cornerRadius = 2.5
            bar.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.35)
            let heightC = bar.heightAnchor.constraint(equalToConstant: 6)
            heightC.isActive = true
            visualizerBars.append(bar)
            visualizerBarConstraints.append(heightC)
            visualizerStack.addArrangedSubview(bar)
        }

        let bottomContainer = UIView()
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpeakerBar.translatesAutoresizingMaskIntoConstraints = false
        bottomSpeakerBar.layer.cornerRadius = 3.5
        bottomSpeakerBar.backgroundColor = .systemPurple

        bottomSpeakerIcon.translatesAutoresizingMaskIntoConstraints = false
        bottomSpeakerIcon.image = UIImage(systemName: "speaker.wave.3.fill")
        bottomSpeakerIcon.tintColor = .systemPurple
        bottomSpeakerIcon.contentMode = .scaleAspectFit

        bottomSpeakerLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomSpeakerLabel.font = .systemFont(ofSize: 13, weight: .bold)
        bottomSpeakerLabel.textColor = .white
        bottomSpeakerLabel.text = IFL("BOTTOM SPEAKER", "НИЖНИЙ ДИНАМИК")

        bottomContainer.addSubview(bottomSpeakerBar)
        bottomContainer.addSubview(bottomSpeakerIcon)
        bottomContainer.addSubview(bottomSpeakerLabel)

        phoneFrameView.addSubview(topContainer)
        phoneFrameView.addSubview(visualizerStack)
        phoneFrameView.addSubview(bottomContainer)

        NSLayoutConstraint.activate([
            topContainer.topAnchor.constraint(equalTo: phoneFrameView.topAnchor, constant: 16),
            topContainer.centerXAnchor.constraint(equalTo: phoneFrameView.centerXAnchor),
            topSpeakerBar.topAnchor.constraint(equalTo: topContainer.topAnchor),
            topSpeakerBar.centerXAnchor.constraint(equalTo: topContainer.centerXAnchor),
            topSpeakerBar.widthAnchor.constraint(equalToConstant: 54),
            topSpeakerBar.heightAnchor.constraint(equalToConstant: 6),
            topSpeakerIcon.topAnchor.constraint(equalTo: topSpeakerBar.bottomAnchor, constant: 6),
            topSpeakerIcon.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
            topSpeakerIcon.widthAnchor.constraint(equalToConstant: 16),
            topSpeakerIcon.heightAnchor.constraint(equalToConstant: 16),
            topSpeakerLabel.centerYAnchor.constraint(equalTo: topSpeakerIcon.centerYAnchor),
            topSpeakerLabel.leadingAnchor.constraint(equalTo: topSpeakerIcon.trailingAnchor, constant: 6),
            topSpeakerLabel.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
            topContainer.bottomAnchor.constraint(equalTo: topSpeakerIcon.bottomAnchor),

            visualizerStack.centerYAnchor.constraint(equalTo: phoneFrameView.centerYAnchor),
            visualizerStack.centerXAnchor.constraint(equalTo: phoneFrameView.centerXAnchor),
            visualizerStack.widthAnchor.constraint(equalToConstant: 180),
            visualizerStack.heightAnchor.constraint(equalToConstant: 50),

            bottomContainer.bottomAnchor.constraint(equalTo: phoneFrameView.bottomAnchor, constant: -16),
            bottomContainer.centerXAnchor.constraint(equalTo: phoneFrameView.centerXAnchor),
            bottomSpeakerIcon.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor),
            bottomSpeakerIcon.topAnchor.constraint(equalTo: bottomContainer.topAnchor),
            bottomSpeakerIcon.widthAnchor.constraint(equalToConstant: 16),
            bottomSpeakerIcon.heightAnchor.constraint(equalToConstant: 16),
            bottomSpeakerLabel.centerYAnchor.constraint(equalTo: bottomSpeakerIcon.centerYAnchor),
            bottomSpeakerLabel.leadingAnchor.constraint(equalTo: bottomSpeakerIcon.trailingAnchor, constant: 6),
            bottomSpeakerLabel.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            bottomSpeakerBar.topAnchor.constraint(equalTo: bottomSpeakerIcon.bottomAnchor, constant: 6),
            bottomSpeakerBar.centerXAnchor.constraint(equalTo: bottomContainer.centerXAnchor),
            bottomSpeakerBar.widthAnchor.constraint(equalToConstant: 68),
            bottomSpeakerBar.heightAnchor.constraint(equalToConstant: 6),
            bottomSpeakerBar.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor)
        ])

        stackView.addArrangedSubview(phoneFrameView)
    }

    private func setupChannelControls() {
        let titleLabel = UILabel()
        titleLabel.text = IFL("Select speaker channel", "Выбор динамика")
        titleLabel.font = .preferredFont(forTextStyle: .headline)

        channelSegment.selectedSegmentIndex = 0
        channelSegment.addTarget(self, action: #selector(channelChanged), for: .valueChanged)

        channelInfoLabel.font = .systemFont(ofSize: 13, weight: .regular)
        channelInfoLabel.textColor = .secondaryLabel
        channelInfoLabel.numberOfLines = 0

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(channelSegment)
        stackView.addArrangedSubview(channelInfoLabel)
    }

    private func setupFrequencyControls() {
        let titleLabel = UILabel()
        titleLabel.text = IFL("Signal frequency", "Тестовая частота")
        titleLabel.font = .preferredFont(forTextStyle: .headline)

        frequencySegment.selectedSegmentIndex = 2
        frequencySegment.addTarget(self, action: #selector(frequencyChanged), for: .valueChanged)

        frequencyInfoLabel.font = .systemFont(ofSize: 13, weight: .regular)
        frequencyInfoLabel.textColor = .secondaryLabel
        frequencyInfoLabel.numberOfLines = 0

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(frequencySegment)
        stackView.addArrangedSubview(frequencyInfoLabel)
    }

    private func setupPlayButton() {
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        playButton.layer.cornerRadius = 16
        playButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        playButton.tintColor = .white
        playButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        stackView.addArrangedSubview(playButton)
    }

    private func setupTipsCard() {
        tipsCard.translatesAutoresizingMaskIntoConstraints = false
        tipsCard.backgroundColor = .secondarySystemGroupedBackground
        tipsCard.layer.cornerRadius = 14

        let tipStack = UIStackView()
        tipStack.translatesAutoresizingMaskIntoConstraints = false
        tipStack.axis = .vertical
        tipStack.spacing = 10
        tipStack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        tipStack.isLayoutMarginsRelativeArrangement = true

        let header = UILabel()
        header.text = IFL("Diagnostic checklist", "Чеклист проверки")
        header.font = .systemFont(ofSize: 15, weight: .semibold)
        tipStack.addArrangedSubview(header)

        let tips = [
            IFL("Top speaker: clean sound without rattling or muted volume.", "Верхний динамик: чистый звук без хрипа и приглушения."),
            IFL("Bottom speaker: full, rich and loud acoustic response.", "Нижний динамик: глубокий и громкий звук."),
            IFL("Both speakers: balanced stereo field with centered soundstage.", "Оба динамика: сбалансированное стерео без перекоса громкости."),
            IFL("Frequency sweep: continuous tone without silent dropouts.", "Частотный свип: непрерывное воспроизведение без провалов.")
        ]

        for tip in tips {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .top

            let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            icon.tintColor = .systemGreen
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

            let lbl = UILabel()
            lbl.font = .systemFont(ofSize: 13, weight: .regular)
            lbl.textColor = .secondaryLabel
            lbl.numberOfLines = 0
            lbl.text = tip

            row.addArrangedSubview(icon)
            row.addArrangedSubview(lbl)
            tipStack.addArrangedSubview(row)
        }

        tipsCard.addSubview(tipStack)
        NSLayoutConstraint.activate([
            tipStack.leadingAnchor.constraint(equalTo: tipsCard.leadingAnchor),
            tipStack.trailingAnchor.constraint(equalTo: tipsCard.trailingAnchor),
            tipStack.topAnchor.constraint(equalTo: tipsCard.topAnchor),
            tipStack.bottomAnchor.constraint(equalTo: tipsCard.bottomAnchor)
        ])

        stackView.addArrangedSubview(tipsCard)
    }

    @objc private func channelChanged() {
        updateVisualState()
        if tester.isPlaying {
            restartTest()
        }
    }

    @objc private func frequencyChanged() {
        updateVisualState()
        if tester.isPlaying {
            restartTest()
        }
    }

    @objc private func togglePlayback() {
        if tester.isPlaying {
            stopTest()
        } else {
            startTest()
        }
    }

    private func currentChannel() -> IFSpeakerChannel {
        IFSpeakerChannel(rawValue: channelSegment.selectedSegmentIndex) ?? .top
    }

    private func currentFrequency() -> IFSpeakerFrequency {
        IFSpeakerFrequency(rawValue: frequencySegment.selectedSegmentIndex) ?? .standard1000
    }

    private func startTest() {
        let channel = currentChannel()
        let frequency = currentFrequency()
        tester.play(channel: channel, frequency: frequency)
        updateVisualState()
        startAnimation()
    }

    private func stopTest() {
        tester.stop()
        stopAnimation()
        updateVisualState()
    }

    private func restartTest() {
        let channel = currentChannel()
        let frequency = currentFrequency()
        tester.play(channel: channel, frequency: frequency)
        updateVisualState()
    }

    private func startAnimation() {
        visualTimer?.invalidate()
        visualTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.animateVisualizer()
        }
    }

    private func stopAnimation() {
        visualTimer?.invalidate()
        visualTimer = nil
        for (index, constraint) in visualizerBarConstraints.enumerated() {
            constraint.constant = 6
            visualizerBars[index].backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
        }
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }

    private func animateVisualizer() {
        animTick += 1
        let channel = currentChannel()
        let activeColor: UIColor = channel == .top ? .systemOrange : (channel == .bottom ? .systemPurple : .systemBlue)
        let heights: [CGFloat] = [12, 28, 44, 32, 48, 20, 42, 36, 50, 26, 38, 16]
        for (index, constraint) in visualizerBarConstraints.enumerated() {
            let offset = (index + animTick) % heights.count
            constraint.constant = heights[offset]
            visualizerBars[index].backgroundColor = activeColor.withAlphaComponent(0.85)
        }
        UIView.animate(withDuration: 0.08) {
            self.view.layoutIfNeeded()
        }
    }

    private func updateVisualState() {
        let channel = currentChannel()
        let frequency = currentFrequency()

        channelInfoLabel.text = channel.subtitle
        frequencyInfoLabel.text = frequency.detail

        let topActive = channel == .top || channel == .both
        let bottomActive = channel == .bottom || channel == .both

        topSpeakerBar.backgroundColor = topActive ? .systemOrange : UIColor(white: 1, alpha: 0.2)
        topSpeakerIcon.tintColor = topActive ? .systemOrange : UIColor(white: 1, alpha: 0.3)
        topSpeakerLabel.textColor = topActive ? .white : UIColor(white: 1, alpha: 0.4)

        bottomSpeakerBar.backgroundColor = bottomActive ? .systemPurple : UIColor(white: 1, alpha: 0.2)
        bottomSpeakerIcon.tintColor = bottomActive ? .systemPurple : UIColor(white: 1, alpha: 0.3)
        bottomSpeakerLabel.textColor = bottomActive ? .white : UIColor(white: 1, alpha: 0.4)

        if tester.isPlaying {
            playButton.backgroundColor = .systemRed
            playButton.setTitle(IFL("Stop test tone", "Остановить воспроизведение"), for: .normal)
            playButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        } else {
            playButton.backgroundColor = .systemBlue
            let channelName = channel.shortTitle
            playButton.setTitle(
                String(format: IFL("Play on %@ (%@)", "Тест: %@ (%@)"), channelName, frequency.title),
                for: .normal
            )
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
}

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

final class IFBatteryViewController: IFStyledTableViewController {
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
        10
    }

    private func value(_ number: NSNumber?, suffix: String) -> String {
        guard let number else {
            return IFL("Unavailable", "Недоступно")
        }
        return String(format: "%.1f%@", number.doubleValue, suffix)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let rows: [(String, String, String, UIColor)] = [
            (
                IFL("Health", "Здоровье"),
                battery.healthPercent > 0
                    ? IFDisplayFormatter.roundedPercent(battery.healthPercent)
                    : IFL("Unavailable", "Недоступно"),
                "heart.fill",
                .systemRed
            ),
            (
                IFL("Thermal state", "Термальное состояние"),
                "\(IFetchCore.thermalStateDescription()) · \(IFetchCore.isThermalThrottling() ? IFL("Throttling", "Троттлинг") : IFL("Optimal", "Оптимально"))",
                "thermometer.sun.fill",
                IFetchCore.isThermalThrottling() ? .systemRed : .systemOrange
            ),
            (
                IFL("Current capacity", "Текущая ёмкость"),
                value(battery.currentCapacity, suffix: " mAh"),
                "battery.75",
                .systemGreen
            ),
            (
                IFL("Maximum capacity", "Максимальная ёмкость"),
                value(battery.maximumCapacity, suffix: " mAh"),
                "battery.100",
                .systemGreen
            ),
            (
                IFL("Design capacity", "Проектная ёмкость"),
                value(battery.designCapacity, suffix: " mAh"),
                "ruler.fill",
                .systemBlue
            ),
            (
                IFL("Cycles", "Циклы"),
                battery.cycleCount?.stringValue ?? IFL("Unavailable", "Недоступно"),
                "arrow.triangle.2.circlepath",
                .systemIndigo
            ),
            (
                IFL("Temperature", "Температура"),
                value(battery.temperatureCelsius, suffix: " °C"),
                "thermometer",
                .systemOrange
            ),
            (
                IFL("Voltage", "Напряжение"),
                value(battery.voltageMillivolts, suffix: " mV"),
                "bolt.fill",
                .systemYellow
            ),
            (
                IFL("Current", "Ток"),
                value(battery.amperageMilliamps, suffix: " mA"),
                "waveform.path.ecg",
                .systemTeal
            ),
            (
                IFL("Charging power", "Мощность зарядки"),
                battery.externalConnected
                    ? String(format: "%.1f W%@", battery.chargingWatts, battery.chargingWatts >= 15 ? " · Fast" : "")
                    : IFL("Not connected", "Не подключена"),
                "bolt.circle.fill",
                .systemYellow
            )
        ]
        let row = rows[indexPath.row]
        let cell = IFValueCell(tableView, identifier: "IFBatteryValue", title: row.0, detail: row.1)
        cell.imageView?.image = IFAppStyle.symbol(row.2, color: row.3)
            ?? IFAppStyle.symbol("circle.fill", color: row.3)
        return cell
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
        let limitStr = process.jetsamLimitBytes > 0
            ? "\(IFDisplayFormatter.bytes(process.jetsamLimitBytes)) (\(String(format: "%.1f%%", process.jetsamUsagePercent)))"
            : IFL("Default / Unlimited", "По умолчанию / Без лимита")
        let jetsamRisk: String
        if process.jetsamLimitBytes > 0 {
            if process.jetsamUsagePercent >= 90 {
                jetsamRisk = IFL("⚠️ Critical (Imminent kill risk)", "⚠️ Критический (Риск выгрузки)")
            } else if process.jetsamUsagePercent >= 75 {
                jetsamRisk = IFL("⚠️ Elevated pressure", "⚠️ Повышенная нагрузка")
            } else {
                jetsamRisk = IFL("✅ Normal", "✅ В норме")
            }
        } else {
            jetsamRisk = IFL("✅ Normal", "✅ В норме")
        }
        detailsLabel.text = [
            "PID: \(process.pid)",
            "CPU: \(IFDisplayFormatter.percent(process.cpuPercent))",
            "RAM: \(IFDisplayFormatter.bytes(process.residentBytes))",
            "\(IFL("Threads", "Потоки")): \(process.threadCount)",
            "\(IFL("Running", "Работает")): \(hours)h \(minutes)m",
            "",
            "\(IFL("Jetsam band", "Полоса Jetsam")): \(process.jetsamPriority) (\(process.jetsamBandName))",
            "\(IFL("Jetsam limit", "Лимит памяти")): \(limitStr)",
            "\(IFL("Jetsam status", "Статус Jetsam")): \(jetsamRisk)",
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

final class IFProcessesViewController: IFStyledTableViewController {
    private let monitor = IFLiveMetricsMonitor()
    private let mode = UISegmentedControl(items: ["CPU", "RAM", "Jetsam"])
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
        if mode.selectedSegmentIndex == 0 {
            samples = monitor.processes.topProcesses(byCPU: 50)
        } else if mode.selectedSegmentIndex == 1 {
            samples = monitor.processes.topProcesses(byMemory: 50)
        } else {
            samples = monitor.processes.topProcesses(byJetsamPressure: 50)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        samples.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let process = samples[indexPath.row]
        let jetsamText = process.jetsamLimitBytes > 0
            ? " · \(process.jetsamBandName) (\(String(format: "%.0f%%", process.jetsamUsagePercent)))"
            : " · \(process.jetsamBandName)"
        let cell = IFValueCell(
            tableView,
            identifier: "IFProcess",
            title: process.name,
            detail: "PID \(process.pid) · \(IFDisplayFormatter.percent(process.cpuPercent)) · \(IFDisplayFormatter.bytes(process.residentBytes))\(jetsamText)"
        )
        let highlighted = monitor.sustainedHighCPUProcesses().contains(where: { $0.pid == process.pid })
        let color: UIColor = highlighted
            ? .systemRed
            : (mode.selectedSegmentIndex == 0 ? .systemOrange : (mode.selectedSegmentIndex == 1 ? .systemPurple : .systemIndigo))
        let symbol = mode.selectedSegmentIndex == 0 ? "cpu" : (mode.selectedSegmentIndex == 1 ? "memorychip" : "gauge.with.dots.needle.bottom.50percent")
        cell.imageView?.image = IFAppStyle.symbol(symbol, color: color)
            ?? IFAppStyle.symbol("gearshape.fill", color: color)
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        if highlighted {
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
        let analysis = IFAdvancedDiagnostics.analysis(for: log)
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

final class IFCrashLogsViewController: IFStyledTableViewController {
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
        cell.imageView?.image = IFAppStyle.symbol("exclamationmark.triangle.fill", color: .systemRed)
            ?? IFAppStyle.symbol("doc.text.fill", color: .systemRed)
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(IFCrashDetailViewController(log: logs[indexPath.row]), animated: true)
    }
}

final class IFTweaksViewController: IFStyledTableViewController, UISearchResultsUpdating {
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
        let color: UIColor = tweak.isEnabled ? .systemPink : .secondaryLabel
        cell.imageView?.image = IFAppStyle.symbol("puzzlepiece.extension.fill", color: color)
            ?? IFAppStyle.symbol("shippingbox.fill", color: color)
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

final class IFHealthViewController: IFStyledTableViewController {
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

final class IFNetworkDetailsViewController: IFStyledTableViewController, CLLocationManagerDelegate {
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
            return 8
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
            let rows: [(String, String, String, UIColor)] = [
                ("IPv4", string("ipv4"), "4.circle.fill", .systemBlue),
                ("IPv6", string("ipv6"), "6.circle.fill", .systemIndigo),
                (
                    "Wi-Fi SSID",
                    string("ssid").isEmpty ? wifiUnavailable : string("ssid"),
                    "wifi",
                    .systemBlue
                ),
                (
                    "BSSID",
                    string("bssid").isEmpty ? wifiUnavailable : string("bssid"),
                    "dot.radiowaves.left.and.right",
                    .systemTeal
                ),
                (
                    IFL("Cellular", "Сотовая сеть"),
                    string("radio").isEmpty
                        ? IFL("No active cellular service", "Нет активной сотовой сети")
                        : string("radio"),
                    "antenna.radiowaves.left.and.right",
                    .systemGreen
                ),
                (
                    IFL("DNS latency", "Задержка DNS"),
                    latency >= 0 ? IFDisplayFormatter.latency(latency) : IFL("Unavailable", "Недоступно"),
                    "server.rack",
                    .systemPurple
                ),
                (IFL("Internet", "Интернет"), internetValue, "globe", .systemTeal),
                (
                    IFL("HTTPS latency", "Задержка HTTPS"),
                    httpsLatency >= 0
                        ? IFDisplayFormatter.latency(httpsLatency)
                        : IFL("Unavailable", "Недоступно"),
                    "lock.fill",
                    .systemGreen
                )
            ]
            let row = rows[indexPath.row]
            let cell = IFValueCell(tableView, identifier: "IFNetworkValue", title: row.0, detail: row.1)
            cell.imageView?.image = IFAppStyle.symbol(row.2, color: row.3)
                ?? IFAppStyle.symbol("network", color: row.3)
            return cell
        }

        let interfaces = details["interfaces"] as? [String: [String: NSNumber]] ?? [:]
        let names = interfaces.keys.sorted()
        let name = names[indexPath.row]
        let traffic = interfaces[name] ?? [:]
        let cell = IFValueCell(
            tableView,
            identifier: "IFNetworkTraffic",
            title: name,
            detail: "↓ \(IFDisplayFormatter.bytes(traffic["received"]?.uint64Value ?? 0))  ↑ \(IFDisplayFormatter.bytes(traffic["sent"]?.uint64Value ?? 0))"
        )
        cell.imageView?.image = IFAppStyle.symbol("arrow.up.arrow.down.circle.fill", color: .systemTeal)
            ?? IFAppStyle.symbol("network", color: .systemTeal)
        return cell
    }
}

@objc(IFDiagnosticsViewController)
final class IFDiagnosticsViewController: IFStyledTableViewController {
    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = IFL("Diagnostics", "Диагностика")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportReport)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = IFL("Export report", "Экспорт отчёта")
    }

    @objc private func exportReport() {
        let report = IFDiagnostics.generateDiagnosticReportMarkdown()
        let activityVC = UIActivityViewController(activityItems: [report], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityVC, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        9
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let titles = [
            IFL("Live charts", "Графики в реальном времени"),
            IFL("Battery diagnostics", "Диагностика батареи"),
            IFL("Speaker diagnostics", "Диагностика динамиков"),
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
            IFL("Test top, bottom and stereo speakers independently", "Проверка верхнего, нижнего и стерео-динамиков раздельно"),
            IFL("Top-50, path, PID and sustained load alerts", "Top-50, путь, PID и длительная нагрузка"),
            IFL("View, copy and share diagnostic reports", "Просмотр и отправка диагностических отчётов"),
            IFL("Packages, dylibs and injection filters", "Пакеты, dylib и фильтры инъекции"),
            IFL("Rootless bootstrap and system status", "Состояние bootstrap и системы"),
            IFL("IPv4/IPv6, Wi-Fi, cellular and traffic", "IPv4/IPv6, Wi-Fi, сотовая сеть и трафик"),
            IFL("Snapshots, injection, daemons and diagnostic mode", "Снимки, инъекции, демоны и режим диагностики")
        ]
        let symbols = [
            "chart.xyaxis.line", "battery.100", "speaker.wave.3.fill", "cpu",
            "doc.text.magnifyingglass", "puzzlepiece.extension", "heart.text.square",
            "network", "gearshape.2.fill"
        ]
        let colors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange, .systemPurple,
            .systemIndigo, .systemPink, .systemRed, .systemTeal, .systemGray
        ]
        let cell = IFValueCell(
            tableView,
            identifier: "IFDiagnosticsMenu",
            title: titles[indexPath.row],
            detail: details[indexPath.row]
        )
        cell.imageView?.image = IFAppStyle.symbol(symbols[indexPath.row], color: colors[indexPath.row])
            ?? IFAppStyle.symbol("circle.fill", color: colors[indexPath.row])
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
            controller = IFSpeakerDiagnosticsViewController()
        case 3:
            controller = IFProcessesViewController()
        case 4:
            controller = IFCrashLogsViewController()
        case 5:
            controller = IFTweaksViewController()
        case 6:
            controller = IFHealthViewController()
        case 7:
            controller = IFNetworkDetailsViewController()
        default:
            controller = IFAdvancedMenuViewController()
        }
        navigationController?.pushViewController(controller, animated: true)
    }
}
