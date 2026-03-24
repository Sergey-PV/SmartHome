import Foundation

public final class AuthenticatedNetworkProvider: NetworkProviding, @unchecked Sendable {
    private let baseProvider: any NetworkProviding
    private let accessTokenProvider: @Sendable () async -> String?
    private let refreshAction: @Sendable () async throws -> String
    private let logoutAction: @Sendable () async -> Void
    private let refreshCoordinator = RefreshCoordinator()

    public init(
        baseProvider: any NetworkProviding,
        accessTokenProvider: @escaping @Sendable () async -> String?,
        refreshAction: @escaping @Sendable () async throws -> String,
        logoutAction: @escaping @Sendable () async -> Void
    ) {
        self.baseProvider = baseProvider
        self.accessTokenProvider = accessTokenProvider
        self.refreshAction = refreshAction
        self.logoutAction = logoutAction
    }

    public func request(_ target: any TargetType) async throws -> NetworkResponse {
        guard target.requiresAuthorization else {
            return try await baseProvider.request(target)
        }

        return try await requestAuthorized(target)
    }

    public func request<T: Decodable>(
        _ target: any TargetType,
        as type: T.Type,
        decoder: JSONDecoder
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

    private func requestAuthorized(_ target: any TargetType) async throws -> NetworkResponse {
        let accessToken = try await currentAccessToken()

        do {
            return try await baseProvider.request(AuthorizedTarget(target: target, accessToken: accessToken))
        } catch let error as NetworkError {
            guard shouldAttemptRefresh(for: error) else {
                throw error
            }

            do {
                let refreshedToken = try await refreshCoordinator.refresh(using: refreshAction)
                return try await baseProvider.request(AuthorizedTarget(target: target, accessToken: refreshedToken))
            } catch {
                await logoutAction()
                throw NetworkError.unauthorized
            }
        } catch {
            throw error
        }
    }

    private func currentAccessToken() async throws -> String {
        guard let accessToken = await accessTokenProvider(), !accessToken.isEmpty else {
            throw NetworkError.unauthorized
        }
        return accessToken
    }

    private func shouldAttemptRefresh(for error: NetworkError) -> Bool {
        switch error {
        case .unauthorized:
            return true
        case let .statusCode(response):
            return response.statusCode == 401
        default:
            return false
        }
    }
}

private struct AuthorizedTarget: TargetType {
    let target: any TargetType
    let accessToken: String

    var baseURL: URL { target.baseURL }
    var path: String { target.path }
    var method: HTTPMethod { target.method }
    var task: RequestTask { target.task }
    var sampleData: Data { target.sampleData }

    var headers: [String : String] {
        var headers = target.headers
        headers["Authorization"] = "Bearer \(accessToken)"
        return headers
    }
}

private actor RefreshCoordinator {
    private var refreshTask: Task<String, Error>?

    func refresh(using action: @escaping @Sendable () async throws -> String) async throws -> String {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task {
            try await action()
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}
