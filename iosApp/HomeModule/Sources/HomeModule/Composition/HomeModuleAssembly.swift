import Foundation
import AuthModule
import Network

public enum HomeModuleAssembly {
    @MainActor
    public static func makeViewModel(
        baseURL: URL = AuthEnvironment.productionBaseURL,
        session: URLSession = .shared,
        accessTokenProvider: @escaping () -> String?
    ) -> HomeViewModel {
        let provider = NetworkProvider(session: session)
        let apiClient = DefaultHomeAPIClient(baseURL: baseURL, provider: provider)
        let repository = DefaultHomeRepository(
            apiClient: apiClient,
            accessTokenProvider: accessTokenProvider
        )

        return HomeViewModel(
            loadCurrentDateUseCase: LoadCurrentDateUseCase(repository: repository)
        )
    }

    @MainActor
    public static func makeRootView(
        authViewModel: AuthViewModel,
        baseURL: URL = AuthEnvironment.productionBaseURL,
        session: URLSession = .shared
    ) -> HomeRootView {
        HomeRootView(
            authViewModel: authViewModel,
            viewModel: makeViewModel(
                baseURL: baseURL,
                session: session,
                accessTokenProvider: { authViewModel.accessToken }
            )
        )
    }
}
