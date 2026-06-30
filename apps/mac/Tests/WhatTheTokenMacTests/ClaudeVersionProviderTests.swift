import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func installedClaudeVersionProviderParsesClaudeCodeVersion() {
    let provider = InstalledClaudeVersionProvider(
        commandRunner: StubClaudeVersionCommandRunner(
            result: .success(ClaudeVersionCommandResult(
                terminationStatus: 0,
                standardOutput: Data("2.1.126 (Claude Code)\n".utf8)
            ))
        )
    )

    #expect(provider.claudeVersion == "2.1.126")
}

@Test func installedClaudeVersionProviderFallsBackWhenCommandFails() {
    let provider = InstalledClaudeVersionProvider(
        commandRunner: StubClaudeVersionCommandRunner(
            result: .success(ClaudeVersionCommandResult(
                terminationStatus: 1,
                standardOutput: Data()
            ))
        )
    )

    #expect(provider.claudeVersion == "unknown")
}

@Test func executableResolverFindsLocalClaudeWhenPathIsRestricted() throws {
    let resolver = ClaudeVersionExecutableResolver(
        environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
        homeDirectory: URL(fileURLWithPath: "/Users/example"),
        fileExists: { path in
            path == "/Users/example/.local/bin/claude"
        }
    )

    let executableURL = try #require(resolver.executableURL())

    #expect(executableURL.path == "/Users/example/.local/bin/claude")
}

@Test func executableResolverPrefersKnownLocationOverPath() throws {
    // Hardening: a poisoned $PATH entry must not preempt a real install location.
    let resolver = ClaudeVersionExecutableResolver(
        environment: ["PATH": "/tmp/evil:/usr/bin"],
        homeDirectory: URL(fileURLWithPath: "/Users/example"),
        fileExists: { path in
            path == "/tmp/evil/claude" || path == "/opt/homebrew/bin/claude"
        }
    )

    let executableURL = try #require(resolver.executableURL())

    #expect(executableURL.path == "/opt/homebrew/bin/claude")
}

private struct StubClaudeVersionCommandRunner: ClaudeVersionCommandRunning {
    let result: Result<ClaudeVersionCommandResult, Error>

    func runClaudeVersion() throws -> ClaudeVersionCommandResult {
        try result.get()
    }
}
