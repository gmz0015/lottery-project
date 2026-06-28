import SwiftUI

struct NumberBadges: View {
    let numbers: [Int]
    var matched: Set<Int> = []
    var color: Color = .red

    var body: some View {
        HStack(spacing: 6) {
            ForEach(numbers, id: \.self) { n in
                Text(String(format: "%02d", n))
                    .font(.system(.body, design: .rounded)).bold()
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(matched.contains(n) ? color : Color.gray.opacity(0.25)))
                    .foregroundStyle(matched.contains(n) ? .white : .primary)
                    .contentTransition(.numericText())
            }
        }
        .animation(AppMotion.quick, value: matched)
    }
}
