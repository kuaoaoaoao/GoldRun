# GoldRun 隐私说明

生效日期：2026-07-29

GoldRun 以本地处理为默认原则。系统指标、生日、倒数日、英语学习进度、黄金持仓和交易记录不会发送给 GoldRun 项目维护者。

## 本地保存的数据

- 系统监控：CPU、内存、磁盘、电池、网络、温度和进程信息只在当前 Mac 采样和展示。
- 日历：生日、倒数日和应用设置保存在 `UserDefaults`。使用带有 iCloud 能力的签名构建时，部分轻量数据可以通过用户自己的 iCloud KVS 同步。
- 英语学习：学习进度和自定义教材保存在 Application Support 目录。
- 金价：历史行情、预测记录、交易流水和持仓输入保存在本机。
- AI 监控：Codex 模块读取本机 Codex app-server 和任务记录；Claude 模块只读 `~/.claude/.credentials.json` 中的 OAuth 凭据以请求 Anthropic 用量接口。访问令牌不会写入 GoldRun 数据文件、备份或匿名统计。

## 网络请求

只有使用对应功能时，应用才会访问相关服务：

| 功能 | 目标服务 | 用途 |
| --- | --- | --- |
| 国内金价与走势 | `ms.jr.jd.com`、`api.jdjygold.com` | 当前金价、分时和历史走势 |
| 多来源金价 | `gold.rsky.cn` | 对比不同报价来源 |
| 国际市场 | `hq.sinajs.cn` | 伦敦金、美元指数和汇率参考 |
| 市场背景 | `news.google.com`、`home.treasury.gov` | 公开新闻标题和美国国债收益率 |
| Claude 额度 | `api.anthropic.com` | 使用本机 Claude Code 登录凭据读取额度 |
| 更新检查 | `api.github.com` | 读取 GoldRun 最新 Release |
| 可选匿名统计 | 配置的 PostHog 主机 | 仅在用户主动开启且构建者配置令牌后发送允许列表中的产品事件 |

第三方服务会按各自的隐私政策处理网络元数据。GoldRun 无法控制第三方接口的可用性或日志保留策略。

## 匿名使用统计

- 新安装和开源构建默认关闭。
- 未配置 `POSTHOG_API_KEY` 的构建无法开启统计。
- 开启后只发送 `AnalyticsEvent` 中明确列出的事件以及应用版本、macOS 版本、CPU 架构和设备型号等诊断属性。
- 不发送生日、倒数日、备注、持仓、盈亏金额、账号、访问令牌、错误正文或文件路径。
- 可以随时在“设置 → 通用 → 隐私”关闭。

## 通知

金价提醒和 AI 额度提醒都需要用户主动开启。应用只在首次开启相关提醒时请求 macOS 通知权限。AI 额度仅在 AI 面板可见时检查。

## 备份

`.goldrun` 备份是未加密的本地 JSON 文件，可能包含生日、倒数日、学习进度、黄金记录与持仓和设置。请像保护其他个人备份一样保存该文件，不要直接上传到公开 Issue。

## 问题与请求

发现隐私或安全问题时，请按 [SECURITY.md](SECURITY.md) 中的方式私下报告。普通隐私问题可以在 GitHub Discussions 中提出。
