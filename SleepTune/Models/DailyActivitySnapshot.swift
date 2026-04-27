import Foundation

struct WorkoutSummary: Codable, Identifiable {
    var id: UUID
    let activityName: String
    let durationMinutes: Double
    let activeCalories: Double?
    let startDate: Date
    let endDate: Date
}

struct DailyActivitySnapshot: Codable {
    let date: Date
    let steps: Double?
    let activeCalories: Double?
    let exerciseMinutes: Double?
    let standMinutes: Double?
    let floorsClimbed: Double?
    let peakHR: Double?
    let vo2Max: Double?
    let workouts: [WorkoutSummary]
}
