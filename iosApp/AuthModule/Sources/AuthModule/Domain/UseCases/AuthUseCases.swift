import Foundation

public struct LoadAuthStateUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute() async throws -> AuthStateSnapshot {
        try await repository.loadState()
    }
}

public struct LoginWithEmailUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute(email: String, password: String) async throws -> AuthStateSnapshot {
        try await repository.login(email: email, password: password)
    }
}

public struct RegisterWithEmailUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute(email: String, password: String, firstName: String?, lastName: String?) async throws -> AuthStateSnapshot {
        try await repository.register(email: email, password: password, firstName: firstName, lastName: lastName)
    }
}

public struct RefreshSessionUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute() async throws -> AuthStateSnapshot {
        try await repository.refreshSession()
    }
}

public struct LoginWithBiometricsUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute() async throws -> AuthStateSnapshot {
        try await repository.loginWithBiometrics()
    }
}

public struct EnableBiometricsUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute() async throws -> AuthStateSnapshot {
        try await repository.enableBiometrics()
    }
}

public struct DisableBiometricsUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute() async throws -> AuthStateSnapshot {
        try await repository.disableBiometrics()
    }
}

public struct LogoutUseCase: Sendable {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func execute(allDevices: Bool) async throws -> AuthStateSnapshot {
        try await repository.logout(allDevices: allDevices)
    }
}
