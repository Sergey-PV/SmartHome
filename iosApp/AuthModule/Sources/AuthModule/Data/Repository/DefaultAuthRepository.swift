import Foundation
import Network

final class DefaultAuthRepository: AuthRepository, @unchecked Sendable {
    private let apiClient: any AuthAPIClient
    private let credentialStore: any AuthCredentialStoring
    private let biometricAuthenticator: any BiometricAuthenticating
    private let deviceContextProvider: any DeviceContextProviding

    init(
        apiClient: any AuthAPIClient,
        credentialStore: any AuthCredentialStoring,
        biometricAuthenticator: any BiometricAuthenticating,
        deviceContextProvider: any DeviceContextProviding
    ) {
        self.apiClient = apiClient
        self.credentialStore = credentialStore
        self.biometricAuthenticator = biometricAuthenticator
        self.deviceContextProvider = deviceContextProvider
    }

    func loadState() async throws -> AuthStateSnapshot {
        let availability = biometricAuthenticator.availability()
        let context = deviceContextProvider.currentDeviceContext()
        let canLoginWithBiometrics = (try? credentialStore.loadBiometricCredential()) != nil

        guard let tokens = try credentialStore.loadTokens() else {
            return .signedOut(
                availability: availability,
                currentDeviceId: context.deviceId,
                canLoginWithBiometrics: canLoginWithBiometrics
            )
        }

        do {
            return try await fetchAuthorizedState(tokens: tokens, availability: availability)
        } catch let error as AuthError {
            if case .unauthorized = error {
                return try await refreshAndFetchState(availability: availability)
            }
            throw error
        } catch {
            throw map(error)
        }
    }

    func login(email: String, password: String) async throws -> AuthStateSnapshot {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidEmail(normalizedEmail) else {
            throw AuthError.validation("Введите корректный email.")
        }

        guard normalizedPassword.count >= 8 else {
            throw AuthError.validation("Пароль должен содержать минимум 8 символов.")
        }

        let device = deviceContextProvider.currentDeviceContext()
        let request = LoginRequestDTO(
            email: normalizedEmail,
            password: normalizedPassword,
            device: DeviceInfoDTO(
                deviceId: device.deviceId,
                platform: device.platform,
                appVersion: device.appVersion,
                osVersion: device.osVersion,
                deviceModel: device.deviceModel
            )
        )

        do {
            let response = try await apiClient.login(request: request)
            return try applyAuthenticatedResponse(response, currentDeviceId: device.deviceId)
        } catch {
            throw map(error)
        }
    }

    func register(email: String, password: String, firstName: String?, lastName: String?) async throws -> AuthStateSnapshot {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFirstName = normalizeOptionalName(firstName)
        let normalizedLastName = normalizeOptionalName(lastName)

        guard isValidEmail(normalizedEmail) else {
            throw AuthError.validation("Введите корректный email.")
        }

        guard normalizedPassword.count >= 8 else {
            throw AuthError.validation("Пароль должен содержать минимум 8 символов.")
        }

        let device = deviceContextProvider.currentDeviceContext()
        let request = RegisterRequestDTO(
            email: normalizedEmail,
            password: normalizedPassword,
            firstName: normalizedFirstName,
            lastName: normalizedLastName,
            device: DeviceInfoDTO(
                deviceId: device.deviceId,
                platform: device.platform,
                appVersion: device.appVersion,
                osVersion: device.osVersion,
                deviceModel: device.deviceModel
            )
        )

        do {
            let response = try await apiClient.register(request: request)
            return try applyAuthenticatedResponse(response, currentDeviceId: device.deviceId)
        } catch {
            throw map(error)
        }
    }

    func refreshSession() async throws -> AuthStateSnapshot {
        try await refreshAndFetchState(availability: biometricAuthenticator.availability())
    }

    func refreshAccessToken() async throws -> AuthTokens {
        try await refreshTokens()
    }

    func loginWithBiometrics() async throws -> AuthStateSnapshot {
        let availability = biometricAuthenticator.availability()
        guard availability.isAvailable else {
            throw AuthError.biometricUnavailable("Face ID / Touch ID недоступны на этом устройстве.")
        }

        guard let credential = try credentialStore.loadBiometricCredential() else {
            throw AuthError.missingBiometricCredential
        }

        try await biometricAuthenticator.authenticate(reason: "Подтвердите вход в SmartHome")

        do {
            let response = try await apiClient.loginWithBiometric(
                request: BiometricLoginRequestDTO(
                    biometricToken: credential.token,
                    deviceId: credential.deviceId
                )
            )

            try credentialStore.saveTokens(mapTokens(from: response))

            return AuthStateSnapshot(
                isAuthenticated: true,
                accessToken: response.accessToken,
                user: mapUser(response.user),
                biometricAvailability: availability,
                biometricEnabled: response.biometricEnabled,
                canLoginWithBiometrics: true,
                currentDeviceId: credential.deviceId,
                sessionStartedAt: Date()
            )
        } catch {
            throw map(error)
        }
    }

    func enableBiometrics() async throws -> AuthStateSnapshot {
        let availability = biometricAuthenticator.availability()
        guard let biometricType = availability.type else {
            throw AuthError.biometricUnavailable("Face ID / Touch ID недоступны на этом устройстве.")
        }

        try await biometricAuthenticator.authenticate(reason: "Подтвердите включение биометрии для SmartHome")

        let device = deviceContextProvider.currentDeviceContext()
        let accessToken = try storedAccessToken()

        do {
            let response = try await apiClient.enableBiometric(
                accessToken: accessToken,
                request: EnableBiometricRequestDTO(
                    deviceId: device.deviceId,
                    biometricType: biometricType.rawValue,
                    deviceName: device.deviceName
                )
            )

            let credential = BiometricCredential(
                token: response.biometricToken,
                deviceId: device.deviceId,
                biometricType: biometricType
            )
            try credentialStore.saveBiometricCredential(credential)

            let session = try await fetchAuthorizedState(
                tokens: try storedTokens(),
                availability: availability,
                overrideBiometricEnabled: response.biometricEnabled
            )
            return session
        } catch {
            throw map(error)
        }
    }

    func disableBiometrics() async throws -> AuthStateSnapshot {
        let availability = biometricAuthenticator.availability()
        let device = deviceContextProvider.currentDeviceContext()
        let accessToken = try storedAccessToken()

        do {
            try await apiClient.disableBiometric(
                accessToken: accessToken,
                request: DisableBiometricRequestDTO(deviceId: device.deviceId)
            )
            try credentialStore.removeBiometricCredential()

            let currentState = try await fetchAuthorizedState(
                tokens: try storedTokens(),
                availability: availability,
                overrideBiometricEnabled: false
            )
            return currentState
        } catch {
            throw map(error)
        }
    }

    func logout(allDevices: Bool) async throws -> AuthStateSnapshot {
        let availability = biometricAuthenticator.availability()
        let device = deviceContextProvider.currentDeviceContext()

        let tokens = try credentialStore.loadTokens()
        if let tokens {
            do {
                if allDevices {
                    try await apiClient.logoutAll(accessToken: tokens.accessToken)
                } else {
                    try await apiClient.logout(
                        accessToken: tokens.accessToken,
                        request: LogoutRequestDTO(refreshToken: tokens.refreshToken, deviceId: device.deviceId)
                    )
                }
            } catch {
                let mapped = map(error)
                if case .unauthorized = mapped {
                    // Local cleanup is still the safest outcome for an explicit logout.
                } else {
                    throw mapped
                }
            }
        }

        try credentialStore.removeAll()

        return .signedOut(
            availability: availability,
            currentDeviceId: device.deviceId,
            canLoginWithBiometrics: false
        )
    }

    private func refreshAndFetchState(availability: BiometricAvailability) async throws -> AuthStateSnapshot {
        let refreshedTokens = try await refreshTokens()

        do {
            return try await fetchAuthorizedState(tokens: refreshedTokens, availability: availability)
        } catch let error as AuthError {
            if case .unauthorized = error {
                try? credentialStore.removeTokens()
            }
            throw error
        }
    }

    private func refreshTokens() async throws -> AuthTokens {
        let device = deviceContextProvider.currentDeviceContext()
        let tokens = try storedTokens()

        do {
            let response = try await apiClient.refresh(
                request: RefreshTokenRequestDTO(
                    refreshToken: tokens.refreshToken,
                    deviceId: device.deviceId
                )
            )

            let refreshedTokens = mapTokens(from: response)
            try credentialStore.saveTokens(refreshedTokens)
            return refreshedTokens
        } catch let error as AuthError {
            if case .unauthorized = error {
                try? credentialStore.removeTokens()
            }
            throw error
        } catch {
            let mappedError = map(error)
            if case .unauthorized = mappedError {
                try? credentialStore.removeTokens()
            }
            throw mappedError
        }
    }

    private func fetchAuthorizedState(
        tokens: AuthTokens,
        availability: BiometricAvailability,
        overrideBiometricEnabled: Bool? = nil
    ) async throws -> AuthStateSnapshot {
        do {
            let session = try await apiClient.getSession(accessToken: tokens.accessToken)
            let userDTO = try await apiClient.getCurrentUser(accessToken: tokens.accessToken)
            let canLoginWithBiometrics = (try? credentialStore.loadBiometricCredential()) != nil

            return AuthStateSnapshot(
                isAuthenticated: session.authenticated,
                accessToken: tokens.accessToken,
                user: mapUser(userDTO),
                biometricAvailability: availability,
                biometricEnabled: overrideBiometricEnabled ?? session.biometricEnabled,
                canLoginWithBiometrics: canLoginWithBiometrics,
                currentDeviceId: session.currentDeviceId ?? deviceContextProvider.currentDeviceContext().deviceId,
                sessionStartedAt: session.sessionStartedAt
            )
        } catch {
            throw map(error)
        }
    }

    private func storedTokens() throws -> AuthTokens {
        guard let tokens = try credentialStore.loadTokens() else {
            throw AuthError.unauthorized("Сессия не найдена. Выполните вход ещё раз.")
        }
        return tokens
    }

    private func storedAccessToken() throws -> String {
        try storedTokens().accessToken
    }

    private func mapUser(_ dto: UserDTO) -> User {
        User(
            id: dto.id,
            email: dto.email,
            firstName: dto.firstName,
            lastName: dto.lastName,
            emailVerified: dto.emailVerified,
            createdAt: dto.createdAt
        )
    }

    private func mapTokens(from response: AuthSessionResponseDTO) -> AuthTokens {
        AuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            refreshExpiresIn: response.refreshExpiresIn
        )
    }

    private func mapTokens(from response: RefreshTokenResponseDTO) -> AuthTokens {
        AuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            refreshExpiresIn: response.refreshExpiresIn
        )
    }

    private func applyAuthenticatedResponse(
        _ response: AuthSessionResponseDTO,
        currentDeviceId: String
    ) throws -> AuthStateSnapshot {
        let availability = biometricAuthenticator.availability()
        try credentialStore.saveTokens(mapTokens(from: response))

        return AuthStateSnapshot(
            isAuthenticated: true,
            accessToken: response.accessToken,
            user: mapUser(response.user),
            biometricAvailability: availability,
            biometricEnabled: response.biometricEnabled,
            canLoginWithBiometrics: (try? credentialStore.loadBiometricCredential()) != nil,
            currentDeviceId: currentDeviceId,
            sessionStartedAt: Date()
        )
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func normalizeOptionalName(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func map(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .unauthorized("Сессия истекла. Выполните вход ещё раз.")
            case let .statusCode(response):
                let payload = try? makeErrorDecoder().decode(ErrorResponseDTO.self, from: response.data)
                let message = payload?.message ?? "Ошибка сервера. Попробуйте ещё раз."

                if response.statusCode == 401 {
                    return .unauthorized(message)
                }

                return .server(code: payload?.code ?? "HTTP_\(response.statusCode)", message: message)
            case .invalidResponse:
                return .transport("Сервер вернул некорректный ответ.")
            case .emptyResponse:
                return .transport("Сервер не вернул данные.")
            case let .transport(message),
                 let .requestEncoding(message):
                return .transport(message)
            }
        }

        if error is KeychainStoreError {
            return .transport("Не удалось безопасно сохранить данные сессии.")
        }

        return .unknown(error.localizedDescription)
    }

    private func makeErrorDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
