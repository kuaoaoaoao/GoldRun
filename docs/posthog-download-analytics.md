# PostHog download analytics

coolRun has two download-related analytics paths:

1. Website click tracking in `docs/index.html`
2. GitHub Release asset download snapshots from GitHub Actions

## Website events

The GitHub Pages site initializes PostHog and records:

| Event | Meaning |
|---|---|
| `website_page_viewed` | A visitor opened the website |
| `download_clicked` | A visitor clicked a download link that points to GitHub Releases |
| `github_link_clicked` | A visitor clicked a GitHub repository link |
| `feedback_clicked` | A visitor clicked the GitHub Issues feedback link |
| `usage_stats_clicked` | A visitor clicked a website link to the public usage stats page |
| `usage_stats_page_viewed` | A visitor opened the public usage stats page |

Useful properties:

| Property | Meaning |
|---|---|
| `location` | Link position, such as `hero`, `download_section`, or `footer` |
| `destination` | Target type, such as `github_releases` or `repository` |
| `platform` | Intended platform, currently `macos` for download links |
| `link_url` | The URL the visitor clicked |
| `referrer_host` | The referring domain when available |

Recommended PostHog insights:

- Trend: `download_clicked`, total count, last 30 days
- Breakdown: `download_clicked` by `location`
- Funnel: `website_page_viewed` -> `download_clicked`

## GitHub Release download snapshots

GitHub does not let a project inject JavaScript into the Release page. To count direct downloads from GitHub Releases, the workflow
`.github/workflows/sync-release-downloads-to-posthog.yml` reads GitHub's Release API once per day and sends PostHog events named:

`github_release_download_snapshot`

This event is a daily snapshot, not a single user click. Use the latest value or daily difference to understand actual release asset downloads.

Useful properties:

| Property | Meaning |
|---|---|
| `release_tag` | Release tag, for example `v1.0.0` |
| `asset_name` | File name, for example `coolRun.dmg` |
| `download_count` | GitHub's cumulative download count for that asset |
| `asset_size` | Asset size in bytes |
| `browser_download_url` | Direct GitHub asset URL |
| `source` | Always `github_api` |

Recommended PostHog insights:

- Trend: `github_release_download_snapshot`, math `max(download_count)`, breakdown by `asset_name`
- Table: latest `download_count` by `release_tag` and `asset_name`
- Trend: daily downloads by subtracting yesterday's `download_count` from today's value in a PostHog SQL insight

## Manual test

After merging and publishing GitHub Pages:

1. Open the website.
2. Click `下载最新版`.
3. In PostHog, open Activity or Product analytics and search for `download_clicked`.
4. In GitHub Actions, run `Sync GitHub release downloads to PostHog` manually once.
5. In PostHog, search for `github_release_download_snapshot`.

## Public usage stats page

The public stats page lives at `docs/usage-stats.html`.

To make it show live PostHog cards:

1. Open the coolRun dashboard in PostHog.
2. Click `Share`.
3. Enable public sharing for the dashboard or the specific insight you want to embed.
4. Copy the iframe `src` URL.
5. Paste it into `POSTHOG_DASHBOARD_EMBED_URL` in `docs/usage-stats.html`.

Only publish aggregate, anonymous metrics. Avoid embedding raw events, person lists, session replay, IP addresses, or any table that can identify a user.
