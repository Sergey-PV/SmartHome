import SwiftUI

public struct AuthRootView: View {
    @StateObject private var viewModel: AuthViewModel

    public init(viewModel: AuthViewModel = AuthModuleAssembly.makeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statusBanner

                    if viewModel.isAuthenticated {
                        authenticatedContent
                    } else {
                        loginContent
                    }
                }
                .padding(20)
            }
            .background(background)
            .authNavigationChrome()
            .onChange(of: viewModel.mode) { _, _ in
                viewModel.resetMessages()
            }
        }
        .task {
            await viewModel.load()
        }
        .alert(
            "Ошибка авторизации",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SmartHome Auth")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("SPM-модуль авторизации на Clean Architecture + MVVM. Поддерживает регистрацию, email/password, refresh token и biometric session restore.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.34, blue: 0.74),
                            Color(red: 0.02, green: 0.60, blue: 0.63),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let infoMessage = viewModel.infoMessage {
            Label(infoMessage, systemImage: "checkmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.07, green: 0.42, blue: 0.19))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.91, green: 0.98, blue: 0.92))
                )
        }
    }

    private var loginContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Режим", selection: $viewModel.mode) {
                ForEach(AuthFlowMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            sectionTitle(viewModel.authSectionTitle)

            VStack(spacing: 14) {
                if viewModel.mode == .register {
                    TextField("Имя", text: $viewModel.firstName)
                        .authTextFieldStyle()

                    TextField("Фамилия", text: $viewModel.lastName)
                        .authTextFieldStyle()
                }

                TextField("Email", text: $viewModel.email)
                    .authTextFieldStyle()
                    .authEmailKeyboard()

                SecureField("Пароль", text: $viewModel.password)
                    .authTextFieldStyle()
            }

            actionButton(title: viewModel.primaryActionTitle, isPrimary: true) {
                Task {
                    if viewModel.mode == .login {
                        await viewModel.login()
                    } else {
                        await viewModel.register()
                    }
                }
            }
            .disabled(viewModel.isLoading)

            if viewModel.mode == .login, viewModel.canLoginWithBiometrics {
                actionButton(title: "Войти через \(viewModel.biometricTitle)", isPrimary: false) {
                    Task {
                        await viewModel.loginWithBiometrics()
                    }
                }
                .disabled(viewModel.isLoading)
            }

            footerDetails
        }
        .cardStyle()
    }

    private var authenticatedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Текущая сессия")

            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.currentUser?.fullName ?? "Пользователь")
                    .font(.title3.weight(.semibold))
                Text(viewModel.currentUser?.email ?? "")
                    .foregroundStyle(.secondary)

                divider

                detailRow(title: "Device ID", value: viewModel.currentDeviceId)
                detailRow(title: "Email verified", value: viewModel.currentUser?.emailVerified == true ? "Yes" : "No")

                if let sessionStartedAt = viewModel.sessionStartedAt {
                    detailRow(title: "Session started", value: sessionStartedAt.formatted(date: .abbreviated, time: .shortened))
                }

                detailRow(title: "Biometric restore", value: viewModel.biometricEnabled ? "Enabled" : "Disabled")
            }

            actionButton(title: "Обновить сессию", isPrimary: true) {
                Task {
                    await viewModel.refreshSession()
                }
            }
            .disabled(viewModel.isLoading)

            if viewModel.biometricAvailable {
                actionButton(
                    title: viewModel.biometricEnabled ? "Отключить \(viewModel.biometricTitle)" : "Включить \(viewModel.biometricTitle)",
                    isPrimary: false
                ) {
                    Task {
                        if viewModel.biometricEnabled {
                            await viewModel.disableBiometrics()
                        } else {
                            await viewModel.enableBiometrics()
                        }
                    }
                }
                .disabled(viewModel.isLoading)
            }

            actionButton(title: "Выйти", isPrimary: false) {
                Task {
                    await viewModel.logout()
                }
            }
            .disabled(viewModel.isLoading)

            actionButton(title: "Выйти на всех устройствах", isPrimary: false, role: .destructive) {
                Task {
                    await viewModel.logout(allDevices: true)
                }
            }
            .disabled(viewModel.isLoading)
        }
        .cardStyle()
    }

    private var footerDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            divider
            detailRow(title: "Biometric available", value: viewModel.biometricAvailable ? viewModel.biometricTitle : "No")
            detailRow(title: "Stored biometric session", value: viewModel.canLoginWithBiometrics ? "Yes" : "No")
            detailRow(title: "Current device", value: viewModel.currentDeviceId)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.92, green: 0.96, blue: 0.99),
                Color.white,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.08))
            .frame(height: 1)
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func actionButton(title: String, isPrimary: Bool, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(isPrimary ? .white : .accentColor)
                }
                Text(title)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPrimary ? .white : role == .destructive ? .red : .primary)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(buttonBackground(isPrimary: isPrimary, role: role))
        )
    }

    private func buttonBackground(isPrimary: Bool, role: ButtonRole?) -> some ShapeStyle {
        if isPrimary {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.34, blue: 0.78),
                        Color(red: 0.10, green: 0.56, blue: 0.74),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if role == .destructive {
            return AnyShapeStyle(Color.red.opacity(0.08))
        }

        return AnyShapeStyle(Color.white.opacity(0.9))
    }
}

private extension View {
    @ViewBuilder
    func authNavigationChrome() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func cardStyle() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 12)
    }

    func authTextFieldStyle() -> some View {
        modifier(AuthTextFieldModifier())
    }

    @ViewBuilder
    func authEmailKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}

private struct AuthTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )
    }
}
