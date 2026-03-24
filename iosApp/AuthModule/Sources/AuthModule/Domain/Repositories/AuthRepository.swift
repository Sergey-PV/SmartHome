import Foundation

public protocol AuthRepository: Sendable {
    func loadState() async throws -> AuthStateSnapshot
    func login(email: String, password: String) async throws -> AuthStateSnapshot
    func register(email: String, password: String, firstName: String?, lastName: String?) async throws -> AuthStateSnapshot
    func refreshSession() async throws -> AuthStateSnapshot
    func refreshAccessToken() async throws -> AuthTokens
    func loginWithBiometrics() async throws -> AuthStateSnapshot
    func enableBiometrics() async throws -> AuthStateSnapshot
    func disableBiometrics() async throws -> AuthStateSnapshot
    func logout(allDevices: Bool) async throws -> AuthStateSnapshot
}
