import SwiftUI
import WebKit

struct AccountInformationView: View {
    @State private var webId = UUID()

    var body: some View {
        WebView(url: URL(string: "https://clients.uschedule.com/loftgolfstudios/customerprofile/details")!)
            .id(webId)
            .navigationTitle("Account Information")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { webId = UUID() }
    }
}
