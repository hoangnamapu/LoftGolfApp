import SwiftUI

struct SavedCardsSelectionView: View {
    @State private var savedCards: [SavedCardDisplay] = []
    @State private var showNewCardForm = false
    let onCardSelected: (SavedCardDisplay) -> Void
    
    var body: some View {
        List {
            if savedCards.isEmpty {
                Text("No saved cards")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(savedCards, id: \.last4Digits) { card in
                    Button {
                        onCardSelected(card)
                    } label: {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(card.nameOnCard)
                                    .font(.headline)
                                Text("\(card.cardType) •••• \(card.last4Digits)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Expires: \(String(format: "%02d/%02d", card.expMonth, card.expYear % 100))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .onDelete(perform: deleteCard)
            }
            
            Button {
                showNewCardForm = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Add New Card")
                }
            }
        }
        .navigationTitle("Payment Method")
        .onAppear {
            loadCards()
        }
        .sheet(isPresented: $showNewCardForm) {
            PaymentCardFormView { newCard in
                PaymentCardKeychainManager.shared.saveCardDisplay(from: newCard)
                loadCards()
            }
        }
    }
    
    private func loadCards() {
        savedCards = PaymentCardKeychainManager.shared.loadAllCardDisplays()
    }
    
    private func deleteCard(at offsets: IndexSet) {
        for index in offsets {
            let card = savedCards[index]
            PaymentCardKeychainManager.shared.deleteCardDisplay(last4: card.last4Digits)
        }
        loadCards()
    }
}
