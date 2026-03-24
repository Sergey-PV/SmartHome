import Testing
@testable import AuthModule

@MainActor
struct AuthViewModelTests {
    @Test
    func loadAppliesSignedInSnapshot() async throws {
        let repository = AuthRepositorySpy()
        repository.loadStateResult = .success(
            AuthStateSnapshot(
                isAuthenticated: true,
                accessToken: "access-token-1",
                user: User(
                    id: "1",
                    email: "sergey@example.com",
                    firstName: "Sergey",
                    lastName: "Parfenchyk",
                    emailVerified: true,
                    createdAt: nil
                ),
                biometricAvailability: BiometricAvailability(isAvailable: true, type: .faceID),
                biometricEnabled: true,
                canLoginWithBiometrics: true,
                currentDeviceId: "device-1",
                sessionStartedAt: nil
            )
        )

        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        #expect(viewModel.isAuthenticated)
        #expect(viewModel.accessToken == "access-token-1")
        #expect(viewModel.currentUser?.email == "sergey@example.com")
        #expect(viewModel.biometricEnabled)
        #expect(viewModel.canLoginWithBiometrics)
    }

    @Test
    func loginShowsValidationError() async throws {
        let repository = AuthRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.email = "wrong-email"
        viewModel.password = "123"

        await viewModel.login()

        #expect(viewModel.errorMessage == "Введите корректный email.")
        #expect(repository.loginCallCount == 0)
    }

    @Test
    func registerCallsRepositoryAndAuthenticatesUser() async throws {
        let repository = AuthRepositorySpy()
        repository.registerResult = .success(
            AuthStateSnapshot(
                isAuthenticated: true,
                accessToken: "access-token-2",
                user: User(
                    id: "2",
                    email: "new@example.com",
                    firstName: "New",
                    lastName: "User",
                    emailVerified: true,
                    createdAt: nil
                ),
                biometricAvailability: .unavailable,
                biometricEnabled: false,
                canLoginWithBiometrics: false,
                currentDeviceId: "device-2",
                sessionStartedAt: nil
            )
        )

        let viewModel = makeViewModel(repository: repository)
        viewModel.mode = .register
        viewModel.email = "new@example.com"
        viewModel.password = "StrongPassword123!"
        viewModel.firstName = "New"
        viewModel.lastName = "User"

        await viewModel.register()

        #expect(viewModel.isAuthenticated)
        #expect(viewModel.accessToken == "access-token-2")
        #expect(viewModel.currentUser?.email == "new@example.com")
        #expect(repository.registerCallCount == 1)
    }

    @Test
    func logoutClearsAuthenticatedState() async throws {
        let repository = AuthRepositorySpy()
        repository.logoutResult = .success(
            .signedOut(
                availability: BiometricAvailability(isAvailable: true, type: .faceID),
                currentDeviceId: "device-1",
                canLoginWithBiometrics: false
            )
        )

        let viewModel = makeViewModel(repository: repository)
        await viewModel.logout()

        #expect(!viewModel.isAuthenticated)
        #expect(viewModel.accessToken == nil)
        #expect(viewModel.currentUser == nil)
        #expect(repository.logoutCallCount == 1)
    }

    private func makeViewModel(repository: some AuthRepository) -> AuthViewModel {
        AuthViewModel(
            loadAuthStateUseCase: LoadAuthStateUseCase(repository: repository),
            loginWithEmailUseCase: LoginWithEmailUseCase(repository: repository),
            registerWithEmailUseCase: RegisterWithEmailUseCase(repository: repository),
            refreshSessionUseCase: RefreshSessionUseCase(repository: repository),
            loginWithBiometricsUseCase: LoginWithBiometricsUseCase(repository: repository),
            enableBiometricsUseCase: EnableBiometricsUseCase(repository: repository),
            disableBiometricsUseCase: DisableBiometricsUseCase(repository: repository),
            logoutUseCase: LogoutUseCase(repository: repository)
        )
    }
}

private final class AuthRepositorySpy: AuthRepository, @unchecked Sendable {
    var loadStateResult: Result<AuthStateSnapshot, Error> = .success(
        .signedOut(
            availability: .unavailable,
            currentDeviceId: "device-0",
            canLoginWithBiometrics: false
        )
    )
    var loginResult: Result<AuthStateSnapshot, Error> = .failure(AuthError.validation("Введите корректный email."))
    var registerResult: Result<AuthStateSnapshot, Error> = .failure(AuthError.validation("Введите корректный email."))
    var refreshResult: Result<AuthStateSnapshot, Error> = .success(
        .signedOut(
            availability: .unavailable,
            currentDeviceId: "device-0",
            canLoginWithBiometrics: false
        )
    )
    var biometricLoginResult: Result<AuthStateSnapshot, Error> = .success(
        .signedOut(
            availability: .unavailable,
            currentDeviceId: "device-0",
            canLoginWithBiometrics: false
        )
    )
    var enableBiometricsResult: Result<AuthStateSnapshot, Error> = .success(
        .signedOut(
            availability: .unavailable,
            currentDeviceId: "device-0",
            canLoginWithBiometrics: false
        )
    )
    var disableBiometricsResult: Result<AuthStateSnapshot, Error> = .success(
        .signedOut(
            availability: .unavailable,
            currentDeviceId: "device-0",
            canLoginWithBiometrics: false
        )
    )
    var logoutResult: Result<AuthStateSnapshot, Error> = .success(
        .signedOut(
            availability: .unavailable,
            currentDeviceId: "device-0",
            canLoginWithBiometrics: false
        )
    )

    var loginCallCount = 0
    var registerCallCount = 0
    var logoutCallCount = 0

    func loadState() async throws -> AuthStateSnapshot {
        try loadStateResult.get()
    }

    func login(email: String, password: String) async throws -> AuthStateSnapshot {
        loginCallCount += 1
        return try loginResult.get()
    }

    func register(email: String, password: String, firstName: String?, lastName: String?) async throws -> AuthStateSnapshot {
        registerCallCount += 1
        return try registerResult.get()
    }

    func refreshSession() async throws -> AuthStateSnapshot {
        try refreshResult.get()
    }

    func loginWithBiometrics() async throws -> AuthStateSnapshot {
        try biometricLoginResult.get()
    }

    func enableBiometrics() async throws -> AuthStateSnapshot {
        try enableBiometricsResult.get()
    }

    func disableBiometrics() async throws -> AuthStateSnapshot {
        try disableBiometricsResult.get()
    }

    func logout(allDevices: Bool) async throws -> AuthStateSnapshot {
        logoutCallCount += 1
        return try logoutResult.get()
    }
}
