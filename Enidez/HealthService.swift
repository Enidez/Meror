//
//  HealthService.swift
//  Enidez
//
//  Lit le sommeil et l'activité depuis Apple Santé, en async/await.
//  Si Santé n'est pas disponible ou refusé, on garde les données d'exemple :
//  l'app reste utile, elle s'enrichit dès que l'accès est accordé.
//
//  Pour activer les vraies données :
//   1. Cible Enidez → Signing & Capabilities → + Capability → HealthKit.
//   2. Ajouter la description d'usage « Privacy - Health Share Usage Description »
//      (clé NSHealthShareUsageDescription) dans les réglages de la cible.
//

import Foundation
#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif

/// Instantané des données de santé, prêt à fusionner dans le LifeContext.
struct HealthSnapshot {
    var lastNightSleepHours: Double?
    var averageSleepHours: Double?
    var averageBedtime: Date?
    var stepsToday: Int?
    var activeEnergyToday: Double?
    var connected: Bool
}

@MainActor
final class HealthService {

    #if canImport(HealthKit) && os(iOS)
    private let store = HKHealthStore()
    #endif

    /// Demande l'autorisation puis récupère un instantané.
    /// Renvoie `nil` si Santé est indisponible ou refusé.
    func requestAndFetch() async -> HealthSnapshot? {
        // Dans le canvas de preview, on ne touche pas à HealthKit : la demande
        // d'autorisation y provoque un crash dur (clé Info.plist absente).
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return nil
        }
        #if canImport(HealthKit) && os(iOS)
        // Sans description d'usage dans l'Info.plist, `requestAuthorization` lève
        // une exception Objective-C non rattrapable : on s'arrête avant.
        guard Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil else {
            return nil
        }
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }
        let stepType = HKQuantityType(.stepCount)
        let energyType = HKQuantityType(.activeEnergyBurned)

        do {
            try await store.requestAuthorization(
                toShare: [],
                read: [sleepType, stepType, energyType]
            )
        } catch {
            return nil
        }

        async let sleep = fetchSleep(sleepType)
        async let steps = fetchTodaySum(stepType, unit: .count())
        async let energy = fetchTodaySum(energyType, unit: .kilocalorie())

        let (sleepResult, stepCount, energyKcal) = await (sleep, steps, energy)

        return HealthSnapshot(
            lastNightSleepHours: sleepResult.lastNight,
            averageSleepHours: sleepResult.average,
            averageBedtime: sleepResult.bedtime,
            stepsToday: stepCount.map { Int($0) },
            activeEnergyToday: energyKcal,
            connected: true
        )
        #else
        return nil
        #endif
    }

    #if canImport(HealthKit) && os(iOS)

    private struct SleepResult {
        var lastNight: Double?
        var average: Double?
        var bedtime: Date?
    }

    /// Vrai si la valeur d'un échantillon correspond à du sommeil (toutes phases).
    private func isAsleep(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            let asleep: [HKCategoryValueSleepAnalysis] = [.asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified]
            return asleep.map(\.rawValue).contains(value)
        } else {
            return value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }
    }

    /// Analyse les 7 derniers jours de sommeil : durée de la nuit passée,
    /// moyenne par nuit et heure de coucher moyenne.
    private func fetchSleep(_ type: HKCategoryType) async -> SleepResult {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        let asleep = samples.filter { isAsleep($0.value) }
        guard !asleep.isEmpty else { return SleepResult() }

        let calendar = Calendar.current
        // On regroupe par « nuit » : la date du matin de réveil.
        var byNight: [Date: (total: TimeInterval, earliestStart: Date)] = [:]
        for sample in asleep {
            let nightKey = calendar.startOfDay(for: sample.endDate)
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            if var existing = byNight[nightKey] {
                existing.total += duration
                existing.earliestStart = min(existing.earliestStart, sample.startDate)
                byNight[nightKey] = existing
            } else {
                byNight[nightKey] = (duration, sample.startDate)
            }
        }

        let nights = byNight.sorted { $0.key > $1.key }
        let lastNight = nights.first.map { $0.value.total / 3600 }
        let average = nights.isEmpty ? nil : nights.map { $0.value.total }.reduce(0, +) / Double(nights.count) / 3600

        // Heure de coucher moyenne, ramenée à une heure du jour.
        var bedtime: Date?
        if let sample = nights.first {
            let comps = calendar.dateComponents([.hour, .minute], from: sample.value.earliestStart)
            bedtime = LifeContext.time(comps.hour ?? 23, comps.minute ?? 0)
        }

        return SleepResult(lastNight: lastNight, average: average, bedtime: bedtime)
    }

    /// Somme cumulée d'une grandeur pour la journée en cours (pas, énergie…).
    private func fetchTodaySum(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    #endif
}
