import SwiftUI
import UIKit

/// StarHash's own icons, one puffy style for the whole app: round and
/// soft, closed shapes filled and traced so every corner is a small curve,
/// open glyphs a thin round line, one colour, all on the same 18pt grid.
/// Each also has an outline form, its closed shapes drawn as a line, which
/// the tab bar shows for the pages not chosen.
/// `scripts/make_icons.swift` draws them into `Icons.xcassets` as custom
/// SF Symbols, so they size with the font, take the foreground style and
/// work wherever an SF Symbol does: views, menus, widgets, controls.
///
/// The app goes on naming its icons by their SF Symbols' names, the names
/// stored in Buy's codes, categories and Settings rows; `Image(symbol:)`
/// draws ours for each, and falls back to the system's for a name with no
/// drawing yet. A new icon needs its case here, its drawing in the script
/// and its SF Symbol names in `bySymbol`.
enum StarIcon: String, CaseIterable {
    case airplane, antenna, appearance, arrowDownLeft, arrowUpRight, bag, bank, battery, bell, bellBadge, bellSlash
    case bolt, box, bus, calendar, camera, car, card, cart, cash, chartBar, chartLine, chat, check, checkCircle
    case chevronLeft, chevronRight, chevronUpDown, circle, clock, close, closeCircle, code, cup, document, download, drop
    case envelope, eye, faceID, film, flag, food, fuel, game, gear, gift, globe, graduation, hash, health, heart
    case hashSquare, history, hourglass, house, info, lightbulb, location, lock, messageCheck, messageQuestion, more, parking
    case pencil, people, person, personAlert, personCircle, phone, pin, play, plus, qrCode, received, reset, scan
    case seal, search, sendBack, shieldAlert, shieldLock, share, simCard, sound, sparkles, star, store, sunset, swap
    case ticket, torch, torchOn, touchID, trash, tray, tv, unpin, wifi

    /// The symbol's name in the asset catalog: its filled form.
    var assetName: String { "Icons/" + rawValue }

    /// Its outline form, drawn beside it by the script: closed shapes as a
    /// line, for a tab that is not chosen.
    var outlineAssetName: String { assetName + "Outline" }

    /// The icon drawn for an SF Symbol's name, or nil when there is none.
    init?(symbol: String) {
        guard let icon = Self.bySymbol[symbol] else { return nil }
        self = icon
    }

    /// Every SF Symbol name the app uses, to the icon that draws it. A
    /// symbol and its filled version share a drawing: the style is filled.
    private static let bySymbol: [String: StarIcon] = [
        "airplane": .airplane,
        "antenna.radiowaves.left.and.right": .antenna,
        "arrow.counterclockwise": .reset,
        "arrow.down.circle.fill": .received,
        "arrow.down.left": .arrowDownLeft,
        "arrow.left.arrow.right": .swap,
        "arrow.up.right": .arrowUpRight,
        "arrow.uturn.backward.circle": .sendBack,
        "bag.fill": .bag,
        "banknote": .cash,
        "banknote.fill": .cash,
        "battery.50percent": .battery,
        "bell.badge.fill": .bellBadge,
        "bell.fill": .bell,
        "bell.slash.fill": .bellSlash,
        "bolt.fill": .bolt,
        "bubble.left.and.bubble.right.fill": .chat,
        "building.columns.fill": .bank,
        "bus.fill": .bus,
        "calendar": .calendar,
        "camera.fill": .camera,
        "car.fill": .car,
        "cart.fill": .cart,
        "chart.bar.fill": .chartBar,
        "chart.line.uptrend.xyaxis": .chartLine,
        "checkmark": .check,
        "checkmark.circle.fill": .checkCircle,
        "checkmark.message": .messageCheck,
        "checkmark.message.fill": .messageCheck,
        "checkmark.seal.fill": .seal,
        "chevron.left": .chevronLeft,
        "chevron.left.forwardslash.chevron.right": .code,
        "chevron.right": .chevronRight,
        "chevron.up.chevron.down": .chevronUpDown,
        "circle": .circle,
        "circle.lefthalf.filled": .appearance,
        "clock": .clock,
        "clock.arrow.circlepath": .history,
        "clock.fill": .clock,
        "creditcard.fill": .card,
        "cross.case.fill": .health,
        "cup.and.saucer.fill": .cup,
        "doc.text.fill": .document,
        "drop.fill": .drop,
        "ellipsis.circle.fill": .more,
        "envelope.open.fill": .envelope,
        "exclamationmark.shield.fill": .shieldAlert,
        "eye.fill": .eye,
        "faceid": .faceID,
        "film.fill": .film,
        "flag.fill": .flag,
        "flashlight.off.fill": .torch,
        "flashlight.on.fill": .torchOn,
        "fork.knife": .food,
        "fuelpump.fill": .fuel,
        "gamecontroller.fill": .game,
        "gearshape.fill": .gear,
        "gift.fill": .gift,
        "globe": .globe,
        "graduationcap.fill": .graduation,
        "heart.fill": .heart,
        "hourglass": .hourglass,
        "house.fill": .house,
        "info.circle": .info,
        "lightbulb.fill": .lightbulb,
        "location.fill": .location,
        "lock.fill": .lock,
        "lock.shield": .shieldLock,
        "lock.shield.fill": .shieldLock,
        "magnifyingglass": .search,
        "number": .hash,
        "number.square": .hashSquare,
        "number.square.fill": .hashSquare,
        "opticid": .eye,
        "parkingsign": .parking,
        "pencil": .pencil,
        "person.2.fill": .people,
        "person.crop.circle.badge.exclamationmark": .personAlert,
        "person.crop.circle.badge.questionmark": .personCircle,
        "person.crop.circle.fill": .personCircle,
        "person.fill": .person,
        "phone": .phone,
        "phone.fill": .phone,
        "pin": .pin,
        "pin.fill": .pin,
        "pin.slash": .unpin,
        "play.circle.fill": .play,
        "plus": .plus,
        "qrcode": .qrCode,
        "qrcode.viewfinder": .scan,
        "questionmark.bubble.fill": .messageQuestion,
        "shippingbox.fill": .box,
        "simcard.fill": .simCard,
        "sparkles": .sparkles,
        "speaker.wave.2.fill": .sound,
        "square.and.arrow.down.fill": .download,
        "square.and.arrow.up.fill": .share,
        "star.fill": .star,
        "storefront": .store,
        "storefront.fill": .store,
        "sunset.fill": .sunset,
        "ticket.fill": .ticket,
        "touchid": .touchID,
        "trash": .trash,
        "tray.full.fill": .tray,
        "tv.fill": .tv,
        "wifi": .wifi,
        "xmark": .close,
        "xmark.circle": .closeCircle,
        "xmark.circle.fill": .closeCircle,
    ]
}

extension Image {
    /// One of StarHash's icons.
    init(icon: StarIcon) {
        self.init(icon.assetName)
    }

    /// StarHash's icon for an SF Symbol's name, or the system's symbol
    /// when none is drawn for it.
    init(symbol: String) {
        if let icon = StarIcon(symbol: symbol) {
            self.init(icon: icon)
        } else {
            self.init(systemName: symbol)
        }
    }

    /// The same, in its outline form when `outline` is true (a tab that is
    /// not chosen) and filled otherwise.
    init(symbol: String, outline: Bool) {
        if let icon = StarIcon(symbol: symbol) {
            self.init(outline ? icon.outlineAssetName : icon.assetName)
        } else {
            self.init(systemName: outline ? symbol.replacingOccurrences(of: ".fill", with: "") : symbol)
        }
    }
}

extension UIImage {
    /// StarHash's icon for an SF Symbol's name, as a UIKit image, for the
    /// places SwiftUI hands an image to UIKit (a menu item's coloured icon).
    static func starhashSymbol(_ symbol: String) -> UIImage? {
        if let icon = StarIcon(symbol: symbol), let image = UIImage(named: icon.assetName) { return image }
        return UIImage(systemName: symbol)
    }
}

extension Label where Title == Text, Icon == Image {
    /// A label with StarHash's icon for an SF Symbol's name.
    init(_ titleKey: LocalizedStringKey, symbol: String) {
        self.init { Text(titleKey) } icon: { Image(symbol: symbol) }
    }

    /// The same, with words worked out at run time.
    @_disfavoredOverload
    init(_ title: some StringProtocol, symbol: String) {
        self.init { Text(title) } icon: { Image(symbol: symbol) }
    }
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    /// A button of words and StarHash's icon for an SF Symbol's name, as
    /// menus show them.
    init(_ titleKey: LocalizedStringKey, symbol: String, action: @escaping () -> Void) {
        self.init(action: action) { SwiftUI.Label(titleKey, symbol: symbol) }
    }
}
