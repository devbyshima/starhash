import SwiftUI
import UIKit

// The navigation bar's buttons, drawn by StarHash rather than the system:
// the system draws its own glass behind bar buttons, which no tint
// reaches, and on the blue light-mode page it came out a bright cyan.
// These use `StarHashCircleGlyph`, the same tinted glass circle as every
// other round button.

extension View {
    /// A pushed page's back button, in StarHash's glass circle, in place
    /// of the system's. The swipe in from the left edge still goes back.
    func starhashBackButton() -> some View {
        modifier(StarHashBackButton())
    }

    /// A back button on the left that runs `back`, and a close button on
    /// the right when `close` is given, for a page that steps back through
    /// itself before leaving (auto-verify's setup). The swipe from the
    /// left edge still goes back a screen.
    func starhashBackAndClose(back: @escaping () -> Void, close: (() -> Void)?) -> some View {
        modifier(BackAndClose(back: back, close: close))
    }

    /// An inline navigation bar title set as every page's title is
    /// (`PageTitle`), drawn by SwiftUI in the bar's middle: UIKit's own
    /// title came out in the system font on some stacks. The plain title
    /// stays for VoiceOver and the back menu.
    func starhashNavigationTitle(_ title: String) -> some View {
        modifier(NavigationPageTitle(title: title))
    }
}

private struct StarHashBackButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .barButton {
                Button { dismiss() } label: {
                    StarHashCircleGlyph(symbol: "chevron.left")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Back")
            }
            .background(SwipeBackEnabler())
    }
}

private struct BackAndClose: ViewModifier {
    let back: () -> Void
    let close: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .barButton {
                Button(action: back) {
                    StarHashCircleGlyph(symbol: "chevron.left")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Back")
            }
            .trailingBarButton {
                if let close {
                    Button(action: close) {
                        StarHashCircleGlyph(symbol: "xmark")
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityLabel("Close")
                }
            }
            .background(SwipeBackEnabler())
    }
}

private struct NavigationPageTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .principalTitle { PageTitle(text: title).lineLimit(1) }
    }
}

private extension View {
    /// `title` in the middle of the bar, with no system glass behind it.
    @ViewBuilder
    func principalTitle(@ViewBuilder _ title: () -> some View) -> some View {
        if #available(iOS 26.0, *) {
            toolbar {
                ToolbarItem(placement: .principal) { title() }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            toolbar {
                ToolbarItem(placement: .principal) { title() }
            }
        }
    }

    /// `button` at the trailing end of the bar, with no system glass.
    @ViewBuilder
    func trailingBarButton(@ViewBuilder _ button: () -> some View) -> some View {
        if #available(iOS 26.0, *) {
            toolbar {
                ToolbarItem(placement: .topBarTrailing) { button() }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            toolbar {
                ToolbarItem(placement: .topBarTrailing) { button() }
            }
        }
    }

    /// `button` at the leading end of the bar, with the system's own glass
    /// behind it turned off on iOS 26 and later, where it would sit under
    /// ours.
    @ViewBuilder
    func barButton(@ViewBuilder _ button: () -> some View) -> some View {
        if #available(iOS 26.0, *) {
            toolbar {
                ToolbarItem(placement: .topBarLeading) { button() }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            toolbar {
                ToolbarItem(placement: .topBarLeading) { button() }
            }
        }
    }
}

/// Keeps the swipe in from the left edge going back on a pushed page that
/// draws its own header: hiding the navigation bar would otherwise turn it
/// off. The navigation controller's own delegate is put back as the page
/// goes, so the root page never starts a swipe with nothing to go back to.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        private weak var savedDelegate: (any UIGestureRecognizerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let pop = navigationController?.interactivePopGestureRecognizer else { return }
            savedDelegate = pop.delegate
            pop.delegate = nil
            pop.isEnabled = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = savedDelegate
        }
    }
}
