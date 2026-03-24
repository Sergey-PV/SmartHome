import Foundation
import Combine

public enum AuthFlowMode: String, CaseIterable, Identifiable, Sendable {
    case login
    case register

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .login:
            return "Вход"
        case .register:
            return "Регистрация"
        }
    }
}

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var mode: AuthFlowMode = .login
    @Published public var email: String = "user@example.com"
    @Published public var password: String = "StrongPassword123!"
    @Published public var firstName: String = ""
    @Published public var lastName: String = ""
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var accessToken: String?
    @Published public private(set) var currentUser: User?
    @Published public private(set) var biometricAvailable: Bool = false
    @Published public private(set) var biometricEnabled: Bool = false
    @Published public private(set) var canLoginWithBiometrics: Bool = false
    @Published public private(set) var biometricTitle: String = "Biometric"
    @Published public private(set) var currentDeviceId: String = ""
    @Published public private(set) var sessionStartedAt: Date?
    @Published public private(set) var infoMessage: String?
    @Published public var errorMessage: String?

    private let loadAuthStateUseCase: LoadAuthStateUseCase
    private let loginWithEmailUseCase: LoginWithEmailUseCase
    private let registerWithEmailUseCase: RegisterWithEmailUseCase
    private let refreshSessionUseCase: RefreshSessionUseCase
    private let loginWithBiometricsUseCase: LoginWithBiometricsUseCase
    private let enableBiometricsUseCase: EnableBiometricsUseCase
    private let disableBiometricsUseCase: DisableBiometricsUseCase
    private let logoutUseCase: LogoutUseCase

    public init(
        loadAuthStateUseCase: LoadAuthStateUseCase,
        loginWithEmailUseCase: LoginWithEmailUseCase,
        registerWithEmailUseCase: RegisterWithEmailUseCase,
        refreshSessionUseCase: RefreshSessionUseCase,
        loginWithBiometricsUseCase: LoginWithBiometricsUseCase,
        enableBiometricsUseCase: EnableBiometricsUseCase,
        disableBiometricsUseCase: DisableBiometricsUseCase,
        logoutUseCase: LogoutUseCase
    ) {
        self.loadAuthStateUseCase = loadAuthStateUseCase
        self.loginWithEmailUseCase = loginWithEmailUseCase
        self.registerWithEmailUseCase = registerWithEmailUseCase
        self.refreshSessionUseCase = refreshSessionUseCase
        self.loginWithBiometricsUseCase = loginWithBiometricsUseCase
        self.enableBiometricsUseCase = enableBiometricsUseCase
        self.disableBiometricsUseCase = disableBiometricsUseCase
        self.logoutUseCase = logoutUseCase
    }

    public func load() async {
        await perform(messageOnSuccess: nil) {
            try await loadAuthStateUseCase.execute()
        }
    }

    public func login() async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidEmail(normalizedEmail) else {
            errorMessage = AuthError.validation("Введите корректный email.").localizedDescription
            return
        }

        guard normalizedPassword.count >= 8 else {
            errorMessage = AuthError.validation("Пароль должен содержать минимум 8 символов.").localizedDescription
            return
        }

        await perform(messageOnSuccess: "Вход выполнен успешно.") {
            try await loginWithEmailUseCase.execute(email: normalizedEmail, password: normalizedPassword)
        }
    }

    public func register() async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidEmail(normalizedEmail) else {
            errorMessage = AuthError.validation("Введите корректный email.").localizedDescription
            return
        }

        guard normalizedPassword.count >= 8 else {
            errorMessage = AuthError.validation("Пароль должен содержать минимум 8 символов.").localizedDescription
            return
        }

        await perform(messageOnSuccess: "Аккаунт создан, вход выполнен автоматически.") {
            try await registerWithEmailUseCase.execute(
                email: normalizedEmail,
                password: normalizedPassword,
                firstName: firstName,
                lastName: lastName
            )
        }
    }

    public func refreshSession() async {
        await perform(messageOnSuccess: "Сессия обновлена.") {
            try await refreshSessionUseCase.execute()
        }
    }

    public func loginWithBiometrics() async {
        await perform(messageOnSuccess: "Сессия восстановлена через \(biometricTitle).") {
            try await loginWithBiometricsUseCase.execute()
        }
    }

    public func enableBiometrics() async {
        await perform(messageOnSuccess: "\(biometricTitle) включён для восстановления сессии.") {
            try await enableBiometricsUseCase.execute()
        }
    }

    public func disableBiometrics() async {
        await perform(messageOnSuccess: "Биометрический вход отключён.") {
            try await disableBiometricsUseCase.execute()
        }
    }

    public func logout(allDevices: Bool = false) async {
        let successMessage = allDevices ? "Выход выполнен на всех устройствах." : "Выход выполнен."

        await perform(messageOnSuccess: successMessage) {
            try await logoutUseCase.execute(allDevices: allDevices)
        }
    }

    public var primaryActionTitle: String {
        if isLoading {
            return mode == .login ? "Выполняется вход..." : "Создаём аккаунт..."
        }
        return mode == .login ? "Войти" : "Зарегистрироваться"
    }

    public var authSectionTitle: String {
        mode == .login ? "Вход по email" : "Регистрация"
    }

    public func resetMessages() {
        infoMessage = nil
        errorMessage = nil
    }

    private func perform(
        messageOnSuccess: String?,
        operation: () async throws -> AuthStateSnapshot
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await operation()
            apply(snapshot)
            infoMessage = messageOnSuccess
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func apply(_ snapshot: AuthStateSnapshot) {
        isAuthenticated = snapshot.isAuthenticated
        accessToken = snapshot.accessToken
        currentUser = snapshot.user
        biometricAvailable = snapshot.biometricAvailability.isAvailable
        biometricEnabled = snapshot.biometricEnabled
        canLoginWithBiometrics = snapshot.canLoginWithBiometrics
        biometricTitle = snapshot.biometricAvailability.title
        currentDeviceId = snapshot.currentDeviceId
        sessionStartedAt = snapshot.sessionStartedAt

        if !snapshot.isAuthenticated {
            accessToken = nil
            currentUser = nil
            biometricEnabled = false
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
