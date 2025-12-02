import SwiftUI

struct SavedCardSummary: View {
    let card: PrepayServiceCustomer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.unitName ?? "Prepaid Card")
                        .font(.headline)

                    Text("Units Remaining: \(card.remainingUnits)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Expires: \(formattedDate(card.endDate))")
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

    private func formattedDate(_ dateString: String?) -> String {
        guard let dateString else { return "N/A" }
        return String(dateString.prefix(10)) // yyyy-mm-dd
    }


    private func masked(number: String) -> String {
        let last4 = number.suffix(4)
        return "•••• •••• •••• \(last4)"
    }
}
