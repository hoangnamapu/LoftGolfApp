import LocalAuthentication

struct BiometricHelper {

    /// Returns true if Face ID or Touch ID is available and enrolled on this device.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Returns "Face ID", "Touch ID", or nil depending on what the device supports.
    static var biometricType: String? {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return nil }
        return ctx.biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    /// Prompts biometric authentication. Returns true on success, false on failure or user cancellation.
    static func authenticate(reason: String) async -> Bool {
        await withCheckedContinuation { continuation in
            LAContext().evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
