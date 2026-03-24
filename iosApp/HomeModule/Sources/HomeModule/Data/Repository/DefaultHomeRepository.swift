import Foundation
import Network

final class DefaultHomeRepository: HomeRepository, @unchecked Sendable {
    private let apiClient: HomeAPIClient
    private let accessTokenProvider: () -> String?

    init(
        apiClient: HomeAPIClient,
        accessTokenProvider: @escaping () -> String?
    ) {
        self.apiClient = apiClient
        self.accessTokenProvider = accessTokenProvider
    }

    func loadCurrentDate() async throws -> Date {
        guard let accessToken = accessTokenProvider(), !accessToken.isEmpty else {
            throw HomeError.missingAccessToken
        }

        do {
            let response = try await apiClient.getCurrentDate(accessToken: accessToken)
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
