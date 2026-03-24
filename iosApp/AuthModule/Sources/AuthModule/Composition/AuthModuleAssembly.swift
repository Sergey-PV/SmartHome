import Foundation
import Network

public enum AuthModuleAssembly {
    @MainActor
    public static func makeViewModel(
        baseURL: URL = AuthEnvironment.productionBaseURL,
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) -> AuthViewModel {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let provider = NetworkProvider(session: session, encoder: encoder)
        let apiClient = DefaultAuthAPIClient(baseURL: baseURL, provider: provider)
        let credentialStore = KeychainAuthCredentialStore()
        let biometricAuthenticator = LocalBiometricAuthenticator()
        let deviceContextProvider = DefaultDeviceContextProvider(userDefaults: userDefaults)
        let repository = DefaultAuthRepository(
            apiClient: apiClient,
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator,
            deviceContextProvider: deviceContextProvider
        )

        return AuthViewModel(
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

    @MainActor
    public static func makeRootView(
        baseURL: URL = AuthEnvironment.productionBaseURL,
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) -> AuthRootView {
        AuthRootView(
            viewModel: makeViewModel(
                baseURL: baseURL,
                session: session,
                userDefaults: userDefaults
            )
        )
    }
}
