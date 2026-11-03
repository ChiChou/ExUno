import Foundation

struct CoachMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool

    init(text: String, isUser: Bool) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
    }
}

struct SavedCoachConversation: Codable, Equatable {
    let topicID: String
    let messages: [CoachMessage]
    let scriptStep: Int?
    let draft: String
}

/// One active conversation per study language, stored locally on this device.
struct CoachHistory {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ language: LanguageCode) -> String { "coach.conversation.v1." + language.rawValue }
    func load(_ language: LanguageCode) -> SavedCoachConversation? {
        guard let data = defaults.data(forKey: key(language)) else { return nil }
        return try? JSONDecoder().decode(SavedCoachConversation.self, from: data)
    }
    func save(_ conversation: SavedCoachConversation, language: LanguageCode) {
        if let data = try? JSONEncoder().encode(conversation) { defaults.set(data, forKey: key(language)) }
    }
}
