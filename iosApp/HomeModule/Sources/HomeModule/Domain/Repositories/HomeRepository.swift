import Foundation

protocol HomeRepository: Sendable {
    func loadCurrentDate() async throws -> Date
}
