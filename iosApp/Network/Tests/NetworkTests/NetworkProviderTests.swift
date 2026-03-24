import Foundation
import Testing
@testable import Network

struct NetworkProviderTests {
    @Test
    func requestBuildsJSONBodyAndDecodesResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let provider = NetworkProvider(session: session)

        let response = try await provider.request(TestTarget.login, as: LoginResponse.self, decoder: JSONDecoder())
        #expect(response.accessToken == "abc")
    }

    @Test
    func requestThrowsStatusCodeErrorForFailedResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let provider = NetworkProvider(session: session)

        await #expect(throws: NetworkError.self) {
            _ = try await provider.request(TestTarget.profile)
        }
    }
}

private enum TestTarget: TargetType {
    case login
    case profile

    var baseURL: URL { URL(string: "https://api.example.com/v1")! }

    var path: String {
        switch self {
        case .login:
            return "/login"
        case .profile:
            return "/profile"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        case .profile:
            return .get
        }
    }

    var task: RequestTask {
        switch self {
        case .login:
            return .requestJSONEncodable(AnyEncodable(LoginPayload(email: "sergey@example.com")))
        case .profile:
            return .requestPlain
        }
    }

    var headers: [String : String] {
        switch self {
        case .login:
            return ["Authorization": "Bearer token"]
        case .profile:
            return [:]
        }
    }
}

private struct LoginPayload: Codable, Sendable {
    let email: String
}

private struct LoginResponse: Codable, Sendable {
    let accessToken: String
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try Self.makeResponse(for: request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func makeResponse(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = try #require(request.url)

        switch url.path {
        case "/v1/login":
            #expect(request.url?.absoluteString == "https://api.example.com/v1/login")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")

            let body = try #require(readBody(from: request))
            let payload = try JSONDecoder().decode(LoginPayload.self, from: body)
            #expect(payload.email == "sergey@example.com")

            return (
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                try JSONEncoder().encode(LoginResponse(accessToken: "abc"))
            )
        case "/v1/profile":
            return (
                HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data("{\"message\":\"Unauthorized\"}".utf8)
            )
        default:
            throw URLError(.badURL)
        }
    }

    private static func readBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }

        return data.isEmpty ? nil : data
    }
}
