import Foundation

/// Decides whether a change in the local Claude credential is worth spending a
/// network refresh on. Performs no I/O.
enum ClaudeRotationDecision {
    /// Steady-state rule: the failure was observed live this session, so the
    /// stored credential is known bad. Only a change is interesting.
    static func shouldRefresh(
        previous: ClaudeCredentialProbeResult,
        current: ClaudeCredentialProbeResult,
        now: Date
    ) -> Bool {
        guard case let .found(currentFingerprint) = current else {
            return false
        }

        switch previous {
        case .absent, .unavailable:
            return true
        case let .found(previousFingerprint):
            if previousFingerprint.tokenDigest != currentFingerprint.tokenDigest {
                return true
            }

            return previousFingerprint.isExpired(at: now)
                && !currentFingerprint.isExpired(at: now)
        }
    }

    /// Start-of-watch rule for a failure restored from cache. No fingerprint is
    /// persisted across launches, so verify once when the stored credential
    /// looks usable now.
    static func shouldVerifyOnStart(
        current: ClaudeCredentialProbeResult,
        now: Date
    ) -> Bool {
        guard case let .found(fingerprint) = current else {
            return false
        }
        return !fingerprint.isExpired(at: now)
    }
}
