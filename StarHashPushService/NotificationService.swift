import Contacts
import Foundation
import StarHashKit
import UserNotifications

/// The server's push for a request carries it sealed (server/src/push.ts).
/// iOS hands it here before showing it: opened with the owner's request key
/// and passing the app's own checks (`PushedRequest.open`), it says "Request
/// for 1,500 RWF from Jean Bosco", with the note under it; anything else,
/// or no answer in time, shows as it came, "New request". Nothing is
/// written or sent: the directory is only asked who lists the asker's
/// number, and the app takes the request in as it always does.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?
    private var work: Task<Void, Never>?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        lock.withLock {
            handler = contentHandler
            content = request.content.mutableCopy() as? UNMutableNotificationContent
        }
        guard let pushed = PushedRequest.Sealed(userInfo: request.content.userInfo),
              let settings = PushKeychain.settings(), let own = PushKeychain.requestKey() else {
            deliver(nil)
            return
        }
        StarHashLanguage.locale = Locale(identifier: settings.language)
        work = Task { [self] in
            let opened = await PushedRequest.open(
                pushed, with: own,
                lookUp: { await Self.lookUp($0, on: settings.server) },
                contact: { Self.contact($0, allowed: settings.contacts) }
            )
            deliver(opened.map { (PushedRequest.text(for: $0, showsAmounts: settings.showsAmounts), $0.ask.id) })
        }
    }

    /// Out of time: the push as it came.
    override func serviceExtensionTimeWillExpire() {
        work?.cancel()
        deliver(nil)
    }

    /// Hands iOS the notification once: the request's words, tagged as
    /// StarHash's own notification of it is, so a tap opens it and the app
    /// says nothing more of it; or the push's own.
    private func deliver(_ opened: ((title: String, body: String), id: UUID)?) {
        let (handler, content) = lock.withLock {
            defer { handler = nil }
            return (handler, content)
        }
        guard let handler, let content else { return }
        if let opened {
            content.title = opened.0.title
            content.body = opened.0.body
            content.userInfo["request"] = opened.id.uuidString
            content.userInfo["kind"] = NotificationPlan.Item.Kind.requestReceived.rawValue
        }
        handler(content)
    }

    // MARK: The checks' sources

    /// Who the directory lists `number` under, as the app asks it
    /// (`StarHashCloud.lookUp`): the number in a body, never a URL.
    private static func lookUp(_ number: String, on server: URL) async -> RequestsAnywhere.LookUp {
        var request = URLRequest(url: server.appending(path: "v1/directory/lookup"), timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["number": number])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .failed }
        if status == 404 { return .notListed }
        guard status == 200, let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .failed }
        return .listed(.init(name: found["name"] as? String, photoID: nil, key: found["key"] as? String))
    }

    /// The name `asker`'s number is saved under in Contacts, as the app
    /// matches numbers (`PayContacts`): only with full access and Enable
    /// contacts on, or it cannot tell.
    private static func contact(_ asker: Recipient, allowed: Bool) -> PushedRequest.Contact {
        guard allowed, CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return .cannotTell }
        let keys: [any CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactOrganizationNameKey as any CNKeyDescriptor,
            CNContactPhoneNumbersKey as any CNKeyDescriptor,
        ]
        var found: String?
        do {
            try CNContactStore().enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, stop in
                let matches = contact.phoneNumbers.contains {
                    Recipient(input: $0.value.stringValue)?.identity == asker.identity
                }
                guard matches else { return }
                let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                found = formatted.isEmpty ? contact.organizationName : formatted
                stop.pointee = true
            }
        } catch {
            return .cannotTell
        }
        guard let found else { return .unknown }
        return .saved(found.isEmpty ? asker.displayName : found)
    }
}
