import Foundation

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settingsStore: SettingsStore
    let cursorSessionManager: CursorSessionManager
    let claudeSessionManager: ClaudeSessionManager
    let cursorUsageClient: ProviderUsageClient
    let claudeUsageClient: ProviderUsageClient
    let cursorUsageCoordinator: CursorUsageCoordinator
    let claudeUsageCoordinator: ClaudeUsageCoordinator
    let dashboardStore: DashboardStore
    let usageHistoryStore: UsageHistoryStore
    let launchAtLoginController: LaunchAtLoginController

    lazy var settingsWindowController: SettingsWindowController = {
        SettingsWindowController(
            settingsStore: settingsStore,
            dashboardStore: dashboardStore,
            cursorUsageCoordinator: cursorUsageCoordinator,
            claudeUsageCoordinator: claudeUsageCoordinator,
            launchAtLoginController: launchAtLoginController
        )
    }()
    lazy var menuBarController: MenuBarController = {
        MenuBarController(
            dashboardStore: dashboardStore,
            cursorUsageCoordinator: cursorUsageCoordinator,
            claudeUsageCoordinator: claudeUsageCoordinator,
            settingsWindowController: settingsWindowController,
            usageHistoryStore: usageHistoryStore
        )
    }()

    private init() {
        let settingsStore = SettingsStore()
        let usageHistoryStore = UsageHistoryStore()
        let launchAtLoginController = LaunchAtLoginController()

        // ── Demo mode: swap real clients for fake ones ────────────────────────
        let cursorUsageClient: ProviderUsageClient
        let claudeUsageClient: ProviderUsageClient
        let cursorSessionManager = CursorSessionManager()
        let claudeSessionManager = ClaudeSessionManager()

        if DemoMode.isEnabled {
            // Only connect providers the user asked for (--cursor-only / --claude-only)
            cursorUsageClient = DemoData.showCursor
                ? DemoUsageClient(provider: .cursor)
                : DisconnectedUsageClient(provider: .cursor)
            claudeUsageClient = DemoData.showClaude
                ? DemoUsageClient(provider: .claude)
                : DisconnectedUsageClient(provider: .claude)
            // Pre-populate history so Recent Readings + burn-rate are visible immediately
            usageHistoryStore.injectDemoData(DemoData.historyEntries())
        } else {
            cursorUsageClient = CursorDashboardClient(
                settingsStore: settingsStore,
                sessionManager: cursorSessionManager
            )
            claudeUsageClient = ClaudeDashboardClient(
                settingsStore: settingsStore,
                sessionManager: claudeSessionManager
            )
        }

        let cursorUsageCoordinator = CursorUsageCoordinator(
            settingsStore: settingsStore,
            client: cursorUsageClient
        )
        let claudeUsageCoordinator = ClaudeUsageCoordinator(
            settingsStore: settingsStore,
            client: claudeUsageClient
        )
        let dashboardStore = DashboardStore(
            settingsStore: settingsStore,
            cursorUsageCoordinator: cursorUsageCoordinator,
            claudeUsageCoordinator: claudeUsageCoordinator,
            usageHistoryStore: usageHistoryStore
        )

        self.settingsStore = settingsStore
        self.cursorSessionManager = cursorSessionManager
        self.claudeSessionManager = claudeSessionManager
        self.cursorUsageClient = cursorUsageClient
        self.claudeUsageClient = claudeUsageClient
        self.cursorUsageCoordinator = cursorUsageCoordinator
        self.claudeUsageCoordinator = claudeUsageCoordinator
        self.usageHistoryStore = usageHistoryStore
        self.dashboardStore = dashboardStore
        self.launchAtLoginController = launchAtLoginController
    }
}
