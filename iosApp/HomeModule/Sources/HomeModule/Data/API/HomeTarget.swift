import Foundation
import Network

enum HomeTarget: TargetType {
    case currentDate(baseURL: URL)

    var baseURL: URL {
        switch self {
        case let .currentDate(baseURL):
            return baseURL
        }
    }

    var path: String {
        switch self {
        case .currentDate:
            return "/home/current-date"
        }
    }

    var method: HTTPMethod { .get }

    var task: RequestTask { .requestPlain }

    var requiresAuthorization: Bool { true }
}
