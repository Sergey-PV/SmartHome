import Foundation
import Network

protocol HomeAPIClient: Sendable {
    func getCurrentDate() async throws -> CurrentDateResponseDTO
}

final class DefaultHomeAPIClient: HomeAPIClient, @unchecked Sendable {
    private let baseURL: URL
    private let provider: any NetworkProviding

    init(baseURL: URL, provider: any NetworkProviding) {
        self.baseURL = baseURL
        self.provider = provider
    }

    func getCurrentDate() async throws -> CurrentDateResponseDTO {
        try await provider.request(
            HomeTarget.currentDate(baseURL: baseURL),
            as: CurrentDateResponseDTO.self,
            decoder: makeDecoder()
        )
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
