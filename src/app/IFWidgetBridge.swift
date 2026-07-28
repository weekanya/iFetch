import Foundation
import WidgetKit

@objc(IFWidgetBridge)
final class IFWidgetBridge: NSObject {
    @objc static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
