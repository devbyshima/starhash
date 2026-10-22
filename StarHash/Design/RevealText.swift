import SwiftUI

/// Words that rise into place one after another out of a slight blur,
/// after textmotion.dev's "blur out up": each word 10 points low, 6 points
/// of blur and clear at first, settling over 0.56 s on an ease-out, 28 ms
/// after the word before it. Onboarding's titles and lines, so a new screen
/// reads as new; the old one leaves as the effect's exit does
/// (`AnyTransition.blurOutUp`). `startIndex` carries the count on from the
/// words above (a line under its title), and `delay` waits for the screen
/// before to leave. With Reduce Motion the words are simply there.
struct RevealText: View {
    let words: [Token]
    var startIndex = 0
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: Double = 0

    /// Looked up in the string catalog by its English, as `Text(catalog:)`.
    init(_ key: String, startIndex: Int = 0, delay: Double = 0) {
        let text = String(starhash: LocalizedStringResource(String.LocalizationValue(key)))
        self.words = Token.split(text)
        self.startIndex = startIndex
        self.delay = delay
    }

    /// How many words it has, for the line that follows it.
    static func wordCount(_ key: String) -> Int {
        Token.split(String(starhash: LocalizedStringResource(String.LocalizationValue(key)))).filter(\.isWord).count
    }

    var body: some View {
        let count = words.filter(\.isWord).count
        let total = RevealTiming.duration + RevealTiming.stagger * Double(startIndex + count)
        text
            .textRenderer(RevealRenderer(elapsed: reduceMotion ? total : elapsed))
            .onAppear {
                guard !reduceMotion, elapsed == 0 else { return }
                withAnimation(.linear(duration: total).delay(delay)) { elapsed = total }
            }
            .accessibilityLabel(Text(verbatim: words.map(\.text).joined()))
    }

    /// The words, each marked with its place in the order they rise.
    private var text: Text {
        var index = startIndex
        return words.reduce(Text(verbatim: "")) { result, token in
            guard token.isWord else { return result + Text(verbatim: token.text) }
            defer { index += 1 }
            return result + Text(verbatim: token.text).customAttribute(RevealWord(index: index))
        }
    }

    /// A stretch of the text: a word, or the spaces and line breaks
    /// between words, which are never animated.
    struct Token {
        let text: String
        let isWord: Bool

        static func split(_ text: String) -> [Token] {
            var tokens: [Token] = []
            var current = ""
            var inWord: Bool?
            for character in text {
                let isWord = !character.isWhitespace
                if inWord != nil, inWord != isWord {
                    tokens.append(Token(text: current, isWord: inWord!))
                    current = ""
                }
                current.append(character)
                inWord = isWord
            }
            if let inWord, !current.isEmpty { tokens.append(Token(text: current, isWord: inWord)) }
            return tokens
        }
    }
}

/// The effect's numbers, from its spec.
enum RevealTiming {
    static let duration = 0.56
    static let stagger = 0.028
    static let rise: CGFloat = 10
    static let blur: CGFloat = 6
    /// The exit: 0.48 s on an ease-in, 14 points up, 8 points of blur.
    static let exitDuration = 0.48
    static let exitRise: CGFloat = 14
    static let exitBlur: CGFloat = 8
    /// The new words start as the old screen is nearly gone: the exit,
    /// less the 0.17 s the two overlap, plus 0.035 s.
    static let enterDelay = exitDuration - 0.17 + 0.035
}

/// Which word a run of glyphs belongs to.
private struct RevealWord: TextAttribute {
    let index: Int
}

/// Draws each word at its own point in the rise: opacity, blur and a drop
/// that all ease out from the word's start, `stagger` after the one before.
private struct RevealRenderer: TextRenderer, Animatable {
    var elapsed: Double

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let word = run[RevealWord.self] else {
                    context.draw(run)
                    continue
                }
                let start = RevealTiming.stagger * Double(word.index)
                let linear = min(max((elapsed - start) / RevealTiming.duration, 0), 1)
                let progress = Self.easeOut(linear)
                guard progress > 0 else { continue }
                var copy = context
                copy.opacity = progress
                copy.translateBy(x: 0, y: RevealTiming.rise * (1 - progress))
                if progress < 1 {
                    copy.addFilter(.blur(radius: RevealTiming.blur * (1 - progress)))
                }
                copy.draw(run)
            }
        }
    }

    /// cubic-bezier(0.22, 1, 0.36, 1), the spec's ease-out, closely: a
    /// fast start that settles gently.
    private static func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 4)
    }
}

extension AnyTransition {
    /// The screen leaving as the reveal's exit has its words leave: up 14
    /// points into 8 points of blur as it fades, over 0.48 s on an ease-in.
    /// Coming in, it fades up as its words rise.
    static var blurOutUp: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.3).delay(RevealTiming.enterDelay)),
            removal: .modifier(
                active: BlurOutUp(progress: 1),
                identity: BlurOutUp(progress: 0)
            )
            .animation(.timingCurve(0.64, 0, 0.78, 0, duration: RevealTiming.exitDuration))
        )
    }
}

private struct BlurOutUp: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(1 - progress)
            .offset(y: -RevealTiming.exitRise * progress)
            .blur(radius: RevealTiming.exitBlur * progress)
    }
}
