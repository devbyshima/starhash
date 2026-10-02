import StarHashKit
import Testing

struct AmountInputTests {
    private func typed(_ keys: [AmountInput.Key], maximum: Int = Money.maximumAmount) -> AmountInput {
        var input = AmountInput(maximum: maximum)
        for key in keys { input.apply(key) }
        return input
    }

    @Test func digitsAppend() {
        #expect(typed([.digit(5), .digit(0), .digit(0), .digit(0)]).value == 5_000)
    }

    @Test func leadingZerosAreIgnored() {
        var input = AmountInput()
        #expect(input.apply(.digit(0)) == false)
        #expect(input.value == 0)
        input.apply(.digit(7))
        #expect(input.value == 7)
    }

    @Test func deleteDropsTheLastDigit() {
        #expect(typed([.digit(1), .digit(2), .digit(3), .delete]).value == 12)
        var empty = AmountInput()
        #expect(empty.apply(.delete) == false)
    }

    @Test func clearResets() {
        let input = typed([.digit(9), .digit(9), .clear])
        #expect(input.value == 0)
        #expect(input.isZero)
    }

    @Test func digitsPastTheCeilingAreRefused() {
        var input = AmountInput(value: 1_000_000)
        #expect(input.apply(.digit(0)) == true)
        #expect(input.value == 10_000_000)
        #expect(input.apply(.digit(0)) == false)
        #expect(input.value == 10_000_000)

        var near = AmountInput(value: 1_000_001)
        #expect(near.apply(.digit(0)) == false)
        #expect(near.value == 1_000_001)
    }

    @Test func initialValueIsClamped() {
        #expect(AmountInput(value: -4).value == 0)
        #expect(AmountInput(value: 12_000_000).value == Money.maximumAmount)
        #expect(Money.maximumAmount == 10_000_000)
    }

    @Test func invalidDigitIsIgnored() {
        var input = AmountInput()
        #expect(input.apply(.digit(12)) == false)
    }

    @Test func hugeCeilingDoesNotOverflow() {
        var input = AmountInput(value: Int.max / 10, maximum: .max)
        #expect(input.apply(.digit(9)) == false)
        #expect(input.apply(.digit(7)) == true)
        #expect(input.value == .max)
    }
}
