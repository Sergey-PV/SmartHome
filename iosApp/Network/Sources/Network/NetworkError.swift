import Foundation

public enum NetworkError: LocalizedError, Sendable {
    case invalidResponse
    case emptyResponse
    case requestEncoding(String)
    case transport(String)
    case statusCode(NetworkResponse)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Сервер вернул некорректный ответ."
        case .emptyResponse:
            return "Сервер не вернул данные."
        case let .requestEncoding(message),
             let .transport(message):
            return message
        case let .statusCode(response):
            return "HTTP error: \(response.statusCode)"
        }
    }
}
