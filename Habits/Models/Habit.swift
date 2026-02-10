import Foundation

struct Habit: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var frequency: HabitFrequency

    init(id: UUID = UUID(), name: String, frequency: HabitFrequency = .daily) {
        self.id = id
        self.name = name
        self.frequency = frequency
    }

    // Backward-compatible decoding: default to .daily if frequency is missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        frequency = try container.decodeIfPresent(HabitFrequency.self, forKey: .frequency) ?? .daily
    }
}
