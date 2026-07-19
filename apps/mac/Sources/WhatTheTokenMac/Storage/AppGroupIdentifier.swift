import Foundation

enum AppGroupIdentifier {
    // Team-ID-prefixed macOS groups are validated by the code signature and
    // do not require a portal-managed provisioning profile.
    static let shared = "3U98C8T3DT.com.whatthetoken.mac"
}
