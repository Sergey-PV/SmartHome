import Foundation
import AuthModule
import Network

public enum HomeModuleAssembly {
    @MainActor
    public static func makeViewModel(
        baseURL: URL = AuthEnvironment.productionBaseURL,
        provider: any NetworkProviding
    ) -> HomeViewModel {
        let apiClient = DefaultHomeAPIClient(baseURL: baseURL, provider: provider)
        let repository = DefaultHomeRepository(apiClient: apiClient)

        return HomeViewModel(
            loadCurrentDateUseCase: LoadCurrentDateUseCase(repository: repository)
        )
    }

    @MainActor
    public static func makeRootView(
        authViewModel: AuthViewModel,
        baseURL: URL = AuthEnvironment.productionBaseURL,
        provider: any NetworkProviding
    ) -> HomeRootView {
        HomeRootView(
            authViewModel: authViewModel,
            viewModel: makeViewModel(
                baseURL: baseURL,
                provider: provider
            )
        )
    }
}
