import Foundation

enum IFAppRoute: String {
    case overview
    case diagnostics
    case advanced

    init(destination: Any?) {
        guard let value = destination as? String,
              let route = IFAppRoute(rawValue: value.lowercased()) else {
            self = .diagnostics
            return
        }
        self = route
    }

    var url: URL? {
        URL(string: "ifetch://\(rawValue)")
    }
}
