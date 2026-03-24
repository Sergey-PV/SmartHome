import Foundation

public struct User: Codable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let emailVerified: Bool
    public let createdAt: Date?

    public init(
        id: String,
        email: String,
        firstName: String?,
        lastName: String?,
        emailVerified: Bool,
        createdAt: Date?
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.emailVerified = emailVerified
        self.createdAt = createdAt
    }

    public var fullName: String {
        let components = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return components.isEmpty ? email : components.joined(separator: " ")
    }
}
