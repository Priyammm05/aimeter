import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var dashboardStore: DashboardStore
    @ObservedObject var cursorUsageCoordinator: CursorUsageCoordinator
    @ObservedObject var claudeUsageCoordinator: ClaudeUsageCoordinator
    @ObservedObject var usageHistoryStore: UsageHistoryStore

    let onRefreshCursor: () -> Void
    let onRefreshClaude: () -> Void
    let onConnectCursor: () -> Void
    let onConnectClaude: () -> Void
    let onDisconnectCursor: () -> Void
    let onDisconnectClaude: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        let state = dashboardStore.state
        let connectedSnapshots = state.connectedProviderSnapshots
        let popoverHeight = preferredHeight(
            state: state,
            connectedProviderCount: connectedSnapshots.count
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()

                if shouldShowInitialLoading(connectedProviderCount: connectedSnapshots.count) {
                    initialLoadingContent
                } else if state.presentationState == .firstRun || connectedSnapshots.isEmpty {
                    firstRunContent
                } else {
                    ForEach(connectedSnapshots, id: \.provider) { snapshot in
                        providerSection(snapshot)
                    }
                    Divider()
                    footer(state)
                }
            }
            .padding(14)
        }
        .frame(width: 390, height: popoverHeight, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AIMeter")
                    .font(.headline)
                Spacer()
                if isAnyProviderBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")
            }

            if dashboardStore.state.presentationState == .firstRun {
                Text("Track Cursor and Claude usage from signed-in local web sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - State helpers

    private var isAnyProviderBusy: Bool {
        cursorUsageCoordinator.isRefreshing ||
            cursorUsageCoordinator.isConnecting ||
            claudeUsageCoordinator.isRefreshing ||
            claudeUsageCoordinator.isConnecting
    }

    private var isAnyProviderRefreshing: Bool {
        cursorUsageCoordinator.isRefreshing || claudeUsageCoordinator.isRefreshing
    }

    private var hasLoadedProviderState: Bool {
        cursorUsageCoordinator.hasLoadedOnce && claudeUsageCoordinator.hasLoadedOnce
    }

    private func shouldShowInitialLoading(connectedProviderCount: Int) -> Bool {
        connectedProviderCount == 0 &&
            (isAnyProviderRefreshing || !hasLoadedProviderState)
    }

    private func preferredHeight(
        state: DashboardState,
        connectedProviderCount: Int
    ) -> CGFloat {
        if state.presentationState == .firstRun || connectedProviderCount == 0 {
            return 420
        }
        return connectedProviderCount == 1 ? 480 : 740
    }

    // MARK: - First-run content

    private var firstRunContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connect a Provider")
                    .font(.title3.weight(.semibold))
                Text("AIMeter reads usage from signed-in provider pages. No API key is required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            onboardingTile(
                description: "Track total plan usage, Auto usage, and API usage from your Cursor settings dashboard.",
                buttonTitle: "Connect Cursor",
                action: onConnectCursor
            )

            onboardingTile(
                provider: .claude,
                description: "Track Claude usage, limits, and reset information when Claude exposes it in your account session.",
                buttonTitle: "Connect Claude",
                action: onConnectClaude
            )

            HStack {
                Spacer()
                Button("Quit", action: onQuit)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var initialLoadingContent: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 76)
            ProgressView()
                .controlSize(.regular)
            Text("Checking connected sessions...")
                .font(.headline)
            Text("AIMeter is loading saved Cursor and Claude sessions.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 76)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Provider section

    private func providerSection(_ snapshot: ProviderUsageSnapshot) -> some View {
        let statusMetrics = displayStatusMetrics(for: snapshot)
        let usageMetrics = displayUsageMetrics(for: snapshot)
        let primaryResetText = primaryResetText(for: snapshot, statusMetrics: statusMetrics)
        let unpairedStatusMetrics = unpairedStatusMetrics(
            statusMetrics,
            snapshot: snapshot,
            usageMetrics: usageMetrics
        )
        let historyEntries = usageHistoryStore.recentEntries(for: snapshot.provider, limit: 5)
        let delta = usageHistoryStore.latestDelta(for: snapshot.provider)
        let burnRatePerHour = usageHistoryStore.burnRate(for: snapshot.provider)

        return VStack(alignment: .leading, spacing: 12) {

            // ── Provider header ──
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.provider.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(snapshot.planLabel)
                            .font(.title3.weight(.semibold))
                        if let delta {
                            trendBadge(delta: delta)
                        }
                    }
                    Text(snapshot.connectionState.displayText)
                        .font(.caption)
                        .foregroundStyle(providerStatusColor(for: snapshot.connectionState))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(snapshot.primaryMetric.value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                    if let burnRatePerHour, burnRatePerHour > 0.1 {
                        Text(burnRateLabel(burnRatePerHour))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // ── Progress bar ──
            if let progressPercent = snapshot.progressPercent {
                ProgressView(value: progressPercent / 100)
                    .tint(providerProgressColor(for: progressPercent))
            }

            // ── Reset text ──
            if let primaryResetText {
                Text(primaryResetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // ── Unpaired status metrics ──
            if !unpairedStatusMetrics.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(unpairedStatusMetrics, id: \.title) { metric in
                        statusMetricLine(metric)
                    }
                }
            }

            // ── Usage metric cards ──
            if !usageMetrics.isEmpty {
                HStack(spacing: 10) {
                    ForEach(usageMetrics, id: \.title) { metric in
                        metricCard(
                            title: metric.title,
                            value: metric.value,
                            percent: metric.percent,
                            subtitle: resetText(for: metric, statusMetrics: statusMetrics)
                        )
                    }
                }
            }

            // ── Usage history ──
            if historyEntries.count >= 2 {
                usageHistorySection(entries: historyEntries)
            }

            // ── Quick stats ──
            if let burnRatePerHour, snapshot.progressPercent != nil {
                quickStatsRow(snapshot: snapshot, burnRatePerHour: burnRatePerHour)
            }

            // ── Sync footer & actions ──
            providerFooter(
                lastSync: snapshot.fetchedAt,
                message: providerMessage(for: snapshot)
            )

            HStack {
                Button("Refresh", action: actions(for: snapshot.provider).refresh)
                    .buttonStyle(.bordered)
                    .disabled(coordinator(for: snapshot.provider).isRefreshing || coordinator(for: snapshot.provider).isConnecting)

                if snapshot.connectionState == .connected {
                    // Connected: Reconnect is secondary, Disconnect is the prominent action
                    Button(connectButtonTitle(for: snapshot), action: actions(for: snapshot.provider).connect)
                        .buttonStyle(.bordered)
                        .disabled(coordinator(for: snapshot.provider).isConnecting)

                    Button("Disconnect", action: actions(for: snapshot.provider).disconnect)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                } else {
                    // Not connected: Connect is the prominent call-to-action
                    Button(connectButtonTitle(for: snapshot), action: actions(for: snapshot.provider).connect)
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator(for: snapshot.provider).isConnecting)

                    Button("Disconnect", action: actions(for: snapshot.provider).disconnect)
                        .buttonStyle(.bordered)
                        .disabled(true)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Usage history section

    private func usageHistorySection(entries: [UsageHistoryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("RECENT READINGS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .kerning(0.5)
            }

            VStack(spacing: 3) {
                ForEach(entries.indices, id: \.self) { index in
                    let entry = entries[index]
                    let prevPercent: Double? = index + 1 < entries.count ? entries[index + 1].percent : nil
                    historyRow(entry: entry, previousPercent: prevPercent, isLatest: index == 0)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
    }

    private func historyRow(entry: UsageHistoryEntry, previousPercent: Double?, isLatest: Bool) -> some View {
        HStack(spacing: 0) {
            // Timestamp
            Text(DisplayFormatting.relativeTimestamp(entry.recordedAt))
                .font(.caption2)
                .foregroundStyle(isLatest ? .secondary : .tertiary)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)

            Spacer()

            // Percentage
            Text(DisplayFormatting.percent(entry.percent))
                .font(.caption2.monospacedDigit())
                .fontWeight(isLatest ? .semibold : .regular)
                .foregroundStyle(isLatest ? usageColor(entry.percent) : .secondary)

            // Delta indicator
            if let prev = previousPercent {
                let delta = entry.percent - prev
                deltaChip(delta: delta)
                    .frame(width: 60, alignment: .trailing)
            } else {
                Color.clear.frame(width: 60, height: 1)
            }
        }
    }

    private func deltaChip(delta: Double) -> some View {
        let isUp = delta > 0.2
        let isDown = delta < -0.2
        let formatted = String(format: "%+.1f%%", delta)
        let icon = isUp ? "arrow.up" : (isDown ? "arrow.down" : "minus")
        let color: Color = isUp ? .orange : (isDown ? .green : .secondary)

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .bold))
            Text(formatted)
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(color)
    }

    // MARK: - Quick stats row

    private func quickStatsRow(snapshot: ProviderUsageSnapshot, burnRatePerHour: Double) -> some View {
        let remaining = 100 - (snapshot.progressPercent ?? 0)
        let hoursLeft = burnRatePerHour > 0 ? remaining / burnRatePerHour : nil

        return HStack(spacing: 8) {
            quickStatChip(
                icon: "flame",
                label: "Burn rate",
                value: burnRateLabel(burnRatePerHour)
            )

            if let hoursLeft, hoursLeft.isFinite, hoursLeft > 0 {
                quickStatChip(
                    icon: "hourglass",
                    label: "Est. remaining",
                    value: hoursRemainingLabel(hoursLeft)
                )
            }
        }
    }

    private func quickStatChip(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.caption2.monospacedDigit())
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
    }

    // MARK: - Trend badge

    private func trendBadge(delta: Double) -> some View {
        let isUp = delta > 0.5
        let isDown = delta < -0.5
        let icon = isUp ? "arrow.up.right" : (isDown ? "arrow.down.right" : "minus")
        let color: Color = isUp ? .orange : (isDown ? .green : .secondary)

        return Image(systemName: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
    }

    // MARK: - Metric helpers

    private func displayUsageMetrics(for snapshot: ProviderUsageSnapshot) -> [UsageMetric] {
        let metrics = snapshot.secondaryMetrics.filter { $0.percent != nil }
        guard snapshot.provider == .claude else {
            return metrics.removingDuplicateTitles()
        }

        return ["All models", "Claude Design"].compactMap { title in
            metrics.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
        }
    }

    private func displayStatusMetrics(for snapshot: ProviderUsageSnapshot) -> [UsageMetric] {
        let metrics = snapshot.secondaryMetrics.filter { $0.percent == nil }
        guard snapshot.provider == .claude else {
            return metrics.removingDuplicateTitles()
        }

        let titles = ["Reset", "All models reset", "Claude Design reset"]
        return titles.compactMap { title in
            metrics.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
        }
    }

    private func statusMetricLine(_ metric: UsageMetric) -> some View {
        HStack(spacing: 6) {
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(metric.value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func primaryResetText(
        for snapshot: ProviderUsageSnapshot,
        statusMetrics: [UsageMetric]
    ) -> String? {
        statusMetrics.first { metric in
            metric.title.caseInsensitiveCompare("Reset") == .orderedSame ||
                metric.title.caseInsensitiveCompare("\(snapshot.primaryMetric.title) reset") == .orderedSame
        }?.value
    }

    private func resetText(
        for usageMetric: UsageMetric,
        statusMetrics: [UsageMetric]
    ) -> String? {
        statusMetrics.first { metric in
            metric.title.caseInsensitiveCompare("\(usageMetric.title) reset") == .orderedSame
        }?.value
    }

    private func unpairedStatusMetrics(
        _ statusMetrics: [UsageMetric],
        snapshot: ProviderUsageSnapshot,
        usageMetrics: [UsageMetric]
    ) -> [UsageMetric] {
        statusMetrics.filter { metric in
            if metric.title.caseInsensitiveCompare("Reset") == .orderedSame ||
                metric.title.caseInsensitiveCompare("\(snapshot.primaryMetric.title) reset") == .orderedSame {
                return false
            }

            return !usageMetrics.contains { usageMetric in
                metric.title.caseInsensitiveCompare("\(usageMetric.title) reset") == .orderedSame
            }
        }
    }

    // MARK: - Footer

    private func footer(_ state: DashboardState) -> some View {
        HStack {
            Text("Last dashboard sync: \(DisplayFormatting.relativeTimestamp(state.lastRefreshAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit", action: onQuit)
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Onboarding tile

    private func onboardingTile(
        provider: UsageProvider = .cursor,
        description: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(provider == .cursor ? Color.blue : Color.purple)
                    .frame(width: 8, height: 8)
                Text(provider.displayName)
                    .font(.headline)
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Metric card

    private func metricCard(title: String, value: String, percent: Double? = nil, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(2)
                .foregroundStyle(percent.map { providerProgressColor(for: $0) } ?? .primary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
    }

    // MARK: - Provider footer

    private func providerFooter(lastSync: Date?, message: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last sync: \(DisplayFormatting.relativeTimestamp(lastSync))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Color helpers

    private func usageColor(_ percent: Double) -> Color {
        switch percent {
        case 86...: return .red       // ≥ 86% — critical
        case 61...: return .orange    // 61–85% — warning
        default:    return .green     // ≤ 60% — healthy
        }
    }

    private func providerProgressColor(for percent: Double) -> Color {
        switch percent {
        case 86...: return .red
        case 61...: return .orange
        default:    return .green
        }
    }

    private func providerStatusColor(for state: ProviderConnectionState) -> Color {
        switch state {
        case .connected:             return .green
        case .disconnected:          return .secondary
        case .authExpired, .syncFailed: return .orange
        }
    }

    // MARK: - Label helpers

    private func connectButtonTitle(for snapshot: ProviderUsageSnapshot) -> String {
        switch snapshot.connectionState {
        case .connected:
            return "Reconnect"
        case .disconnected, .authExpired, .syncFailed:
            return "Connect \(snapshot.provider.displayName)"
        }
    }

    private func providerMessage(for snapshot: ProviderUsageSnapshot) -> String? {
        switch snapshot.connectionState {
        case .connected:
            return nil
        case .authExpired:
            return "Reconnect \(snapshot.provider.displayName) to refresh usage."
        case .disconnected:
            return "Connect \(snapshot.provider.displayName) to start tracking usage."
        case .syncFailed(let reason):
            return reason
        }
    }

    private func burnRateLabel(_ ratePerHour: Double) -> String {
        String(format: "+%.1f%%/hr", ratePerHour)
    }

    private func hoursRemainingLabel(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60))m left"
        } else if hours < 24 {
            return String(format: "%.1fh left", hours)
        } else {
            return String(format: "%.1fd left", hours / 24)
        }
    }

    // MARK: - Coordinator / actions

    private func coordinator(for provider: UsageProvider) -> ProviderUsageCoordinator {
        switch provider {
        case .cursor: return cursorUsageCoordinator
        case .claude: return claudeUsageCoordinator
        }
    }

    private func actions(for provider: UsageProvider) -> (refresh: () -> Void, connect: () -> Void, disconnect: () -> Void) {
        switch provider {
        case .cursor: return (onRefreshCursor, onConnectCursor, onDisconnectCursor)
        case .claude: return (onRefreshClaude, onConnectClaude, onDisconnectClaude)
        }
    }
}

// MARK: - Extensions

private extension Array where Element == UsageMetric {
    func removingDuplicateTitles() -> [UsageMetric] {
        var seen: Set<String> = []
        return filter { metric in
            seen.insert(metric.title.lowercased()).inserted
        }
    }
}
