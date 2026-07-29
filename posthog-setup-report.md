# PostHog post-wizard report

The wizard has completed a PostHog integration for the GoldRun macOS menu bar app. Changes include:

- **`GoldRun.xcodeproj/project.pbxproj`** — Added `posthog-ios` (v3.64.1) as an SPM dependency with the three required pbxproj objects (`PBXBuildFile`, `XCSwiftPackageProductDependency`, `XCRemoteSwiftPackageReference`) and linked the Frameworks build phase.
- **`GoldRun/GoldRunApp.swift`** — Imported PostHog and called `PostHogSDK.shared.setup(config)` once in the `App` initializer, with `captureApplicationLifecycleEvents` enabled. The project token ships hardcoded in the binary (the recommended approach for iOS/macOS), with an optional Xcode-scheme override via `POSTHOG_API_KEY` / `POSTHOG_HOST` env vars.
- **`GoldRun/MacAppDelegate.swift`** — Imported PostHog; added `app_launched`, `popover_opened`, `settings_opened`, `gold_price_fetched`, and `gold_price_fetch_failed` capture calls.
- **`GoldRun/ContentView.swift`** — Imported PostHog; added `view_tab_switched` capture on tab button tap.
- **`GoldRun/SettingsView.swift`** — Imported PostHog; added `language_changed`, `menu_bar_display_mode_changed`, and `holiday_data_updated` capture calls.
- **`GoldRun/GoldAnalysisView.swift`** — Imported PostHog; added `gold_position_analyzed` capture when valid position inputs produce an advice result.
- **`.env`** — Created with `POSTHOG_API_KEY` and `POSTHOG_HOST` for reference and Xcode scheme variable setup.

## Events

| Event Name | Description | File |
|---|---|---|
| `website_page_viewed` | Fired when a visitor opens the GitHub Pages website | `docs/index.html` |
| `download_clicked` | Fired when a visitor clicks a website link to GitHub Releases | `docs/index.html` |
| `github_link_clicked` | Fired when a visitor clicks a website link to the GitHub repository | `docs/index.html` |
| `feedback_clicked` | Fired when a visitor clicks the website feedback link to GitHub Issues | `docs/index.html` |
| `usage_stats_clicked` | Fired when a visitor opens the public usage stats page from the website | `docs/index.html` |
| `usage_stats_page_viewed` | Fired when a visitor opens the public usage stats page | `docs/usage-stats.html` |
| `github_release_download_snapshot` | Daily GitHub Release asset download-count snapshot from the GitHub API | `.github/workflows/sync-release-downloads-to-posthog.yml` |
| `app_launched` | Fired once when the macOS menu bar app finishes launching | `GoldRun/MacAppDelegate.swift` |
| `popover_opened` | Fired when the user left-clicks the menu bar icon to open the monitoring popover | `GoldRun/MacAppDelegate.swift` |
| `view_tab_switched` | Fired when the user taps a module tab in the popover | `GoldRun/ContentView.swift` |
| `gold_price_fetched` | Fired each time a gold price is successfully retrieved from the 浙商银行 API | `GoldRun/MacAppDelegate.swift` |
| `gold_price_fetch_failed` | Fired when a gold price fetch fails, including the error reason | `GoldRun/MacAppDelegate.swift` |
| `settings_opened` | Fired when the user opens the Settings window from the context menu | `GoldRun/MacAppDelegate.swift` |
| `language_changed` | Fired when the user changes the app display language in Settings | `GoldRun/SettingsView.swift` |
| `menu_bar_display_mode_changed` | Fired when the user switches the menu bar display between gold price and date | `GoldRun/SettingsView.swift` |
| `holiday_data_updated` | Fired when the user triggers a holiday data refresh in the Data settings tab | `GoldRun/SettingsView.swift` |
| `gold_position_analyzed` | Fired when the user enters a valid gold holding position and profit/loss advice is computed | `GoldRun/GoldAnalysisView.swift` |

## Guardrails

- PostHog setup now goes through `GoldRun/Analytics.swift`, which validates the project token and host URL before setup.
- Set `POSTHOG_DISABLED=1` in the Xcode scheme environment to disable analytics locally.
- Event names are centralized in `AnalyticsEvent` to avoid string typos at call sites.
- Sensitive event properties are filtered before capture: `error_message`, `profit_loss`, and `profit_percent`.
- High-frequency events can be throttled with `minimumInterval`; `gold_price_fetched` is limited to once per hour and `gold_position_analyzed` to once every 30 seconds.
- User-sensitive values are bucketed where useful. Gold position analytics sends `profit_state` and `profit_percent_bucket`, not exact profit/loss values.
- GitHub Release pages cannot run custom analytics JavaScript. The website tracks outbound download clicks, and GitHub Actions syncs GitHub's cumulative Release asset `download_count` into PostHog once per day.
- Public usage stats are served from `docs/usage-stats.html`. It is ready for a public PostHog dashboard iframe, but the iframe URL must be pasted after choosing exactly which aggregate dashboard is safe to share.
- `app_launched` now includes aggregate launch properties for public stats: `app_version`, `app_build`, `os_name`, `os_version`, `cpu_arch`, `chip_model`, and `device_model`.

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events we just instrumented:

- [Analytics basics (wizard) — Dashboard](https://us.posthog.com/project/497412/dashboard/1798381)
- [App Launches Over Time](https://us.posthog.com/project/497412/insights/vKUROxWL)
- [Popover Opens & View Tab Switches](https://us.posthog.com/project/497412/insights/2mVTOLS2)
- [Gold Price Fetch Success vs Failure](https://us.posthog.com/project/497412/insights/Unj3Yk5x)
- [Settings & Customisation Activity](https://us.posthog.com/project/497412/insights/TnjxsQZB)

For download analytics details, see `docs/posthog-download-analytics.md`.

## Verify before merging

- [ ] Open the project in Xcode so it can resolve the `posthog-ios` SPM package, then do a full production Archive build and fix any errors introduced by the generated code.
- [ ] Run the test suite — any call sites that were instrumented may need updated mocks or fixtures.
- [ ] Add `POSTHOG_API_KEY` and `POSTHOG_HOST` to `.env.example` (or your team's onboarding docs) so collaborators know what values to set in their Xcode schemes for local override.

### Agent skill

We've left an agent skill folder in your project. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.
