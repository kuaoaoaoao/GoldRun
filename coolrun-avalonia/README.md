# GoldRun for Windows (C# / Avalonia)

GoldRun 的 C# 版 Windows 移植，使用 **Avalonia 11 + .NET 10**，可在 macOS 上开发调试、直接交叉编译出 Windows exe。

## 功能

- 系统托盘常驻，左键弹出面板（失焦自动隐藏），托盘悬停显示实时金价
- **系统监控**：CPU / 内存（Windows 原生 API）、磁盘、网速、开机时长，3 秒刷新
- **金价分析**：京东金融现价 + 分时/历史走势（1D~1Y 自绘图表）、技术指标（MA/RSI/MACD/布林/支撑压力）、多平台金价对比

## 开发（macOS / Windows 均可）

```bash
dotnet run
```

> 注：macOS 上预览时 CPU/内存显示为不可用（使用了 Windows 原生 API），其余功能正常。

## 发布 Windows exe（在 Mac 上即可）

```bash
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true
# 产物: bin/Release/net10.0/win-x64/publish/GoldRun.exe（自带运行时，免安装）
```

## 目录结构

| 文件 | 职责 |
|---|---|
| `App.axaml(.cs)` | 托盘图标、菜单、窗口定位、托盘价格轮询 |
| `MainWindow.axaml(.cs)` | 双 Tab 面板 UI 与刷新逻辑 |
| `Services/GoldService.cs` | 金价 API（现价/分时/历史/多源，含缓存） |
| `Services/TechnicalIndicators.cs` | 技术指标计算 |
| `Services/SystemSampler.cs` | 系统采样（Windows P/Invoke + 跨平台部分） |
| `Controls/PriceChart.cs` | 自绘走势图控件 |
