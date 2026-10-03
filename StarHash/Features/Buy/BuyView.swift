import SwiftUI

/// Buy: airtime, bundles and electricity through MoMo. Not built yet; the
/// switcher at the top left of Pay comes here.
struct BuyView: View {
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(page: .buy, title: "Buy")

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
        .starhashTabBarClearance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashBackground.ignoresSafeArea())
    }
}
