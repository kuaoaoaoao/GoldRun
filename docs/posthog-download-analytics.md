# PostHog release download analytics

CoolRun 的 GitHub Pages 当前不加载 PostHog SDK，也不发送页面访问或链接点击事件。网站上的下载按钮直接跳转到 GitHub Releases。

## GitHub Release 下载快照

GitHub Release 页面不能注入项目自己的 JavaScript。仓库通过
`.github/workflows/sync-release-downloads-to-posthog.yml` 每天读取一次 GitHub Release API，并可选发送以下事件：

`github_release_download_snapshot`

这是一份 Release 资源累计下载量快照，不代表单个用户点击。工作流只有在仓库配置了
`POSTHOG_PROJECT_API_KEY` secret 时才会上报；没有 secret 时会安全跳过。

常用属性：

| 属性 | 含义 |
| --- | --- |
| `release_tag` | Release 标签，例如 `v1.0.0` |
| `asset_name` | 资源文件名，例如 `CoolRun.dmg` |
| `download_count` | GitHub 返回的累计下载次数 |
| `asset_size` | 资源大小，单位为字节 |
| `browser_download_url` | GitHub 资源下载地址 |
| `source` | 固定为 `github_api` |

推荐统计方式：

- 按 `asset_name` 查看最新 `download_count`。
- 用相邻日期的累计值差计算每日下载量。
- 不要把快照事件当作唯一访客或真实会话数量。

## 公开统计页

公开统计页位于 `docs/usage-stats.html`，默认不加载任何远程看板。需要展示聚合数据时：

1. 在 PostHog 中创建只包含聚合指标的公开 Dashboard。
2. 启用公开分享并复制 iframe 地址。
3. 将地址填入 `docs/usage-stats.html` 的 `POSTHOG_DASHBOARD_EMBED_URL`。

不要公开原始事件、人员列表、会话回放、IP 地址或其他可以识别个人的信息。变更网页统计行为时，也要同步更新根目录的 `PRIVACY.md`。
