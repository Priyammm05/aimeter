import Foundation

// MARK: - Demo Usage Client

/// A fake `ProviderUsageClient` that returns pre-baked snapshots.
/// Only instantiated when `DemoMode.isEnabled == true`.
@MainActor
final class DemoUsageClient: ProviderUsageClient {
    let provider: UsageProvider
    private let fakeSnapshot: ProviderUsageSnapshot

    init(provider: UsageProvider) {
        self.provider = provider
        self.fakeSnapshot = DemoData.snapshot(for: provider)
    }

    func connect() async throws {
        // Simulate a brief connection handshake
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    func fetchUsage() async throws -> ProviderUsageSnapshot {
        // Simulate network round-trip so the spinner shows up briefly
        try await Task.sleep(nanoseconds: 700_000_000)
        return fakeSnapshot
    }

    func disconnect() {}
}

// MARK: - Demo Configuration

/// Parses `--key value` pairs from `CommandLine.arguments`.
private enum DemoArgs {
    static func string(_ key: String) -> String? {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: key), args.indices.contains(idx + 1) else { return nil }
        return args[idx + 1]
    }

    static func double(_ key: String) -> Double? {
        string(key).flatMap { Double($0) }
    }

    static func bool(_ key: String) -> Bool {
        CommandLine.arguments.contains(key)
    }
}

// MARK: - Demo Data

/// All fake data lives here. Values are read from CLI args when present;
/// otherwise sensible defaults are used so you can run `--demo` with no extra flags.
///
/// CLI arg reference
/// ─────────────────
/// --cursor-percent <0-100>    Cursor total usage %       (default: 67)
/// --cursor-plan    <string>   Cursor plan label          (default: "Included in Pro+")
/// --claude-percent <0-100>    Claude all-models usage %  (default: 82)
/// --claude-plan    <string>   Claude plan label          (default: "Claude Pro")
/// --cursor-only               Only show Cursor (Claude stays disconnected)
/// --claude-only               Only show Claude (Cursor stays disconnected)
enum DemoData {

    // MARK: - Provider activation

    static var showCursor: Bool {
        // Show cursor unless explicitly limited to claude-only
        !DemoArgs.bool("--claude-only")
    }

    static var showClaude: Bool {
        // Show claude unless explicitly limited to cursor-only
        !DemoArgs.bool("--cursor-only")
    }

    // MARK: - Snapshots

    static func snapshot(for provider: UsageProvider) -> ProviderUsageSnapshot {
        switch provider {
        case .cursor: return cursorSnapshot()
        case .claude: return claudeSnapshot()
        }
    }

    /// Cursor snapshot — defaults: 67% total, 58% auto, 12% API.
    static func cursorSnapshot() -> ProviderUsageSnapshot {
        let total  = DemoArgs.double("--cursor-percent") ?? 67
        let plan   = DemoArgs.string("--cursor-plan")   ?? "Included in Pro+"
        let auto   = min(total * 0.87, 100)
        let api    = min(total * 0.18, 100)
        return ProviderUsageSnapshot(
            planLabel: plan,
            totalUsedPercent: total,
            autoUsedPercent: auto,
            apiUsedPercent: api,
            fetchedAt: Date(),
            connectionState: .connected
        )
    }

    /// Claude snapshot — defaults: 82% all-models, 34% Claude Design.
    static func claudeSnapshot() -> ProviderUsageSnapshot {
        let allModels  = DemoArgs.double("--claude-percent") ?? 82
        let plan       = DemoArgs.string("--claude-plan")   ?? "Claude Pro"
        let design     = min(allModels * 0.42, 100)

        return ProviderUsageSnapshot(
            provider: .claude,
            planLabel: plan,
            primaryMetric: UsageMetric(
                title: "All models",
                value: DisplayFormatting.percent(allModels),
                percent: allModels
            ),
            secondaryMetrics: [
                UsageMetric(title: "All models",         value: DisplayFormatting.percent(allModels), percent: allModels),
                UsageMetric(title: "All models reset",   value: "Resets in 2 days"),
                UsageMetric(title: "Claude Design",      value: DisplayFormatting.percent(design),    percent: design),
                UsageMetric(title: "Claude Design reset",value: "Resets in 2 days")
            ],
            fetchedAt: Date(),
            connectionState: .connected
        )
    }

    // MARK: - History

    /// Pre-baked history so Recent Readings + burn-rate show up immediately.
    /// History percentages ramp up to the current snapshot value.
    static func historyEntries() -> [UsageHistoryEntry] {
        let now = Date()
        var entries: [UsageHistoryEntry] = []

        if showCursor {
            let top    = DemoArgs.double("--cursor-percent") ?? 67
            let plan   = DemoArgs.string("--cursor-plan")   ?? "Included in Pro+"
            // 6 readings spread over 3 hours, climbing from ~(top - 9) to top
            let steps: [Double] = [-9, -7, -5, -3, -1.5, 0]
            let times: [Double] = [ 3,  2.5, 1.75, 1, 0.5, 0.08]
            for (step, hoursAgo) in zip(steps, times) {
                entries.append(UsageHistoryEntry(
                    provider: .cursor,
                    percent: max(0, top + step),
                    planLabel: plan,
                    recordedAt: now.addingTimeInterval(-hoursAgo * 3600)
                ))
            }
        }

        if showClaude {
            let top  = DemoArgs.double("--claude-percent") ?? 82
            let plan = DemoArgs.string("--claude-plan")    ?? "Claude Pro"
            // 6 readings spread over 4 hours, climbing from ~(top - 11) to top
            let steps: [Double] = [-11, -8, -6, -4, -2, 0]
            let times: [Double] = [  4,  3.25, 2.5, 1.5, 0.75, 0.15]
            for (step, hoursAgo) in zip(steps, times) {
                entries.append(UsageHistoryEntry(
                    provider: .claude,
                    percent: max(0, top + step),
                    planLabel: plan,
                    recordedAt: now.addingTimeInterval(-hoursAgo * 3600)
                ))
            }
        }

        return entries.sorted { $0.recordedAt < $1.recordedAt }
    }
}

// MARK: - Disconnected stub (keeps a provider hidden in demo mode)

/// Used in demo mode when a provider is excluded (e.g. `--cursor-only` hides Claude).
@MainActor
final class DisconnectedUsageClient: ProviderUsageClient {
    let provider: UsageProvider
    init(provider: UsageProvider) { self.provider = provider }
    func connect() async throws { throw ProviderUsageError.disconnected }
    func fetchUsage() async throws -> ProviderUsageSnapshot { throw ProviderUsageError.disconnected }
    func disconnect() {}
}
