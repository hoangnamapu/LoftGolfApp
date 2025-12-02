import SwiftUI

struct SavedCardsListView: View {
    @State private var savedCards: [SavedCardDisplay] = []
    @State private var showNewCardForm = false
    @State private var showDeleteConfirmation = false
    @State private var cardToDelete: SavedCardDisplay?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if savedCards.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        
                        Text("No Saved Cards")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        Text("Add a credit card to make checkout faster")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            showNewCardForm = true
                        } label: {
                            Label("Add Card", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                } else {
                    List {
                        Section {
                            ForEach(savedCards, id: \.last4Digits) { card in
                                SavedCardRow(card: card) {
                                    cardToDelete = card
                                    showDeleteConfirmation = true
                                }
                            }
                        } header: {
                            Text("Saved Cards")
                        }
                        
                        Section {
                            Button {
                                showNewCardForm = true
                            } label: {
                                Label("Add New Card", systemImage: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Payment Methods")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewCardForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadCards()
            }
            .sheet(isPresented: $showNewCardForm) {
                PaymentCardFormView { newCard in
                    PaymentCardKeychainManager.shared.saveCardDisplay(from: newCard)
                    loadCards()
                }
            }
            .alert("Delete Card?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    cardToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let card = cardToDelete {
                        deleteCard(card)
                    }
                }
            } message: {
                if let card = cardToDelete {
                    Text("Are you sure you want to remove \(card.cardType) ending in \(card.last4Digits)?")
                }
            }
        }
    }
    
    private func loadCards() {
        savedCards = PaymentCardKeychainManager.shared.loadAllCardDisplays()
        print("📱 Loaded \(savedCards.count) saved card(s)")
    }
    
    private func deleteCard(_ card: SavedCardDisplay) {
        PaymentCardKeychainManager.shared.deleteCardDisplay(last4: card.last4Digits)
        loadCards()
        cardToDelete = nil
    }
}

// MARK: - Card Row Component
struct SavedCardRow: View {
    let card: SavedCardDisplay
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Card icon with brand color
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardBrandColor(card.cardType))
                    .frame(width: 50, height: 35)
                
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.nameOnCard)
                    .font(.headline)
                
                Text("\(card.cardType) •••• \(card.last4Digits)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if card.isExpired {
                    Text("Expired")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                } else {
                    Text("Expires \(String(format: "%02d/%02d", card.expMonth, card.expYear % 100))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
    
    private func cardBrandColor(_ brand: String) -> Color {
        switch brand.lowercased() {
        case "visa":
            return Color.blue
        case "mastercard":
            return Color.orange
        case "american express":
            return Color.green
        case "discover":
            return Color.purple
        default:
            return Color.gray
        }
    }
}

// MARK: - Preview
#if DEBUG
struct SavedCardsListView_Previews: PreviewProvider {
    static var previews: some View {
        SavedCardsListView()
    }
}
#endif
