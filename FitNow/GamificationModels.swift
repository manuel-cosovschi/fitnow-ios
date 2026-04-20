import Foundation

// MARK: - Gamification Models

struct GamificationProfile: Decodable {
    let level: Int
    let total_xp: Int
    let streak_days: Int
    let last_active: String?
    let badges: [UserBadge]
    let stats: UserStats
}

struct UserBadge: Identifiable, Decodable {
    let id: Int?
    let code: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let threshold: Int?
    let earned_at: String?

    var sfSymbol: String {
        switch icon {
        case "footprints":   return "figure.walk"
        case "trophy":       return "trophy.fill"
        case "shield":       return "shield.fill"
        case "compass":      return "safari.fill"
        case "shield-alert": return "shield.checkered"
        case "flame":        return "flame.fill"
        case "fire":         return "flame.fill"
        case "dumbbell":     return "dumbbell.fill"
        case "users":        return "person.3.fill"
        case "message-star": return "star.bubble.fill"
        case "zap":          return "bolt.fill"
        case "award":        return "medal.fill"
        case "crown":        return "crown.fill"
        case "star":         return "star.fill"
        case "map-pin":      return "mappin.circle.fill"
        case "weight":       return "scalemass.fill"
        default:             return "star.circle.fill"
        }
    }
}

struct UserStats: Decodable {
    let total_run_sessions: Int
    let total_run_km: Double
    let total_gym_sessions: Int
    let total_gym_sets: Int
    let total_enrollments: Int
    let total_feedbacks: Int
    let total_hazards_reported: Int
}

struct XpLogEntry: Identifiable, Decodable {
    let id: Int
    let xp: Int
    let source: String
    let ref_type: String?
    let note: String?
    let created_at: String?
}

struct BadgeItem: Identifiable, Decodable {
    let id: Int
    let code: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let threshold: Int
    let earned: Bool?
}

struct RankingUser: Identifiable, Decodable {
    let id: Int
    let name: String
    let photo_url: String?
    let total_xp: Int?
    let weekly_xp: Int?
    let level: Int?
    let streak_days: Int?
}

struct PublicProfile: Decodable {
    let user: PublicUser
    let level: Int
    let total_xp: Int
    let streak_days: Int
    let badges: [UserBadge]
    let stats: UserStats
}

struct PublicUser: Decodable {
    let id: Int
    let name: String
    let photo_url: String?
    let bio: String?
}

// MARK: - Gym Models

struct GymSession: Identifiable, Decodable {
    let id: Int
    let user_id: Int?
    let activity_id: Int?
    let started_at: String?
    let finished_at: String?
    let status: String?
    let goal: String?
    let time_available_min: Int?
    let equipment_available: String?
    let muscle_groups: [String]?
    let ai_plan: AIPlan?
    let reroute_count: Int?
    let total_sets: Int?
    let total_reps: Int?
    let total_volume_kg: Double?
    let duration_s: Int?
    let sets: [GymSet]?
    let xp_earned: Int?
}

struct AIPlan: Decodable {
    let exercises: [AIExercise]?
    let estimated_duration_min: Int?
    let summary: String?
    let warmup: String?
    let cooldown: String?
}

struct AIExercise: Identifiable, Decodable {
    let order: Int?
    let name: String
    let muscle_group: String?
    let sets: Int?
    let reps: Int?
    let suggested_weight_kg: Double?
    let rest_seconds: Int?
    let notes: String?

    var id: String { "\(order ?? 0)-\(name)" }
}

struct GymSet: Identifiable, Decodable {
    let id: Int
    let session_id: Int?
    let exercise_name: String
    let muscle_group: String?
    let set_number: Int
    let planned_reps: Int?
    let planned_weight: Double?
    let actual_reps: Int?
    let actual_weight: Double?
    let rpe: Int?
    let rest_s: Int?
    let completed: Bool?
    let notes: String?
}

struct RerouteResponse: Decodable {
    let remaining_exercises: [AIExercise]?
    let estimated_remaining_min: Int?
    let reasoning: String?
    let adjustments_made: String?
}

// MARK: - Analytics Models

struct RunningSummary: Decodable {
    let total_sessions: Int?
    let total_distance_m: Double?
    let total_duration_s: Double?
    let avg_pace_s: Double?
    let avg_speed_mps: Double?
    let avg_hr_bpm: Double?
    let best_pace_s: Double?
    let longest_run_m: Double?
    let total_elevation_gain_m: Double?
}

struct WeeklyRunItem: Identifiable, Decodable {
    let week_start: String
    let sessions: Int
    let distance_m: Double
    let duration_s: Double
    let avg_pace_s: Double?

    var id: String { week_start }
}

struct WeeklyItemsResponse: Decodable { let items: [WeeklyRunItem] }

struct GymSummary: Decodable {
    let total_sessions: Int?
    let total_sets: Int?
    let total_reps: Int?
    let total_volume_kg: Double?
    let total_duration_s: Double?
    let avg_sets_per_session: Double?
    let avg_volume_per_session: Double?
    let favorite_exercise: String?
}

struct GymWeeklyItem: Identifiable, Decodable {
    let week_start: String
    let sessions: Int
    let total_sets: Int
    let total_volume_kg: Double

    var id: String { week_start }
}

struct GymWeeklyResponse: Decodable { let items: [GymWeeklyItem] }

struct MuscleDistItem: Identifiable, Decodable {
    let muscle_group: String
    let total_sets: Int
    let total_volume_kg: Double
    let percentage: Double

    var id: String { muscle_group }
}

struct MuscleDistResponse: Decodable { let items: [MuscleDistItem] }

struct StreakInfo: Decodable {
    let current_streak: Int
    let longest_streak: Int
    let active_days_last_30: Int
    let active_days_last_7: Int
}

// MARK: - Training Plan Models

struct TrainingPlan: Identifiable, Decodable {
    let id: Int
    let user_id: Int?
    let title: String
    let goal: String
    let duration_weeks: Int
    let difficulty: String?
    let plan_data: PlanData?
    let status: String?
    let started_at: String?
    let created_at: String?
}

struct PlanData: Decodable {
    let title: String?
    let summary: String?
    let weeks: [PlanWeek]?
    let tips: [String]?
}

struct PlanWeek: Identifiable, Decodable {
    let week: Int
    let focus: String?
    let days: [PlanDay]?

    var id: Int { week }
}

struct PlanDay: Identifiable, Decodable {
    let day: Int
    let type: String?
    let title: String?
    let description: String?
    let duration_min: Int?
    let distance_km: Double?
    let intensity: String?
    let exercises: [PlanExercise]?

    var id: Int { day }
}

struct PlanExercise: Identifiable, Decodable {
    let name: String
    let sets: Int?
    let reps: Int?
    let weight_suggestion: String?

    var id: String { name }
}

// MARK: - Paged response for gamification

struct PagedGamification<T: Decodable>: Decodable {
    let items: [T]
    let pagination: PagedPagination?
}

struct GymSessionsList: Decodable {
    let items: [GymSession]
    let pagination: PagedPagination?
}

struct TrainingPlansList: Decodable {
    let items: [TrainingPlan]
    let pagination: PagedPagination?
}
