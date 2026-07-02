import Foundation
import HealthKit

// MARK: - HealthKitService
// Saves completed run sessions as HKWorkout and writes distance/calorie samples.

final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    // Pide permiso para leer/escribir en Apple Salud.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let types: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.runningSpeed),
        ]
        return (try? await store.requestAuthorization(toShare: types, read: types)) != nil
    }

    // MARK: - Save run workout

    // Guarda la corrida terminada en Apple Salud.
    func saveRun(
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        startDate: Date,
        endDate: Date,
        calories: Double? = nil
    ) async {
        guard isAvailable else { return }
        let _ = await requestAuthorization()

        var samples: [HKSample] = []

        // Distance sample
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let distanceSample = HKQuantitySample(
            type: distanceType,
            quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
            start: startDate, end: endDate
        )
        samples.append(distanceSample)

        // Calorie sample (estimated if not provided)
        let kcal = calories ?? estimateCalories(distanceMeters: distanceMeters,
                                                durationSeconds: durationSeconds)
        let energyType = HKQuantityType(.activeEnergyBurned)
        let energySample = HKQuantitySample(
            type: energyType,
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            start: startDate, end: endDate
        )
        samples.append(energySample)

        // Workout
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: startDate)
            try await builder.addSamples(samples)
            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
        } catch {
            // HealthKit save failures are non-critical
        }
    }

    // MARK: - Read weekly distance (for ACWR)

    // Suma los km que corriste en una semana.
    func weeklyDistanceKm(weeksBack: Int) async -> Double {
        guard isAvailable else { return 0 }
        let _ = await requestAuthorization()

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let now = Date()
        let start = Calendar.current.date(byAdding: .weekOfYear, value: -weeksBack, to: now) ?? now

        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: now, options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let meters = stats?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters / 1000)
            }
            store.execute(query)
        }
    }

    // MARK: - Read average heart rate (feeds the coach analysis)

    /// Average heart rate (bpm) recorded in the given window, e.g. from an Apple
    /// Watch worn during the run. Returns nil if there are no samples or no
    /// permission — the run just finishes without HR in that case.
    func averageHeartRate(from start: Date, to end: Date) async -> Double? {
        guard isAvailable, end > start else { return nil }
        let _ = await requestAuthorization()

        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: bpmUnit))
            }
            store.execute(query)
        }
    }

    // MARK: - ACWR

    struct ACWR {
        let acuteKm: Double     // last 7 days
        let chronicKm: Double   // 4-week average
        var ratio: Double { chronicKm > 0 ? acuteKm / chronicKm : 0 }
        var zone: Zone {
            switch ratio {
            case ..<0.8:  return .underload
            case 0.8...1.3: return .optimal
            default:      return .overload
            }
        }
        enum Zone { case underload, optimal, overload }
    }

    // Calcula la relación carga aguda/crónica, para avisarte si entrenás de más.
    func computeACWR() async -> ACWR {
        async let w1 = weeklyDistanceKm(weeksBack: 1)
        async let w2 = weeklyDistanceKm(weeksBack: 2)
        async let w3 = weeklyDistanceKm(weeksBack: 3)
        async let w4 = weeklyDistanceKm(weeksBack: 4)
        let (acute, week2, week3, week4) = await (w1, w2, w3, w4)
        let chronic = (acute + week2 + week3 + week4) / 4
        return ACWR(acuteKm: acute, chronicKm: chronic)
    }

    // MARK: - Helpers

    // Estima las calorías quemadas.
    private func estimateCalories(distanceMeters: Double, durationSeconds: TimeInterval) -> Double {
        // MET ≈ 8 for running, average weight 70kg assumed
        let met = 8.0
        let weightKg = 70.0
        let hours = durationSeconds / 3600
        return met * weightKg * hours
    }
}
