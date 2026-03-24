import Foundation

enum HomeError: LocalizedError, Equatable, Sendable {
    case missingAccessToken
    case unauthorized
    case invalidResponse
    case server(statusCode: Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken, .unauthorized:
            return "Сессия не найдена. Выполните вход заново."
        case .invalidResponse:
            return "Сервер вернул некорректный ответ."
        case let .server(statusCode):
            return "Не удалось загрузить дату. Код ответа: \(statusCode)."
        case let .transport(message):
            return message
        }
    }
}
