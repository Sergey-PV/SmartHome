import Foundation
import Testing
@testable import HomeModule

@MainActor
struct HomeViewModelTests {
    @Test
    func initStartsWithEmptyState() async throws {
        let viewModel = HomeViewModel(
            loadCurrentDateUseCase: LoadCurrentDateUseCase(repository: HomeRepositorySpy())
        )

        #expect(!viewModel.isLoading)
        #expect(viewModel.currentDateText == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadCurrentDateAppliesFormattedValue() async throws {
        let repository = HomeRepositorySpy()
        repository.result = .success(Date(timeIntervalSince1970: 1_711_293_296))

        let viewModel = HomeViewModel(
            loadCurrentDateUseCase: LoadCurrentDateUseCase(repository: repository)
        )

        await viewModel.loadCurrentDate()

        #expect(viewModel.currentDateText != nil)
        #expect(viewModel.errorMessage == nil)
    }
}

private final class HomeRepositorySpy: HomeRepository, @unchecked Sendable {
    var result: Result<Date, Error> = .success(.now)

    func loadCurrentDate() async throws -> Date {
        try result.get()
    }
}
