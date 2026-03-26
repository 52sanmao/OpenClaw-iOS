import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role: String, Codable {
        case user, assistant, system
    }
}
