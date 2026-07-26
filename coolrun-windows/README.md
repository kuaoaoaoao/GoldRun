# coolRun for Windows

coolRun macOS 菜单栏应用的 Windows 托盘版，基于 **Tauri 2**（Rust 后端 + TypeScript 前端）。

## 功能

- **系统监控**：CPU / 内存 / 磁盘 / 网络速率 / 开机时长 / 温度传感器
- **金价分析**：京东金融现价与走势（1D~1Y）、多平台金价对比、技术指标（RSI / MACD / 布林带 / 支撑压力位）
- **托盘常驻**：左键点击托盘弹出面板，悬停显示实时金价，右键菜单退出

## 目录结构

```
coolrun-windows/
├── index.html            # 面板页面
├── src/                  # 前端（TypeScript + 原生 DOM，无框架）
│   ├── main.ts           # 数据轮询、图表绘制、Tab 切换
│   └── styles.css        # 暗色玻璃风样式
└── src-tauri/            # Rust 后端
    └── src/
        ├── lib.rs        # 托盘、窗口、命令注册
        ├── gold.rs       # 金价数据源（移植 GoldPriceService / GoldMarketDataService）
        ├── indicators.rs # 技术指标（移植 TechnicalIndicators）
        └── system.rs     # 系统采样（sysinfo，对应 SystemSampler）
```

## 开发

前置：Node.js 20+、Rust stable（`rustup` 安装）。

```bash
cd coolrun-windows
npm install
npm run tauri dev     # macOS 上也可运行调试（托盘 + 面板）
```

## 打包 Windows 安装包

推荐用 GitHub Actions（`.github/workflows/build-windows.yml`）：

- 推送 `win-v*` 标签（如 `win-v0.1.0`）自动构建并发布 Release
- 或在 Actions 页面手动触发 `Build Windows App`
- 产物：NSIS 安装器（`.exe`）与 MSI 包

本机（需 Windows）：`npm run tauri build`。

## 与 macOS 版的差异

| 能力 | 说明 |
|---|---|
| 温度/风扇 | 用 sysinfo 读取，部分机型需管理员权限；风扇转速暂不支持（可后续接 LibreHardwareMonitor） |
| 托盘价格 | Windows 托盘不支持文字，金价显示在托盘悬停提示中 |
| 数据缓存 | 与 macOS 版一致：分时 2 分钟 / 历史 30 分钟 / 多源 5 分钟 |
