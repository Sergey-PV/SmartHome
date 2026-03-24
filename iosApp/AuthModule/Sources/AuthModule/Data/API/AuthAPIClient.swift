import Foundation
import Network

protocol AuthAPIClient: Sendable {
    func login(request: LoginRequestDTO) async throws -> AuthSessionResponseDTO
    func register(request: RegisterRequestDTO) async throws -> AuthSessionResponseDTO
    func refresh(request: RefreshTokenRequestDTO) async throws -> RefreshTokenResponseDTO
    func logout(accessToken: String, request: LogoutRequestDTO?) async throws
    func logoutAll(accessToken: String) async throws
    func enableBiometric(accessToken: String, request: EnableBiometricRequestDTO) async throws -> EnableBiometricResponseDTO
    func loginWithBiometric(request: BiometricLoginRequestDTO) async throws -> AuthSessionResponseDTO
    func disableBiometric(accessToken: String, request: DisableBiometricRequestDTO) async throws
    func getSession(accessToken: String) async throws -> SessionInfoResponseDTO
    func getCurrentUser(accessToken: String) async throws -> UserDTO
}

final class DefaultAuthAPIClient: AuthAPIClient, @unchecked Sendable {
    private let baseURL: URL
    private let provider: any NetworkProviding

    init(baseURL: URL, provider: any NetworkProviding) {
        self.baseURL = baseURL
        self.provider = provider
    }

    func login(request: LoginRequestDTO) async throws -> AuthSessionResponseDTO {
        try await provider.request(
            AuthTarget.login(baseURL: baseURL, request: request),
            as: AuthSessionResponseDTO.self,
            decoder: makeDecoder()
        )
    }

    func register(request: RegisterRequestDTO) async throws -> AuthSessionResponseDTO {
        try await provider.request(
            AuthTarget.register(baseURL: baseURL, request: request),
            as: AuthSessionResponseDTO.self,
            decoder: makeDecoder()
        )
    }

    func refresh(request: RefreshTokenRequestDTO) async throws -> RefreshTokenResponseDTO {
        try await provider.request(
            AuthTarget.refresh(baseURL: baseURL, request: request),
            as: RefreshTokenResponseDTO.self,
            decoder: makeDecoder()
        )
    }

    func logout(accessToken: String, request: LogoutRequestDTO?) async throws {
        _ = try await provider.request(AuthTarget.logout(baseURL: baseURL, accessToken: accessToken, request: request))
    }

    func logoutAll(accessToken: String) async throws {
        _ = try await provider.request(AuthTarget.logoutAll(baseURL: baseURL, accessToken: accessToken))
    }

    func enableBiometric(accessToken: String, request: EnableBiometricRequestDTO) async throws -> EnableBiometricResponseDTO {
        try await provider.request(
            AuthTarget.enableBiometric(baseURL: baseURL, accessToken: accessToken, request: request),
            as: EnableBiometricResponseDTO.self,
            decoder: makeDecoder()
        )
    }

    func loginWithBiometric(request: BiometricLoginRequestDTO) async throws -> AuthSessionResponseDTO {
        try await provider.request(
            AuthTarget.loginWithBiometric(baseURL: baseURL, request: request),
            as: AuthSessionResponseDTO.self,
            decoder: makeDecoder()
        )
    }

    func disableBiometric(accessToken: String, request: DisableBiometricRequestDTO) async throws {
        _ = try await provider.request(
            AuthTarget.disableBiometric(baseURL: baseURL, accessToken: accessToken, request: request)
        )
    }

    func getSession(accessToken: String) async throws -> SessionInfoResponseDTO {
        try await provider.request(
            AuthTarget.session(baseURL: baseURL, accessToken: accessToken),
            as: SessionInfoResponseDTO.self,
            decoder: makeDecoder()
        )
    }

    func getCurrentUser(accessToken: String) async throws -> UserDTO {
        try await provider.request(
            AuthTarget.currentUser(baseURL: baseURL, accessToken: accessToken),
            as: UserDTO.self,
            decoder: makeDecoder()
        )
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
