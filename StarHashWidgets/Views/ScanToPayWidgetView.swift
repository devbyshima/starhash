#if DEBUG || WIDGET_EXTENSION
import SwiftUI
import WidgetKit

/// Scan to Pay on the Home Screen: the scanner's symbol and its name, laid
/// out as the small Buy widget is, opening StarHash on its scanner.
struct ScanToPayWidgetView: View {
    var body: some View {
        SmallWidgetLabel(symbol: "qrcode.viewfinder", name: Text("Scan to Pay"))
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .widgetURL(URL(string: "starhash://scan"))
    }
}
#endif
