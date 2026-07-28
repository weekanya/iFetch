import Foundation
import WidgetKit

@objc(IFWidgetBridge)
final class IFWidgetBridge: NSObject {
    @objc static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: "com.wee1ka.ifetch.system")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
