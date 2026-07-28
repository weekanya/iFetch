import Foundation
import WidgetKit

@objc(IFWidgetRefreshBridge)
final class IFWidgetRefreshBridge: NSObject {
    @objc static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: "com.wee1ka.ifetch.system")
    }
}
