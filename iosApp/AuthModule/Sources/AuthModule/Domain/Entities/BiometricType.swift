import Foundation

public enum BiometricType: String, Codable, CaseIterable, Equatable, Sendable {
    case faceID = "faceId"
    case touchID = "touchId"

    public var displayName: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        }
    }
}

public struct BiometricAvailability: Equatable, Sendable {
    public let isAvailable: Bool
    public let type: BiometricType?

    public init(isAvailable: Bool, type: BiometricType?) {
        self.isAvailable = isAvailable
        self.type = type
    }

    public var title: String {
        type?.displayName ?? "Biometric"
    }

    public static let unavailable = BiometricAvailability(isAvailable: false, type: nil)
}
