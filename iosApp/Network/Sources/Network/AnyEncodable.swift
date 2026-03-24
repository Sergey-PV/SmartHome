import Foundation

public struct AnyEncodable: Encodable, @unchecked Sendable {
    private let encodeClosure: @Sendable (Encoder) throws -> Void

    public init<Value: Encodable & Sendable>(_ value: Value) {
        encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
