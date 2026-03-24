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

    @Test
    func authenticatedProviderRefreshesAndRetriesAfterUnauthorized() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let baseProvider = NetworkProvider(session: session)
        let provider = AuthenticatedNetworkProvider(
            baseProvider: baseProvider,
            accessTokenProvider: { URLProtocolStub.currentAccessToken },
            refreshAction: {
                URLProtocolStub.currentAccessToken = "new-token"
                return "new-token"
            },
            logoutAction: {}
        )

        URLProtocolStub.reset()

        let response = try await provider.request(
            TestTarget.secureProfile,
            as: LoginResponse.self,
            decoder: JSONDecoder()
        )

        #expect(response.accessToken == "secure")
        #expect(URLProtocolStub.secureProfileRequestCount >= 2)
    }

    @Test
    func authenticatedProviderLogsOutWhenRefreshFails() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let baseProvider = NetworkProvider(session: session)
        let logoutFlag = LogoutFlag()
        let provider = AuthenticatedNetworkProvider(
            baseProvider: baseProvider,
            accessTokenProvider: { URLProtocolStub.currentAccessToken },
            refreshAction: {
                throw NetworkError.unauthorized
            },
            logoutAction: {
                await logoutFlag.markLoggedOut()
            }
        )

        URLProtocolStub.reset()

        await #expect(throws: NetworkError.self) {
            _ = try await provider.request(TestTarget.secureProfile)
        }

        let didLogout = await logoutFlag.didLogout
        #expect(didLogout)
    }
}

private enum TestTarget: TargetType {
    case login
    case profile
    case secureProfile

    var baseURL: URL { URL(string: "https://api.example.com/v1")! }

    var path: String {
        switch self {
        case .login:
            return "/login"
        case .profile:
            return "/profile"
        case .secureProfile:
            return "/secure-profile"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        case .profile, .secureProfile:
            return .get
        }
    }

    var task: RequestTask {
        switch self {
        case .login:
            return .requestJSONEncodable(AnyEncodable(LoginPayload(email: "sergey@example.com")))
        case .profile, .secureProfile:
            return .requestPlain
        }
    }

    var headers: [String : String] {
        switch self {
        case .login:
            return ["Authorization": "Bearer token"]
        case .profile, .secureProfile:
            return [:]
        }
    }

    var requiresAuthorization: Bool {
        switch self {
        case .secureProfile:
            return true
        case .login, .profile:
            return false
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
    nonisolated(unsafe) static var currentAccessToken = "expired-token"
    nonisolated(unsafe) static var secureProfileRequestCount = 0

    static func reset() {
        currentAccessToken = "expired-token"
        secureProfileRequestCount = 0
    }

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
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")

            let body = try #require(readBody(from: request))
            let payload = try JSONDecoder().decode(LoginPayload.self, from: body)
            #expect(payload.email == "sergey@example.com")

            return (
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                try JSONEncoder().encode(LoginResponse(accessToken: "abc"))
            )
        case "/v1/profile":
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            return (
                HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data("{\"message\":\"Unauthorized\"}".utf8)
            )
        case "/v1/secure-profile":
            secureProfileRequestCount += 1

            if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-token" {
                return (
                    HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                    Data("{\"message\":\"Unauthorized\"}".utf8)
                )
            }

            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            return (
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                try JSONEncoder().encode(LoginResponse(accessToken: "secure"))
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

private actor LogoutFlag {
    private(set) var didLogout = false

    func markLoggedOut() {
        didLogout = true
    }
}
