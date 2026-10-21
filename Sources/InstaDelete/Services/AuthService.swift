import LocalAuthentication

enum AuthOutcome: Equatable {
    case success
    case cancelled
    case failed(String)
}

/// Shows the *system* Touch ID / password prompt. No custom UI.
struct AuthService {
    func authenticate(reason: String) async -> AuthOutcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .failed(error?.localizedDescription ?? "This Mac can’t verify your identity.")
        }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return ok ? .success : .failed("Authentication was not approved.")
        } catch let e as LAError where [.userCancel, .systemCancel, .appCancel].contains(e.code) {
            return .cancelled
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
