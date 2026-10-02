import SwiftUI
import UIKit

/// A swipe in from the left edge of the screen, the system's own edge pan
/// rather than a drag that happens to start near the edge, so it does not
/// fight scroll views or rows. Reports how far it has come, then where it
/// ended and how fast.
struct EdgeSwipeGesture: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
        let recognizer = UIScreenEdgePanGestureRecognizer()
        recognizer.edges = .left
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        let translation = max(0, recognizer.translation(in: recognizer.view).x)
        switch recognizer.state {
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed:
            onEnded(0, 0)
        default:
            break
        }
    }
}
