import Foundation

public protocol NetworkProviding: Sendable {
    func request(_ target: any TargetType) async throws -> NetworkResponse
    func request<T: Decodable>(
        _ target: any TargetType,
        as type: T.Type,
        decoder: JSONDecoder
    ) async throws -> T
}

public final class NetworkProvider: NetworkProviding, @unchecked Sendable {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let defaultHeaders: [String: String]

    public init(
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        defaultHeaders: [String: String] = ["Accept": "application/json"]
    ) {
        self.session = session
        self.encoder = encoder
        self.defaultHeaders = defaultHeaders
    }

    public func request(_ target: any TargetType) async throws -> NetworkResponse {
        let request = try buildRequest(for: target)
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        let networkResponse = NetworkResponse(statusCode: httpResponse.statusCode, data: data)

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw NetworkError.statusCode(networkResponse)
        }

        return networkResponse
    }

    public func request<T: Decodable>(
        _ target: any TargetType,
        as type: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let response = try await request(target)

        guard !response.data.isEmpty else {
            throw NetworkError.emptyResponse
        }

        do {
            return try response.decode(type, decoder: decoder)
        } catch {
            throw NetworkError.transport("Не удалось обработать ответ сервера.")
        }
    }

    private func buildRequest(for target: any TargetType) throws -> URLRequest {
        var components = URLComponents(url: target.baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        components?.path = "/" + [basePath, target.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        var queryItems = components?.queryItems ?? []
        var httpBody: Data?

        switch target.task {
        case .requestPlain:
            break
        case let .requestJSONEncodable(body):
            httpBody = try encode(body)
        case let .requestParameters(parameters, encoding):
            switch encoding {
            case .url:
                queryItems.append(contentsOf: parameters.map { URLQueryItem(name: $0.key, value: $0.value) })
            case .json:
                httpBody = try encode(parameters)
            }
        case let .requestComposite(body, urlParameters):
            queryItems.append(contentsOf: urlParameters.map { URLQueryItem(name: $0.key, value: $0.value) })
            httpBody = try encode(body)
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw NetworkError.requestEncoding("Не удалось сформировать URL запроса.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = target.method.rawValue
        request.httpBody = httpBody

        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        for (key, value) in target.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if httpBody != nil, request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw NetworkError.requestEncoding("Не удалось закодировать тело запроса.")
        }
    }
}
