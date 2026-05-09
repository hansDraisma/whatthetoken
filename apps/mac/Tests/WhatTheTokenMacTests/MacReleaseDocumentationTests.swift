import Testing

@Test func releaseDocsDescribeGitHubHostedManualFirstUpdates() throws {
    let readme = try repositoryFileContents("README.md")
    let hosting = try repositoryFileContents("docs/release/github-hosting-and-updates.md")
    let checklist = try repositoryFileContents("docs/release/public-v1-checklist.md")

    #expect(readme.contains("manual-first"))
    #expect(readme.contains("Automatic background checks and silent installs remain disabled"))
    #expect(hosting.contains("GitHub Releases"))
    #expect(hosting.contains("GitHub Pages"))
    #expect(hosting.contains("https://hansdraisma.github.io/whatthetoken/appcast.xml"))
    #expect(checklist.contains("docs/release/github-hosting-and-updates.md"))
}

@Test func releaseRunbooksCoverPublicV1CredentialedGates() throws {
    let sandbox = try repositoryFileContents("docs/release/app-sandbox-compatibility-matrix.md")
    let sparkle = try repositoryFileContents("docs/release/sparkle-key-custody.md")
    let rollback = try repositoryFileContents("docs/release/rollback-and-hotfix.md")
    let notes = try repositoryFileContents("docs/release/release-notes-template.md")

    #expect(sandbox.contains("Keep `com.apple.security.app-sandbox` disabled for Public V1"))
    #expect(sparkle.contains("SUPublicEDKey"))
    #expect(sparkle.contains("SUFeedURL"))
    #expect(sparkle.contains("private key"))
    #expect(rollback.contains("Never reuse a build number"))
    #expect(notes.contains("Privacy And Security"))
}
