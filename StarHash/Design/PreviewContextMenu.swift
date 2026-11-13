import SwiftUI
import UIKit

extension View {
    /// A long press lifts `preview` over the dimmed page with no menu under
    /// it, as a system list lifts a cell's preview, and a tap on the preview
    /// runs `onOpen`. This is UIKit's context menu: SwiftUI's opens nothing
    /// when its menu is empty. The view shows `highlight` behind it while
    /// the finger holds it, as a list's cell does, and the preview grows out
    /// of its place and shrinks back into it. The view must be inside a
    /// scroll view, whose one interaction serves every row.
    func previewContextMenu<Preview: View>(
        isEnabled: Bool = true,
        size: CGSize,
        highlight: Color,
        onOpen: @escaping () -> Void,
        @ViewBuilder preview: @escaping () -> Preview
    ) -> some View {
        modifier(PreviewContextMenuModifier(
            isEnabled: isEnabled,
            size: size,
            highlight: highlight,
            onOpen: onOpen,
            preview: preview
        ))
    }
}

private struct PreviewContextMenuModifier<Preview: View>: ViewModifier {
    let isEnabled: Bool
    let size: CGSize
    let highlight: Color
    let onOpen: () -> Void
    let preview: () -> Preview

    /// The preview is hosted apart from the page, so the language chosen in
    /// Settings goes with it.
    @Environment(\.locale) private var locale
    /// Held: the long press cancels the button's own press as it begins,
    /// so the highlight is kept here until the preview lifts.
    @State private var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background {
                highlight
                    .opacity(isHighlighted ? 1 : 0)
                    .animation(isHighlighted ? nil : .easeOut(duration: 0.25), value: isHighlighted)
            }
            .background {
                PreviewMenuAnchor(
                    isEnabled: isEnabled,
                    size: size,
                    onOpen: onOpen,
                    onHighlight: { isHighlighted = $0 },
                    preview: { AnyView(preview().environment(\.locale, locale)) }
                )
                .allowsHitTesting(false)
            }
    }
}

private struct PreviewMenuAnchor: UIViewRepresentable {
    let isEnabled: Bool
    let size: CGSize
    let onOpen: () -> Void
    let onHighlight: (Bool) -> Void
    let preview: () -> AnyView

    func makeUIView(context: Context) -> PreviewMenuAnchorView {
        PreviewMenuAnchorView()
    }

    func updateUIView(_ view: PreviewMenuAnchorView, context: Context) {
        view.isEnabled = isEnabled
        view.previewSize = size
        view.onOpen = onOpen
        view.onHighlight = onHighlight
        view.makePreview = preview
    }
}

/// Stands where its row is, so the scroll view's interaction can tell
/// which row a long press landed on, and builds that row's preview.
final class PreviewMenuAnchorView: UIView {
    var isEnabled = true
    var previewSize: CGSize = .zero
    var onOpen: (() -> Void)?
    var onHighlight: ((Bool) -> Void)?
    var makePreview: (() -> AnyView)?

    private weak var menu: PreviewMenuInteraction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        menu?.remove(self)
        menu = nil
        guard let window else { return }
        let scrollView = sequence(first: superview, next: { $0?.superview }).lazy.compactMap { $0 as? UIScrollView }.first
        menu = PreviewMenuInteraction.shared(for: scrollView ?? window)
        menu?.add(self)
    }
}

/// One context menu interaction for a scroll view's rows, as a collection
/// view has one for its cells: it lifts the preview of the row under the
/// finger and lays it back there.
@MainActor
private final class PreviewMenuInteraction: NSObject, UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate {
    /// Keeps each host's interaction delegate, which UIKit holds weakly.
    private static let menus = NSMapTable<UIView, PreviewMenuInteraction>.weakToStrongObjects()

    static func shared(for host: UIView) -> PreviewMenuInteraction {
        if let menu = menus.object(forKey: host) { return menu }
        let menu = PreviewMenuInteraction()
        host.addInteraction(UIContextMenuInteraction(delegate: menu))
        // Follows the finger alongside everything else, taking nothing from
        // them, to know when it leaves a row held but not yet lifted.
        let finger = UILongPressGestureRecognizer(target: menu, action: #selector(fingerMoved(_:)))
        finger.minimumPressDuration = 0
        finger.cancelsTouchesInView = false
        finger.delaysTouchesEnded = false
        finger.delegate = menu
        host.addGestureRecognizer(finger)
        menus.setObject(menu, forKey: host)
        return menu
    }

    private let anchors = NSHashTable<PreviewMenuAnchorView>.weakObjects()
    /// The row pressed last, and the one showing its highlight.
    private weak var lifted: PreviewMenuAnchorView?
    private weak var highlighted: PreviewMenuAnchorView?

    func add(_ anchor: PreviewMenuAnchorView) { anchors.add(anchor) }
    func remove(_ anchor: PreviewMenuAnchorView) { anchors.remove(anchor) }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let anchor = anchors.allObjects.first(where: {
            $0.isEnabled && $0.window != nil && $0.bounds.contains(interaction.location(in: $0))
        }), let makePreview = anchor.makePreview else { return nil }
        lifted = anchor
        highlight(anchor)
        let size = anchor.previewSize
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            let controller = UIHostingController(rootView: makePreview())
            controller.view.backgroundColor = .clear
            controller.preferredContentSize = size
            return controller
        }, actionProvider: nil)
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configuration: UIContextMenuConfiguration,
        highlightPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        targetedPreview()
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configuration: UIContextMenuConfiguration,
        dismissalPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        targetedPreview()
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        highlight(nil)
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: any UIContextMenuInteractionCommitAnimating
    ) {
        let open = lifted?.onOpen
        animator.addCompletion {
            MainActor.assumeIsolated { open?() }
        }
    }

    /// The anchor itself, clear and without a shadow, so the row under it
    /// keeps showing as it is pressed (its own grey), the preview grows out
    /// of its place and shrinks back into it, and the row is there when
    /// the preview has gone.
    private func targetedPreview() -> UITargetedPreview? {
        guard let anchor = lifted, anchor.window != nil else { return nil }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.shadowPath = UIBezierPath()
        return UITargetedPreview(view: anchor, parameters: parameters)
    }

    // MARK: Highlight

    private func highlight(_ anchor: PreviewMenuAnchorView?) {
        guard highlighted !== anchor else { return }
        highlighted?.onHighlight?(false)
        highlighted = anchor
        anchor?.onHighlight?(true)
    }

    /// The finger lifted or slid away before the preview did.
    @objc private func fingerMoved(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .ended, .cancelled, .failed: highlight(nil)
        default: break
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
