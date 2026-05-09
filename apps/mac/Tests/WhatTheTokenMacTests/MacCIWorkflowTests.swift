import Testing

@Test func ciBuildsXcodeAppTargetWithSigningDisabled() throws {
    let workflow = try repositoryFileContents(".github/workflows/test.yml")

    #expect(workflow.contains("Build Mac Xcode app target"))
    #expect(workflow.contains("xcodebuild -project apps/mac/WhatTheToken.xcodeproj"))
    #expect(workflow.contains("-scheme WhatTheToken"))
    #expect(workflow.contains("-configuration Debug"))
    #expect(workflow.contains("-destination 'platform=macOS'"))
    #expect(workflow.contains("CODE_SIGNING_ALLOWED=NO"))
    #expect(workflow.contains("build"))
}
