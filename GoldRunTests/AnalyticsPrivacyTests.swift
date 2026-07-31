import XCTest
@testable import GoldRun

final class AnalyticsPrivacyTests: XCTestCase {
    func testConfigurationKeepsAutomaticCollectionAndPersonProfilesDisabled() {
        let config = Analytics.makePostHogConfiguration(
            projectToken: "phc_test",
            host: "https://us.i.posthog.com",
            enabled: true
        )

        XCTAssertFalse(config.captureApplicationLifecycleEvents)
        XCTAssertFalse(config.captureScreenViews)
        XCTAssertFalse(config.enableSwizzling)
        XCTAssertEqual(config.personProfiles, .never)
        XCTAssertFalse(config.setDefaultPersonProperties)
        XCTAssertFalse(config.preloadFeatureFlags)
        XCTAssertFalse(config.sendFeatureFlagEvent)
        XCTAssertFalse(config.errorTrackingConfig.autoCapture)
        XCTAssertFalse(config.optOut)
    }

    func testPrivacyBoundaryDropsUnknownAndSensitiveProperties() {
        let properties = Analytics.privacySafeEventProperties([
            "language": "zh-Hans",
            "success": true,
            "$app_version": "1.2.3",
            "$session_id": "anonymous-session",
            "$timezone": "Asia/Shanghai",
            "$set": ["email": "person@example.com"],
            "email": "person@example.com",
            "error_message": "private details",
            "file_path": "/Users/person/private.txt",
            "unexpected": "value",
        ])

        XCTAssertEqual(properties["language"] as? String, "zh-Hans")
        XCTAssertEqual(properties["success"] as? Bool, true)
        XCTAssertEqual(properties["$app_version"] as? String, "1.2.3")
        XCTAssertEqual(properties["$session_id"] as? String, "anonymous-session")
        XCTAssertEqual(properties["$geoip_disable"] as? Bool, true)
        XCTAssertEqual(properties["$process_person_profile"] as? Bool, false)
        XCTAssertNil(properties["$timezone"])
        XCTAssertNil(properties["$set"])
        XCTAssertNil(properties["email"])
        XCTAssertNil(properties["error_message"])
        XCTAssertNil(properties["file_path"])
        XCTAssertNil(properties["unexpected"])
    }

    func testDisabledConfigurationStartsOptedOut() {
        let config = Analytics.makePostHogConfiguration(
            projectToken: "phc_test",
            host: "https://us.i.posthog.com",
            enabled: false
        )

        XCTAssertTrue(config.optOut)
    }
}
