import SwiftUI

/// Simple container to show a saved card summary on the Profile tab
struct SavedCardSummary: View {
    let name: String
    let last4: String
    let expMonth: Int
    let expYear: Int

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 26))
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(masked(last4: last4))
                    .font(.headline)
                Text("Exp: \(expMonth)/\(String(expYear % 100).leftPad2())  •  \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func masked(last4: String) -> String { "•••• •••• •••• " + last4 }
}

private extension String {
    func leftPad2() -> String { count == 1 ? ("0" + self) : self }
}

// MARK: - Profile Tab wired with PaymentCardFormView
struct ProfileTabView: View {
    @State private var showingCardSheet = false
    @State private var savedCard: PaymentCardFormData? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray)
                            Text("Profile")
                                .font(.title.bold())
                            Text("This is the profile page")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 24)

                        // Payment section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Payment Method").font(.headline)
                                Spacer()
                                Button(savedCard == nil ? "Add" : "Edit") { showingCardSheet = true }
                                    .buttonStyle(.bordered)
                            }

                            if let card = savedCard {
                                SavedCardSummary(
                                    name: card.nameOnCard,
                                    last4: String(card.number.suffix(4)),
                                    expMonth: card.expMonth ?? 0,
                                    expYear: card.expYear ?? 0
                                )
                            } else {
                                Text("No card on file")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 24)
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingCardSheet) {
                PaymentCardFormView(initial: savedCard) { data in
                    // Persist ONLY display-safe bits to Keychain
                    let display = ProfileCardDisplay(
                        nameOnCard: data.nameOnCard,
                        last4: String(data.number.suffix(4)),
                        expMonth: data.expMonth ?? 0,
                        expYear: data.expYear ?? 0
                    )
                    saveProfileCardDisplay(display)
                    savedCard = data
                }
            }
            .onAppear {
                if let d = loadProfileCardDisplay() {
                    // Rehydrate minimal state for the UI (PAN/CVV not stored)
                    savedCard = PaymentCardFormData(
                        nameOnCard: d.nameOnCard,
                        number: "****" + d.last4,   // placeholder for display only
                        expMonth: d.expMonth,
                        expYear: d.expYear,
                        cvv: "",
                        billingAddress: "",
                        billingCity: "",
                        billingState: "",
                        billingZip: ""
                    )
                }
            }
        }
    }
}

#Preview {
    ProfileTabView()
}
