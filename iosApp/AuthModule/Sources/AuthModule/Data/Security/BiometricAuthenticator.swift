import Foundation
import LocalAuthentication

protocol BiometricAuthenticating: Sendable {
    func availability() -> BiometricAvailability
    func authenticate(reason: String) async throws
}

final class LocalBiometricAuthenticator: BiometricAuthenticating, @unchecked Sendable {
    func availability() -> BiometricAvailability {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        guard canEvaluate else {
            return .unavailable
        }

        switch context.biometryType {
        case .faceID:
            return BiometricAvailability(isAvailable: true, type: .faceID)
        case .touchID:
            return BiometricAvailability(isAvailable: true, type: .touchID)
        default:
            return .unavailable
        }
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Использовать пароль"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthError.biometricUnavailable("Face ID / Touch ID недоступны на этом устройстве.")
        }

        do {
            try await withCheckedThrowingContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evaluationError in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        let message = evaluationError?.localizedDescription ?? "Биометрическая проверка не была пройдена."
                        continuation.resume(throwing: AuthError.biometricFailed(message))
                    }
                }
            }
        } catch let authError as AuthError {
            throw authError
        } catch {
            throw AuthError.biometricFailed(error.localizedDescription)
        }
    }
}
