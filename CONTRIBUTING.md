# 参与贡献

感谢你帮助改进 GoldRun。macOS 菜单栏应用是当前主实现；`goldrun-windows` 和 `goldrun-avalonia` 是实验性端口，不保证功能一致。

## 开发环境

- macOS 15 或更高版本
- Xcode 16.4 或更高版本，建议使用最新稳定版
- Git

打开工程：

```bash
git clone https://github.com/kuaoaoaoao/GoldRun.git
cd GoldRun
open GoldRun.xcodeproj
```

命令行构建与测试：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project GoldRun.xcodeproj \
  -scheme GoldRun \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/GoldRun-derived \
  CODE_SIGNING_ALLOWED=NO \
  test
```

CI 测试会设置 `POSTHOG_DISABLED=1`。本地和 fork 构建不需要任何分析令牌。

## 提交改动

1. 先搜索已有 Issue。
2. 每个 Pull Request 只解决一个清晰问题。
3. 不要提交 `.env`、账号、访问令牌、备份、IDE 状态、DMG 或 DerivedData。
4. 新功能需要有明确的失败状态、空状态和可恢复方式。
5. 影响用户数据格式时必须兼容旧版本，并补迁移测试。
6. 影响菜单栏界面时至少检查 320×512 尺寸、浅色/深色、键盘导航、VoiceOver 标签和 Reduce Motion。

## 代码约定

- 优先使用 SwiftUI；只有系统菜单栏、窗口或 SwiftUI 无法覆盖的能力才使用 AppKit。
- 异步任务必须可取消，视图消失后不得继续无意义轮询。
- 不新增第三方依赖，除非 Pull Request 解释了必要性、许可证和替代方案。
- 网络服务必须设置超时，并在失败时保留缓存或显示可操作提示。
- 用户数据默认保存在本地；新增上传行为必须默认关闭并同步更新 `PRIVACY.md`。
- 文案至少提供简体中文和英文；面向现有多语言界面的文案还应补日文、韩文。

## 测试建议

- 纯计算逻辑使用单元测试，不依赖实时网络。
- 网络解析使用固定 JSON/XML fixture 或自定义 `URLProtocol`。
- 关键菜单栏页面使用 `NSHostingView` 做固定尺寸渲染测试。
- 提交前运行完整 `xcodebuild test` 和 `git diff --check`。

## 发布与遥测配置

维护者如需在自己的发行构建中启用 PostHog，可以把 `POSTHOG_API_KEY` 和可选的 `POSTHOG_HOST` 作为 Xcode 构建设置或 Scheme 环境变量提供。令牌不得硬编码进源码。手动运行 `Package unsigned macOS build` 时，可在仓库中配置 `POSTHOG_PROJECT_API_KEY` Secret 和可选的 `POSTHOG_HOST` Variable；未配置 Secret 时，生成的应用仍保持统计不可用。无论构建是否配置令牌，用户都必须在应用设置中主动开启匿名统计。

本地 `.env` 仅用于保存参考值，Xcode 不会自动读取它。请把 `.env.example` 复制为 `.env`，再将对应值加入 Scheme 的 Environment Variables，或作为 `xcodebuild` 构建设置传入。

仓库当前不依赖付费 Apple Developer Program 账号发布。维护者可以手动运行
`Package unsigned macOS build` Action 获取 ad hoc 签名的 ZIP 和 SHA-256，并在 Release 中明确标注“未使用 Developer ID、未经 Apple 公证”。不要把这种临时签名描述成 Apple 已验证或安全认证。

## 许可证

提交代码即表示：

1. 你有权提交该贡献，并且该贡献不侵犯第三方权利；
2. 你同意该贡献随项目按 [PolyForm Noncommercial License 1.0.0](LICENSE) 提供；
3. 你向项目版权所有者授予永久的、全球性的、非独占的、免许可费且不可撤销的权利，允许其使用、复制、修改、分发并以项目许可证或单独的商业许可证再次许可该贡献。

如你不同意上述贡献授权，请不要提交 Pull Request。
