import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func decodesSingleBucketRateLimitResponse() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "codex",
        "limitName": null,
        "planType": "plus",
        "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 },
        "secondary": null,
        "credits": null,
        "rateLimitReachedType": null
      },
      "rateLimitsByLimitId": null
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: json)

    #expect(response.rateLimits.limitId == "codex")
    #expect(response.rateLimits.planType == "plus")
    #expect(response.rateLimits.primary?.usedPercent == 25)
    #expect(response.rateLimits.primary?.windowDurationMins == 15)
    #expect(response.rateLimits.primary?.resetsAt == 1730947200)
}

@Test func decodesMultiBucketRateLimitResponse() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "codex",
        "primary": { "usedPercent": 25 }
      },
      "rateLimitsByLimitId": {
        "codex": {
          "limitId": "codex",
          "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 }
        },
        "codex_other": {
          "limitId": "codex_other",
          "limitName": "codex_other",
          "primary": { "usedPercent": 42, "windowDurationMins": 60, "resetsAt": 1730950800 },
          "secondary": { "usedPercent": 10, "windowDurationMins": 1440, "resetsAt": null }
        }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: json)

    #expect(response.buckets.count == 2)
    #expect(response.buckets.compactMap(\.limitId).sorted() == ["codex", "codex_other"])
    #expect(response.buckets.first { $0.limitId == "codex_other" }?.secondary?.usedPercent == 10)
}

@Test func decodesCreditsShapeWithoutAssumingNumericBalance() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "codex",
        "primary": { "usedPercent": 80 },
        "credits": { "hasCredits": true, "unlimited": false, "balance": "12.50" }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: json)

    #expect(response.rateLimits.credits?.hasCredits == true)
    #expect(response.rateLimits.credits?.unlimited == false)
    #expect(response.rateLimits.credits?.balance == "12.50")
}
