import UIKit

func IFL(_ english: String, _ russian: String) -> String {
    IFLanguageManager.english(english, russian: russian)
}

enum IFAppStyle {
    static let accent = UIColor(red: 0.12, green: 0.47, blue: 0.98, alpha: 1)
    static let cardBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.105, green: 0.11, blue: 0.135, alpha: 1)
            : UIColor.secondarySystemGroupedBackground
    }

    static func configureGlobalAppearance() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithDefaultBackground()
        navigation.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        navigation.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.82)
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigation.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigation
        navigationBar.scrollEdgeAppearance = navigation
        navigationBar.compactAppearance = navigation
        navigationBar.tintColor = accent

        UIBarButtonItem.appearance().tintColor = accent
        UISearchBar.appearance().tintColor = accent
        UISwitch.appearance().onTintColor = accent
    }

    static func symbol(
        _ name: String,
        color: UIColor,
        pointSize: CGFloat = 16,
        weight: UIImage.SymbolWeight = .semibold
    ) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    static func configure(_ controller: UITableViewController) {
        controller.navigationController?.navigationBar.prefersLargeTitles = true
        controller.navigationItem.largeTitleDisplayMode = .automatic
        controller.tableView.backgroundColor = .systemGroupedBackground
        controller.tableView.separatorColor = UIColor.separator.withAlphaComponent(0.48)
        controller.tableView.separatorInset = UIEdgeInsets(top: 0, left: 58, bottom: 0, right: 18)
        controller.tableView.estimatedRowHeight = 58
        controller.tableView.rowHeight = UITableView.automaticDimension
        controller.tableView.keyboardDismissMode = .onDrag
        if #available(iOS 15.0, *) {
            controller.tableView.sectionHeaderTopPadding = 12
        }
    }

    static func configure(_ cell: UITableViewCell) {
        cell.backgroundColor = cardBackground
        cell.tintColor = accent
        cell.textLabel?.textColor = .label
        cell.detailTextLabel?.textColor = .secondaryLabel
        let selection = UIView()
        selection.backgroundColor = accent.withAlphaComponent(0.12)
        cell.selectedBackgroundView = selection
    }
}

class IFStyledTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        IFAppStyle.configure(self)
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        IFAppStyle.configure(cell)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else {
            return
        }
        header.textLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        header.textLabel?.textColor = .secondaryLabel
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else {
            return
        }
        footer.textLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        footer.textLabel?.textColor = .tertiaryLabel
    }
}

func IFValueCell(
    _ tableView: UITableView,
    identifier: String,
    title: String,
    detail: String,
    lines: Int = 2
) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
        ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
    cell.textLabel?.text = title
    cell.detailTextLabel?.text = detail
    cell.detailTextLabel?.numberOfLines = lines
    cell.accessoryType = .none
    cell.selectionStyle = .none
    cell.imageView?.image = nil
    cell.textLabel?.textColor = .label
    cell.detailTextLabel?.textColor = .secondaryLabel
    cell.accessoryView = nil
    IFAppStyle.configure(cell)
    return cell
}

func IFShowMessage(
    on controller: UIViewController,
    title: String = "iFetch",
    message: String
) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .cancel))
    controller.present(alert, animated: true)
}

final class IFLineChartView: UIView {
    var values: [Double] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    var lineColor = UIColor.systemBlue
    var fixedMaximum = 0.0
    var unit = ""
    var rateValues = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = IFAppStyle.cardBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let plot = CGRect(
            x: 44,
            y: 12,
            width: max(1, rect.width - 56),
            height: max(1, rect.height - 34)
        )
        var maximum = fixedMaximum
        if maximum <= 0 {
            maximum = max(1, (values.max() ?? 0) * 1.15)
        }

        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.5)
        let axisAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 8, weight: .medium),
            .foregroundColor: UIColor.tertiaryLabel
        ]

        for row in 0...3 {
            let y = plot.minY + plot.height * CGFloat(row) / 3
            context.move(to: CGPoint(x: plot.minX, y: y))
            context.addLine(to: CGPoint(x: plot.maxX, y: y))
            let axisValue = maximum * (1 - Double(row) / 3)
            let text = rateValues
                ? IFDisplayFormatter.rate(axisValue)
                : String(format: "%.0f%@", axisValue, unit)
            text.draw(in: CGRect(x: 4, y: y - 6, width: 38, height: 12), withAttributes: axisAttributes)
        }
        context.strokePath()

        guard values.count > 1 else {
            let text = IFL("Collecting data…", "Сбор данных…")
            let size = text.size(withAttributes: axisAttributes)
            text.draw(
                at: CGPoint(x: plot.midX - size.width / 2, y: plot.midY - size.height / 2),
                withAttributes: axisAttributes
            )
            return
        }

        let path = UIBezierPath()
        for (index, value) in values.enumerated() {
            let x = plot.minX + plot.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
            let y = plot.minY + plot.height * CGFloat(1 - min(1, max(0, value / maximum)))
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        let fill = UIBezierPath(cgPath: path.cgPath)
        fill.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        fill.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        fill.close()
        lineColor.withAlphaComponent(0.14).setFill()
        fill.fill()

        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        lineColor.setStroke()
        path.stroke()

        if let last = values.last {
            let y = plot.minY + plot.height * CGFloat(1 - min(1, max(0, last / maximum)))
            context.setFillColor(lineColor.cgColor)
            context.fillEllipse(in: CGRect(x: plot.maxX - 3.5, y: y - 3.5, width: 7, height: 7))
        }
    }
}

extension UITableViewController {
    func ifEmptyBackground(_ text: String, visible: Bool) {
        guard visible else {
            tableView.backgroundView = nil
            return
        }
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        tableView.backgroundView = label
    }
}
