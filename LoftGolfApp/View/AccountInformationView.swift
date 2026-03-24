import SwiftUI
import WebKit

struct AccountInformationView: View {
    var body: some View {
        WebView(url: URL(string: "https://clients.uschedule.com/loftgolfstudios/customerprofile/details")!)
            .navigationTitle("Account Information")
            .navigationBarTitleDisplayMode(.inline)
    }
}
