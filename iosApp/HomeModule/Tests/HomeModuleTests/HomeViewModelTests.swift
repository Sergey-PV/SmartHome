import Testing
@testable import HomeModule

@MainActor
struct HomeViewModelTests {
    @Test
    func initStartsWithEmptyState() async throws {
        let viewModel = HomeViewModel()

        #expect(!viewModel.isLoading)
        #expect(viewModel.currentDateText == nil)
        #expect(viewModel.errorMessage == nil)
    }
}
