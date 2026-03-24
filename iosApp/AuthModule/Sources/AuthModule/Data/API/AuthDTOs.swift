import Foundation

struct DeviceContext: Codable, Equatable, Sendable {
    let deviceId: String
    let platform: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let deviceName: String
}

struct BiometricCredential: Codable, Equatable, Sendable {
    let token: String
    let deviceId: String
    let biometricType: BiometricType
}

struct LoginRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
    let device: DeviceInfoDTO
}

struct RegisterRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
    let device: DeviceInfoDTO
}

struct DeviceInfoDTO: Encodable, Sendable {
    let deviceId: String
    let platform: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
}

struct RefreshTokenRequestDTO: Encodable, Sendable {
    let refreshToken: String
    let deviceId: String
}

struct LogoutRequestDTO: Encodable, Sendable {
    let refreshToken: String?
    let deviceId: String?
}

struct EnableBiometricRequestDTO: Encodable, Sendable {
    let deviceId: String
    let biometricType: String
    let deviceName: String
}

struct EnableBiometricResponseDTO: Decodable, Sendable {
    let biometricEnabled: Bool
    let biometricToken: String
    let issuedAt: Date?
    let expiresAt: Date?
}

struct BiometricLoginRequestDTO: Encodable, Sendable {
    let biometricToken: String
    let deviceId: String
}

struct DisableBiometricRequestDTO: Encodable, Sendable {
    let deviceId: String
}

struct AuthSessionResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshExpiresIn: Int?
    let user: UserDTO
    let biometricAvailable: Bool
    let biometricEnabled: Bool
}

struct RefreshTokenResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshExpiresIn: Int?
}

struct SessionInfoResponseDTO: Decodable, Sendable {
    let authenticated: Bool
    let user: UserDTO?
    let biometricEnabled: Bool
    let currentDeviceId: String?
    let sessionStartedAt: Date?
}

struct UserDTO: Decodable, Sendable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let emailVerified: Bool
    let createdAt: Date?
}

struct ErrorResponseDTO: Decodable, Sendable {
    let code: String
    let message: String
    let details: [String: String]?
}
