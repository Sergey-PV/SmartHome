import Foundation

public enum ParameterEncoding: Sendable {
    case url
    case json
}

public enum RequestTask: Sendable {
    case requestPlain
    case requestJSONEncodable(AnyEncodable)
    case requestParameters([String: String], encoding: ParameterEncoding)
    case requestComposite(body: AnyEncodable, urlParameters: [String: String])
}
