import Foundation
import Combine

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var currentDateText: String?
    @Published public var errorMessage: String?

    private let loadCurrentDateUseCase: LoadCurrentDateUseCase

    public init(loadCurrentDateUseCase: LoadCurrentDateUseCase) {
        self.loadCurrentDateUseCase = loadCurrentDateUseCase
    }

    public func loadCurrentDate() async {
        isLoading = true
        errorMessage = nil

        do {
            let currentDate = try await loadCurrentDateUseCase.execute()
            currentDateText = Self.makeFormatter().string(from: currentDate)
        } catch let homeError as HomeError {
            errorMessage = homeError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }
}
