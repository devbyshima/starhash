import Foundation

/// StarHash's own links (starhash://), made and read in one place: the
/// app's quick actions and notifications, the widgets and the bundled
/// shortcut make them, and the app's router reads them, so a link always
/// opens what its maker meant.
public enum StarHashLink: Hashable, Sendable {
    /// A page of the app.
    case page(Page)
    /// A StarHash QR code's link: who to pay, and how much when it says
    /// (`PaymentQR`).
    case payment(PaymentRequest)
    /// One transaction's page.
    case transaction(UUID)
    /// The QR scanner.
    case scan
    /// A USSD code to dial (Balance, Buy's codes on the Home Screen).
    case dial(code: String)
    /// The auto-verify shortcut, run by the setup's check, answering.
    case shortcutRan(ShortcutResult)
    /// What's New on a page (debug builds only act on it).
    case whatsNew(page: Int)

    public enum Page: String, CaseIterable, Sendable {
        case pay, buy, activity, settings
    }

    /// How the shortcut run by the setup's check ended, as Shortcuts'
    /// x-callback says.
    public enum ShortcutResult: String, Sendable {
        case success, error, cancel
    }

    static let scheme = "starhash"

    /// Reads a starhash:// link; nil for any other, or one StarHash never
    /// makes. starhash://help, from before Help moved into Settings, opens
    /// Settings.
    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host() else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        switch host {
        case "help":
            self = .page(.settings)
        case "pay" where value("to") != nil:
            guard let request = PaymentQR.parse(url.absoluteString) else { self = .page(.pay); return }
            self = .payment(request)
        case "transaction":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .transaction(id)
        case "scan":
            self = .scan
        case "dial":
            guard let code = value("code").flatMap(USSDShortcut.code(from:)) else { return nil }
            self = .dial(code: code)
        case "shortcut":
            self = .shortcutRan(ShortcutResult(rawValue: url.lastPathComponent) ?? .error)
        case "whatsnew":
            self = .whatsNew(page: value("page").flatMap(Int.init) ?? 0)
        default:
            guard let page = Page(rawValue: host) else { return nil }
            self = .page(page)
        }
    }

    public var url: URL {
        switch self {
        case .page(let page):
            return URL(string: "\(Self.scheme)://\(page.rawValue)")!
        case .payment(let request):
            return PaymentQR.link(for: request.recipient, amount: request.amount, photoID: request.photoID)
        case .transaction(let id):
            return URL(string: "\(Self.scheme)://transaction/\(id.uuidString)")!
        case .scan:
            return URL(string: "\(Self.scheme)://scan")!
        case .dial(let code):
            // `#` and `*` are kept out of the URL's own syntax.
            let encoded = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            return URL(string: "\(Self.scheme)://dial?code=\(encoded)")!
        case .shortcutRan(let result):
            return URL(string: "\(Self.scheme)://shortcut/\(result.rawValue)")!
        case .whatsNew(let page):
            return URL(string: "\(Self.scheme)://whatsnew?page=\(page)")!
        }
    }
}
