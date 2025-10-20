import SwiftUI

struct WaiverView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false
    @State private var signedName = ""
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Participant Waiver and Release of Liability")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                Text("""
                By signing this document, I acknowledge that using the Loft Golf Studios indoor golf simulator involves inherent risks...
                [Include your full waiver text here.]
                """)
                .foregroundStyle(.white.opacity(0.9))
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 20)

                Toggle(isOn: $agreed) {
                    Text("I have read and agree to the terms above.")
                        .foregroundStyle(.white)
                }

                TextField("Type full name as signature", text: $signedName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 10)

                Button {
                    if agreed && !signedName.isEmpty {
                        // Save waiver status, then go to main app
                        dismiss()
                    } else {
                        showError = true
                    }
                } label: {
                    Text("Agree and Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(agreed && !signedName.isEmpty ? Color.white : Color.gray)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .disabled(!agreed || signedName.isEmpty)

                if showError {
                    Text("Please agree and sign before continuing.")
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            .padding()
        }
        .background(Color(red: 0.10, green: 0.11, blue: 0.14).ignoresSafeArea())
        .navigationTitle("Waiver Form")
    }
}
