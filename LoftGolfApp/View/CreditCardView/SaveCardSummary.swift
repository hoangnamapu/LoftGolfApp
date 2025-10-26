import SwiftUI

struct SavedCardSummary: View {
    let data: PaymentCardFormData
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(masked(number: data.number))
                        .font(.headline)
                    Text("Exp: \(expString(data))  •  \(data.nameOnCard)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func masked(number: String) -> String {
        let digits = number.filter(\.isNumber)
        let last4 = digits.suffix(4)
        return "•••• •••• •••• \(last4)"
    }

    private func expString(_ d: PaymentCardFormData) -> String {
        guard let m = d.expMonth, let y = d.expYear else { return "--/--" }
        let yy = String(y % 100)
        let mm = String(format: "%02d", m)
        return "\(mm)/\(yy)"
    }
}
