import Foundation
import Network

enum HomeTarget: TargetType {
    case currentDate(baseURL: URL, accessToken: String)

    var baseURL: URL {
        switch self {
        case let .currentDate(baseURL, _):
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

    var headers: [String : String] {
        switch self {
        case let .currentDate(_, accessToken):
            return [
                "Authorization": "Bearer \(accessToken)",
            ]
        }
    }
}
