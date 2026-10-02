import SwiftUI

/// Buy: airtime, bundles and electricity through MoMo. Not built yet; the
/// page holds its place in the menu.
struct BuyView: View {
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Buy")

            // Centred in the space between the header and the bottom of
            // the screen.
            EmptyStateView(
                symbol: "bag",
                title: "Coming Soon",
                message: "Buy airtime, bundles and electricity with MoMo, right from StarHash.",
                style: .large
            )
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashBackground.ignoresSafeArea())
    }
}
