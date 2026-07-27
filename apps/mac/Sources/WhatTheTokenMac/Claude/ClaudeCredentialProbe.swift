import CryptoKit
import Foundation

/// A non-secret summary of the stored Claude credential.
///
/// The watcher retains this across polls to detect rotation, so it must not
/// carry the access token itself. It must never be persisted because an
/// identifier derived from a session token is still derived from that token.
struct ClaudeCredentialFingerprint: Equatable, Sendable {
    let tokenDigest: String
    let expiresAt: Date?

    func isExpired(at now: Date) -> Bool {
        guard let expiresAt else {
            return false
        }
        return expiresAt <= now
    }
}

enum ClaudeCredentialProbeResult: Equatable, Sendable {
    /// A credential is stored and was read successfully.
    case found(ClaudeCredentialFingerprint)
    /// The Keychain has no Claude credential. This is a legitimate state.
    case absent
    /// The Keychain could not be read. Callers should back off.
    case unavailable
}

protocol ClaudeCredentialProbing: Sendable {
    func probe() async -> ClaudeCredentialProbeResult
}

/// Reads the Claude Code credential and reports only whether it changed.
/// Performs no network request.
struct ClaudeCredentialProbe: ClaudeCredentialProbing {
    let credentialStore: ClaudeCredentialStore

    init(credentialStore: ClaudeCredentialStore) {
        self.credentialStore = credentialStore
    }

    func probe() async -> ClaudeCredentialProbeResult {
        let store = credentialStore
        return await Task.detached(priority: .utility) {
            // readCredential() blocks on a `security` subprocess, so it must
            // never run on the main actor.
            do {
                guard let credential = try store.readCredential() else {
                    return .absent
                }
                return .found(
                    ClaudeCredentialFingerprint(
                        tokenDigest: Self.digest(of: credential.accessToken),
                        expiresAt: credential.expiresAt
                    )
                )
            } catch {
                return .unavailable
            }
        }.value
    }

    static func digest(of token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
