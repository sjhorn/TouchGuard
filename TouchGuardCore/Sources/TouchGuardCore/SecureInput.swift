import Carbon.HIToolbox

/// Secure Event Input: while any app has it on (usually a password field, a
/// terminal's Secure Keyboard Entry or a password manager), macOS hides key
/// events from every event tap, so TouchGuard can't see typing and blocks nothing.
/// It can get stuck on after the app that enabled it quits; logging out clears it.
public enum SecureInput {
    public static var isEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
