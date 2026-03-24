import Foundation

public protocol TargetType: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: RequestTask { get }
    var headers: [String: String] { get }
    var sampleData: Data { get }
}

public extension TargetType {
    var task: RequestTask { .requestPlain }
    var headers: [String: String] { [:] }
    var sampleData: Data { Data() }
}
