import Foundation
import Network

enum AuthTarget: TargetType {
    case login(baseURL: URL, request: LoginRequestDTO)
    case register(baseURL: URL, request: RegisterRequestDTO)
    case refresh(baseURL: URL, request: RefreshTokenRequestDTO)
    case logout(baseURL: URL, accessToken: String, request: LogoutRequestDTO?)
    case logoutAll(baseURL: URL, accessToken: String)
    case enableBiometric(baseURL: URL, accessToken: String, request: EnableBiometricRequestDTO)
    case loginWithBiometric(baseURL: URL, request: BiometricLoginRequestDTO)
    case disableBiometric(baseURL: URL, accessToken: String, request: DisableBiometricRequestDTO)
    case session(baseURL: URL, accessToken: String)
    case currentUser(baseURL: URL, accessToken: String)

    var baseURL: URL {
        switch self {
        case let .login(baseURL, _),
             let .register(baseURL, _),
             let .refresh(baseURL, _),
             let .logout(baseURL, _, _),
             let .logoutAll(baseURL, _),
             let .enableBiometric(baseURL, _, _),
             let .loginWithBiometric(baseURL, _),
             let .disableBiometric(baseURL, _, _),
             let .session(baseURL, _),
             let .currentUser(baseURL, _):
            return baseURL
        }
    }

    var path: String {
        switch self {
        case .login:
            return "/auth/login"
        case .register:
            return "/auth/register"
        case .refresh:
            return "/auth/refresh"
        case .logout:
            return "/auth/logout"
        case .logoutAll:
            return "/auth/logout-all"
        case .enableBiometric:
            return "/auth/biometric/enable"
        case .loginWithBiometric:
            return "/auth/biometric/login"
        case .disableBiometric:
            return "/auth/biometric/disable"
        case .session:
            return "/auth/session"
        case .currentUser:
            return "/users/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .session, .currentUser:
            return .get
        default:
            return .post
        }
    }

    var task: RequestTask {
        switch self {
        case let .login(_, request):
            return .requestJSONEncodable(AnyEncodable(request))
        case let .register(_, request):
            return .requestJSONEncodable(AnyEncodable(request))
        case let .refresh(_, request):
            return .requestJSONEncodable(AnyEncodable(request))
        case let .logout(_, _, request):
            if let request {
                return .requestJSONEncodable(AnyEncodable(request))
            }
            return .requestPlain
        case .logoutAll:
            return .requestPlain
        case let .enableBiometric(_, _, request):
            return .requestJSONEncodable(AnyEncodable(request))
        case let .loginWithBiometric(_, request):
            return .requestJSONEncodable(AnyEncodable(request))
        case let .disableBiometric(_, _, request):
            return .requestJSONEncodable(AnyEncodable(request))
        case .session, .currentUser:
            return .requestPlain
        }
    }

    var headers: [String : String] {
        switch self {
        case let .logout(_, accessToken, _),
             let .logoutAll(_, accessToken),
             let .enableBiometric(_, accessToken, _),
             let .disableBiometric(_, accessToken, _),
             let .session(_, accessToken),
             let .currentUser(_, accessToken):
            return authorizedHeaders(accessToken)
        case .login, .register, .refresh, .loginWithBiometric:
            return [:]
        }
    }

    private func authorizedHeaders(_ accessToken: String) -> [String: String] {
        ["Authorization": "Bearer \(accessToken)"]
    }
}
