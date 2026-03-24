import Foundation

public struct LoadCurrentDateUseCase: Sendable {
    private let repository: HomeRepository

    init(repository: HomeRepository) {
        self.repository = repository
    }

    public func execute() async throws -> Date {
        try await repository.loadCurrentDate()
    }
}
