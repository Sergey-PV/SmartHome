import Foundation

public struct AuthTokens: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let refreshExpiresIn: Int?

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresIn: Int,
        refreshExpiresIn: Int?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshExpiresIn = refreshExpiresIn
    }
}

public struct AuthSession: Equatable, Sendable {
    public let tokens: AuthTokens
    public let user: User
    public let biometricAvailable: Bool
    public let biometricEnabled: Bool

    public init(tokens: AuthTokens, user: User, biometricAvailable: Bool, biometricEnabled: Bool) {
        self.tokens = tokens
        self.user = user
        self.biometricAvailable = biometricAvailable
        self.biometricEnabled = biometricEnabled
    }
}

public struct AuthStateSnapshot: Equatable, Sendable {
    public let isAuthenticated: Bool
    public let accessToken: String?
    public let user: User?
    public let biometricAvailability: BiometricAvailability
    public let biometricEnabled: Bool
    public let canLoginWithBiometrics: Bool
    public let currentDeviceId: String
    public let sessionStartedAt: Date?

    public init(
        isAuthenticated: Bool,
        accessToken: String?,
        user: User?,
        biometricAvailability: BiometricAvailability,
        biometricEnabled: Bool,
        canLoginWithBiometrics: Bool,
        currentDeviceId: String,
        sessionStartedAt: Date?
    ) {
        self.isAuthenticated = isAuthenticated
        self.accessToken = accessToken
        self.user = user
        self.biometricAvailability = biometricAvailability
        self.biometricEnabled = biometricEnabled
        self.canLoginWithBiometrics = canLoginWithBiometrics
        self.currentDeviceId = currentDeviceId
        self.sessionStartedAt = sessionStartedAt
    }

    public static func signedOut(
        availability: BiometricAvailability,
        currentDeviceId: String,
        canLoginWithBiometrics: Bool
    ) -> AuthStateSnapshot {
        AuthStateSnapshot(
            isAuthenticated: false,
            accessToken: nil,
            user: nil,
            biometricAvailability: availability,
            biometricEnabled: false,
            canLoginWithBiometrics: canLoginWithBiometrics,
            currentDeviceId: currentDeviceId,
            sessionStartedAt: nil
        )
    }
}
