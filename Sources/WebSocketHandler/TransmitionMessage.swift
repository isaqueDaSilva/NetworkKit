public struct TransmitionMessage: Sendable {
    let message: any Codable & Sendable
}