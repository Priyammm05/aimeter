import Foundation

/// Controls demo / preview mode. The flag is **always `false`** in normal operation.
///
/// To enable, launch the app with the `--demo` argument:
///
///     # From the terminal (binary path)
///     /Applications/AIMeter.app/Contents/MacOS/AIMeter --demo
///
///     # Using `open` (re-launches even if already running)
///     open -n /Applications/AIMeter.app --args --demo
///
///     # Xcode: Product → Scheme → Edit Scheme → Run → Arguments Passed On Launch → + `--demo`
///
/// Demo mode shows realistic fake data for both Cursor and Claude without
/// requiring any real connection or credentials.
enum DemoMode {
    /// `true` only when the process was launched with `--demo`.
    /// Evaluated once — safe to call many times.
    static let isEnabled: Bool = CommandLine.arguments.contains("--demo")
}
