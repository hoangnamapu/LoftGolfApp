import SwiftUI

// MARK: - Model you can reuse with USchedule BookingModel.CreditCard
struct PaymentCardFormData: Equatable, Codable {
    var nameOnCard: String = ""
    var number: String = ""          // digits only in storage
    var expMonth: Int? = nil          // 1...12
    var expYear: Int? = nil           // four-digit year
    var cvv: String = ""             // digits only
    var billingAddress: String = ""
    var billingCity: String = ""
    var billingState: String = ""     // 2-letter (e.g., AZ)
    var billingZip: String = ""       // 5(-4) digits
}

// MARK: - Reusable View
struct PaymentCardFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var form = PaymentCardFormData()
    let initial: PaymentCardFormData?
    let onSave: (PaymentCardFormData) -> Void

    @State private var showErrors = false
    @State private var errorText: String?
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name, number, month, year, cvv, address, city, state, zip }

    // Years: current -> +15
    private var yearOptions: [Int] {
        let y = Calendar.current.component(.year, from: .now)
        return Array(y...(y+15))
    }

    // Months with labels like "1 - Jan"
    private let monthLabels: [(value: Int, label: String)] = [
        (1, "1 - Jan"),(2, "2 - Feb"),(3, "3 - Mar"),(4, "4 - Apr"),(5, "5 - May"),(6, "6 - Jun"),
        (7, "7 - Jul"),(8, "8 - Aug"),(9, "9 - Sep"),(10, "10 - Oct"),(11, "11 - Nov"),(12, "12 - Dec")
    ]

    init(initial: PaymentCardFormData? = nil, onSave: @escaping (PaymentCardFormData) -> Void) {
        self.initial = initial
        self.onSave = onSave
        // _form is @State; will set in .onAppear
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Name on Card", text: $form.nameOnCard)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)

                    TextField("Card Number", text: Binding(
                        get: { formatCardForDisplay(form.number) },
                        set: { form.number = digitsOnly($0) }
                    ))
                    .keyboardType(.numberPad)
                    .textContentType(.creditCardNumber)
                    .focused($focusedField, equals: .number)

                    HStack {
                        Picker("Expiration Month", selection: Binding(
                            get: { form.expMonth ?? 0 },
                            set: { form.expMonth = $0 == 0 ? nil : $0 }
                        )) {
                            Text("Month").tag(0)
                            ForEach(monthLabels, id: \.value) { m in
                                Text(m.label).tag(m.value)
                            }
                        }
                        .focused($focusedField, equals: .month)

                        Picker("Expiration Year", selection: Binding(
                            get: { form.expYear ?? 0 },
                            set: { form.expYear = $0 == 0 ? nil : $0 }
                        )) {
                            Text("Year").tag(0)
                            ForEach(yearOptions, id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .focused($focusedField, equals: .year)
                    }

                    TextField("Security Code", text: $form.cvv)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .cvv)
                        .onChange(of: form.cvv) { form.cvv = digitsOnly(form.cvv).prefix(4).description }
                }

                Section("Billing") {
                    TextField("Billing Address", text: $form.billingAddress)
                        .textContentType(.fullStreetAddress)
                        .focused($focusedField, equals: .address)

                    TextField("Billing City", text: $form.billingCity)
                        .textContentType(.addressCity)
                        .focused($focusedField, equals: .city)

                    HStack {
                        TextField("State (e.g., AZ)", text: $form.billingState)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .state)
                            .onChange(of: form.billingState) { new in
                                form.billingState = String(new.uppercased().prefix(2))
                            }

                        TextField("ZIP", text: $form.billingZip)
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                            .focused($focusedField, equals: .zip)
                            .onChange(of: form.billingZip) { form.billingZip = digitsOnly(form.billingZip).prefix(10).description }
                    }
                }

                if let e = errorText, showErrors {
                    Section { Text(e).foregroundStyle(.red) }
                }

                Section {
                    Button(action: saveTapped) {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
            .navigationTitle("New Credit Card Details")
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } } }
            .onAppear {
                if let initial { self.form = initial }
            }
        }
    }

    // MARK: - Validation
    private var isValid: Bool {
        // Basic checks
        guard !form.nameOnCard.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard isLikelyCardNumber(form.number), luhnCheck(form.number) else { return false }
        guard let m = form.expMonth, (1...12).contains(m) else { return false }
        guard let y = form.expYear, yearOptions.contains(y) else { return false }
        guard !isExpired(month: m, year: y) else { return false }
        guard (3...4).contains(form.cvv.count) else { return false }
        guard !form.billingAddress.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !form.billingCity.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard form.billingState.count == 2 else { return false }
        guard (5...10).contains(form.billingZip.count) else { return false }
        return true
    }

    private func saveTapped() {
        showErrors = true
        guard isValid else {
            errorText = explainFirstError() ?? "Please complete the form."
            return
        }
        onSave(form)
        dismiss()
    }

    private func explainFirstError() -> String? {
        if form.nameOnCard.trimmingCharacters(in: .whitespaces).isEmpty { return "Name on card is required." }
        if !isLikelyCardNumber(form.number) { return "Card number must be 13–19 digits." }
        if !luhnCheck(form.number) { return "Card number failed verification (check digits)." }
        if form.expMonth == nil { return "Select an expiration month." }
        if form.expYear == nil { return "Select an expiration year." }
        if let m = form.expMonth, let y = form.expYear, isExpired(month: m, year: y) { return "Card is expired." }
        if !(3...4).contains(form.cvv.count) { return "Security code should be 3–4 digits." }
        if form.billingAddress.trimmingCharacters(in: .whitespaces).isEmpty { return "Billing address is required." }
        if form.billingCity.trimmingCharacters(in: .whitespaces).isEmpty { return "Billing city is required." }
        if form.billingState.count != 2 { return "Use 2-letter state code (e.g., AZ)." }
        if !(5...10).contains(form.billingZip.count) { return "Enter a valid ZIP code." }
        return nil
    }

    // MARK: - Helpers
    private func digitsOnly(_ s: String) -> String {
        s.filter { $0.isNumber }
    }

    private func formatCardForDisplay(_ digits: String) -> String {
        let d = digitsOnly(digits)
        // Group as 4-4-4-4…
        return stride(from: 0, to: d.count, by: 4).map { i in
            let start = d.index(d.startIndex, offsetBy: i)
            let end   = d.index(start, offsetBy: min(4, d.distance(from: start, to: d.endIndex)), limitedBy: d.endIndex) ?? d.endIndex
            return String(d[start..<end])
        }.joined(separator: " ")
    }

    private func isLikelyCardNumber(_ digits: String) -> Bool {
        let n = digits.count
        return (13...19).contains(n)
    }

    private func luhnCheck(_ digits: String) -> Bool {
        // https://en.wikipedia.org/wiki/Luhn_algorithm
        var sum = 0
        let rev = digits.reversed().map { Int(String($0)) ?? 0 }
        for (idx, d) in rev.enumerated() {
            if idx % 2 == 1 {
                var v = d * 2
                if v > 9 { v -= 9 }
                sum += v
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }

    private func isExpired(month m: Int, year y: Int) -> Bool {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = 1
        let cal = Calendar.current
        guard let firstOfMonth = cal.date(from: comps),
              let endOfMonth = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth) else { return false }
        return endOfMonth < Date()
    }
}

// MARK: - Preview / Example Wiring
struct PaymentCardFormView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentCardFormView(initial: nil) { data in
            print("Saved:", data)
        }
    }
}
