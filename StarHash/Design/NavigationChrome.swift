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

    /// A close button at the leading end of the bar, for a page shown over
    /// everything (auto-verify's setup during onboarding).
    func starhashCloseButton(_ action: @escaping () -> Void) -> some View {
        barButton {
            Button(action: action) {
                StarHashCircleGlyph(symbol: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    /// The side menu button at the leading end of a root page's bar
    /// (Settings).
    func starhashSideMenuToolbar() -> some View {
        modifier(SideMenuToolbar())
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
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            .background(SwipeBackEnabler())
    }
}

private struct SideMenuToolbar: ViewModifier {
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.barButton {
            Button { router.isMenuOpen = true } label: {
                StarHashCircleGlyph(symbol: "line.3.horizontal")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
        }
    }
}

private extension View {
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
