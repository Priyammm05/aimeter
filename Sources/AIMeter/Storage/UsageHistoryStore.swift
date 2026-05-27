import Foundation
import Combine

// MARK: - Usage History Entry

struct UsageHistoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let provider: UsageProvider
    let percent: Double
    let planLabel: String
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        provider: UsageProvider,
        percent: Double,
        planLabel: String,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.provider = provider
        self.percent = percent
        self.planLabel = planLabel
        self.recordedAt = recordedAt
    }
}

// MARK: - Usage History Store

@MainActor
final class UsageHistoryStore: ObservableObject {
    @Published private(set) var entries: [UsageHistoryEntry] = []

    private let maxEntriesPerProvider = 20

    /// Minimum percentage change to record a new entry (avoids noise).
    private let minChangeThreshold = 0.4

    /// Minimum seconds between entries even if no change (ensures periodic recording).
    private let minRecordInterval: TimeInterval = 300

    private let userDefaults: UserDefaults
    private let storageKey = "aimeter.usageHistory.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadEntries()
    }

    // MARK: - Recording

    func record(snapshot: ProviderUsageSnapshot) {
        guard snapshot.connectionState == .connected,
              let percent = snapshot.progressPercent else { return }

        let existing = entries.filter { $0.provider == snapshot.provider }

        if let last = existing.last {
            let pctDelta = abs(last.percent - percent)
            let elapsed = Date().timeIntervalSince(last.recordedAt)
            guard pctDelta >= minChangeThreshold || elapsed >= minRecordInterval else { return }
        }

        let entry = UsageHistoryEntry(
            provider: snapshot.provider,
            percent: percent,
            planLabel: snapshot.planLabel
        )
        entries.append(entry)
        trimEntries()
        saveEntries()
    }

    // MARK: - Queries

    /// Returns up to `limit` most-recent entries for a provider, newest first.
    func recentEntries(for provider: UsageProvider, limit: Int = 5) -> [UsageHistoryEntry] {
        Array(entries.filter { $0.provider == provider }.suffix(limit).reversed())
    }

    /// Returns the change in usage percent between the two most recent readings (positive = going up).
    func latestDelta(for provider: UsageProvider) -> Double? {
        let recent = Array(entries.filter { $0.provider == provider }.suffix(2))
        guard recent.count == 2 else { return nil }
        return recent[1].percent - recent[0].percent
    }

    /// Average percent increase per hour based on recent history (last 5 entries).
    func burnRate(for provider: UsageProvider) -> Double? {
        let recent = Array(entries.filter { $0.provider == provider }.suffix(5))
        guard recent.count >= 3 else { return nil }

        let first = recent.first!
        let last = recent.last!
        let hours = last.recordedAt.timeIntervalSince(first.recordedAt) / 3600
        guard hours > 0 else { return nil }

        let pctChange = last.percent - first.percent
        return pctChange / hours
    }

    // MARK: - Demo injection

    /// Replaces all entries with the supplied demo data. Only called when `DemoMode.isEnabled`.
    /// Does **not** persist to UserDefaults so real history is never clobbered.
    func injectDemoData(_ demoEntries: [UsageHistoryEntry]) {
        entries = demoEntries
        // Deliberately skip saveEntries() — demo data lives in-memory only
    }

    // MARK: - Persistence

    private func trimEntries() {
        var trimmed: [UsageHistoryEntry] = []
        for provider in UsageProvider.allCases {
            trimmed += entries.filter { $0.provider == provider }.suffix(maxEntriesPerProvider)
        }
        entries = trimmed.sorted { $0.recordedAt < $1.recordedAt }
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func loadEntries() {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([UsageHistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
