import Foundation

public enum AuthError: LocalizedError, Equatable, Sendable {
    case validation(String)
    case unauthorized(String)
    case server(code: String, message: String)
    case biometricUnavailable(String)
    case biometricFailed(String)
    case missingBiometricCredential
    case invalidConfiguration(String)
    case transport(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case let .validation(message),
             let .unauthorized(message),
             let .biometricUnavailable(message),
             let .biometricFailed(message),
             let .invalidConfiguration(message),
             let .transport(message),
             let .unknown(message):
            return message
        case let .server(_, message):
            return message
        case .missingBiometricCredential:
            return "Биометрическая сессия не найдена на устройстве."
        }
    }
}
