import Foundation
import Network

final class DefaultHomeRepository: HomeRepository, @unchecked Sendable {
    private let apiClient: HomeAPIClient

    init(apiClient: HomeAPIClient) {
        self.apiClient = apiClient
    }

    func loadCurrentDate() async throws -> Date {
        do {
            let response = try await apiClient.getCurrentDate()
            return response.currentDate
        } catch {
            throw map(error)
        }
    }

    private func map(_ error: Error) -> HomeError {
        if let homeError = error as? HomeError {
            return homeError
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .unauthorized
            case .invalidResponse:
                return .invalidResponse
            case let .statusCode(response):
                if response.statusCode == 401 {
                    return .unauthorized
                }
                return .server(statusCode: response.statusCode)
            case .emptyResponse:
                return .invalidResponse
            case let .requestEncoding(message),
                 let .transport(message):
                return .transport(message)
            }
        }

        return .transport(error.localizedDescription)
    }
}
