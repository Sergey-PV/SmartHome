import SwiftUI
import AuthModule

public struct HomeRootView: View {
    @ObservedObject private var authViewModel: AuthViewModel
    @StateObject private var homeViewModel: HomeViewModel

    public init(
        authViewModel: AuthViewModel,
        viewModel: HomeViewModel
    ) {
        self.authViewModel = authViewModel
        _homeViewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Главный экран")
                        .font(.largeTitle.weight(.bold))
                    Text("Это временная домашняя страница. Дальше будем расширять её реальными данными.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Текущий пользователь")
                        .font(.headline)
                    Text(authViewModel.currentUser?.fullName ?? authViewModel.currentUser?.email ?? "Пользователь")
                        .font(.title3.weight(.semibold))
                    Text(authViewModel.currentUser?.email ?? "")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Дата с middleware")
                        .font(.headline)

                    if homeViewModel.isLoading {
                        ProgressView("Загружаем текущую дату...")
                    } else if let currentDateText = homeViewModel.currentDateText {
                        Text(currentDateText)
                            .font(.title3.weight(.semibold))
                    } else {
                        Text("Дата ещё не загружена")
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage = homeViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await homeViewModel.loadCurrentDate()
                        }
                    } label: {
                        Text("Обновить дату")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        Text("Выйти")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.98, blue: 1.0),
                        Color(red: 0.90, green: 0.95, blue: 0.99),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("SmartHome")
        }
        .task {
            await homeViewModel.loadCurrentDate()
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { authViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        authViewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                authViewModel.errorMessage = nil
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }
}
