import Foundation
import Combine
import SwiftUI
import AuthModule

public struct HomeRootView: View {
    @ObservedObject private var authViewModel: AuthViewModel
    @StateObject private var homeViewModel: HomeViewModel

    public init(
        authViewModel: AuthViewModel,
        baseURL: URL = AuthEnvironment.productionBaseURL,
        urlSession: URLSession = .shared
    ) {
        self.authViewModel = authViewModel
        _homeViewModel = StateObject(
            wrappedValue: HomeViewModel(
                baseURL: baseURL,
                urlSession: urlSession
            )
        )
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

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var currentDateText: String?
    @Published public var errorMessage: String?

    private let urlSession: URLSession
    private let baseURL: URL

    public init(
        baseURL: URL = AuthEnvironment.productionBaseURL,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    public func loadCurrentDate() async {
        isLoading = true
        errorMessage = nil

        do {
            let endpoint = baseURL.appending(path: "home/current-date")
            let (data, response) = try await urlSession.data(from: endpoint)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HomeScreenError.invalidResponse
            }

            guard 200 ..< 300 ~= httpResponse.statusCode else {
                throw HomeScreenError.server(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(CurrentDateResponse.self, from: data)

            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            currentDateText = formatter.string(from: payload.currentDate)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }
}

private struct CurrentDateResponse: Decodable {
    let currentDate: Date
}

private enum HomeScreenError: LocalizedError {
    case invalidResponse
    case server(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Сервер вернул некорректный ответ."
        case let .server(statusCode):
            return "Не удалось загрузить дату. Код ответа: \(statusCode)."
        }
    }
}
