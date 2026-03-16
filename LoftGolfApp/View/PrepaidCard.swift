import SwiftUI

struct PrepaidCard: View {
    let freeHours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.green)

                Text("Prepaid Free Hours")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.gray)
            }

            Text("\(freeHours)")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.green)

            Text("Hours Remaining")
                .foregroundStyle(.gray)
                .font(.subheadline)

            Divider().background(Color.gray.opacity(0.3))
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.9), lineWidth: 1)
        )
    }
}
