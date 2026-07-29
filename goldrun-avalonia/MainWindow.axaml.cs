using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using GoldRun.Services;

namespace GoldRun;

public partial class MainWindow : Window
{
    private static readonly IBrush RisingBrush = new SolidColorBrush(Color.FromRgb(0xF0, 0x52, 0x4F));
    private static readonly IBrush FallingBrush = new SolidColorBrush(Color.FromRgb(0x34, 0xC7, 0x7B));
    private static readonly IBrush NeutralBrush = new SolidColorBrush(Color.FromRgb(0x8B, 0x90, 0xA0));
    private static readonly IBrush ValueBrush = new SolidColorBrush(Color.FromRgb(0xE8, 0xEA, 0xF0));

    private readonly DispatcherTimer _systemTimer;
    private readonly DispatcherTimer _goldTimer;
    private string _currentRange = "today";
    private bool _goldLoadedOnce;

    public MainWindow()
    {
        InitializeComponent();

        // 系统监控每 3 秒采样，与 macOS 版一致
        _systemTimer = new DispatcherTimer(TimeSpan.FromSeconds(3), DispatcherPriority.Normal,
            (_, _) => RefreshSystem());
        // 金价每 60 秒刷新
        _goldTimer = new DispatcherTimer(TimeSpan.FromSeconds(60), DispatcherPriority.Normal,
            (_, _) => _ = RefreshGoldAsync());

        Opened += (_, _) =>
        {
            RefreshSystem();
            _systemTimer.Start();
        };
        // 失焦自动隐藏（托盘面板行为）
        Deactivated += (_, _) => Hide();
    }

    // MARK: Tab 切换

    private void OnSystemTabClicked(object? sender, RoutedEventArgs e) => SwitchTab(system: true);

    private void OnGoldTabClicked(object? sender, RoutedEventArgs e) => SwitchTab(system: false);

    private void SwitchTab(bool system)
    {
        SystemPage.IsVisible = system;
        GoldPage.IsVisible = !system;
        SystemTabButton.Classes.Set("active", system);
        GoldTabButton.Classes.Set("active", !system);

        if (!system)
        {
            _goldTimer.Start();
            if (!_goldLoadedOnce)
            {
                _goldLoadedOnce = true;
                _ = RefreshGoldAsync();
            }
        }
        else
        {
            _goldTimer.Stop();
        }
    }

    // MARK: 系统监控

    private void RefreshSystem()
    {
        if (!SystemPage.IsVisible || !IsVisible)
        {
            return;
        }

        var snapshot = SystemSampler.Shared.Sample();

        if (snapshot.CpuUsage is { } cpu)
        {
            CpuUsageText.Text = $"{cpu * 100:F0}%";
            CpuBar.Value = cpu;
        }
        else
        {
            CpuUsageText.Text = "--%";
            CpuBar.Value = 0;
        }
        CpuDetailText.Text = $"{snapshot.CoreCount} 核心";

        if (snapshot is { MemoryUsed: { } used, MemoryTotal: { } total } && total > 0)
        {
            var ratio = (double)used / total;
            MemUsageText.Text = $"{ratio * 100:F0}%";
            MemBar.Value = ratio;
            MemDetailText.Text = $"{FormatBytes(used)} / {FormatBytes(total)}";
        }
        else
        {
            MemUsageText.Text = "--%";
            MemBar.Value = 0;
            MemDetailText.Text = "仅 Windows 支持";
        }

        if (snapshot.StorageTotal > 0)
        {
            var ratio = (double)snapshot.StorageUsed / snapshot.StorageTotal;
            DiskUsageText.Text = $"{ratio * 100:F0}%";
            DiskBar.Value = ratio;
            DiskDetailText.Text = $"{FormatBytes(snapshot.StorageUsed)} / {FormatBytes(snapshot.StorageTotal)}";
        }

        NetSpeedText.Text = $"↓ {FormatBytes(snapshot.DownloadSpeed)}/s  ↑ {FormatBytes(snapshot.UploadSpeed)}/s";
        UptimeText.Text = FormatUptime(snapshot.Uptime);
    }

    // MARK: 金价分析

    private async Task RefreshGoldAsync()
    {
        if (!GoldPage.IsVisible)
        {
            return;
        }

        await Task.WhenAll(
            RefreshQuoteAsync(),
            RefreshChartAsync(_currentRange),
            RefreshTechnicalAsync(),
            RefreshMultiSourceAsync());
    }

    private async Task RefreshQuoteAsync()
    {
        try
        {
            var quote = await GoldService.Shared.FetchQuoteAsync();
            GoldPriceText.Text = $"¥{quote.CnyPerGram:F2}";
            GoldUpdatedText.Text =
                $"更新于 {quote.UpdatedAt.ToLocalTime():HH:mm:ss}{(quote.IsMarketClosed ? " · 休市" : "")}";

            if (quote is { ChangeAmount: { } amount, ChangeRatePercent: { } rate })
            {
                GoldChangeText.Text = $"{amount:+0.00;-0.00} ({rate:+0.00;-0.00}%)";
                GoldChangeText.Foreground = amount >= 0 ? RisingBrush : FallingBrush;
            }
            else
            {
                GoldChangeText.Text = "--";
                GoldChangeText.Foreground = NeutralBrush;
            }
            FooterStatus.Text = $"数据源: {quote.Source} · {DateTime.Now:HH:mm:ss}";
        }
        catch (Exception error)
        {
            FooterStatus.Text = $"金价加载失败: {error.Message}";
        }
    }

    private async Task RefreshChartAsync(string range)
    {
        try
        {
            var points = range == "today"
                ? await GoldService.Shared.FetchTodayPricesAsync()
                : await GoldService.Shared.FetchHistoryPricesAsync(range);

            Chart.Points = points;
            var format = range == "today" ? "HH:mm" : "MM-dd";
            ChartStartText.Text = points[0].Timestamp.ToLocalTime().ToString(format);
            ChartEndText.Text = points[^1].Timestamp.ToLocalTime().ToString(format);
        }
        catch (Exception error)
        {
            FooterStatus.Text = $"走势加载失败: {error.Message}";
        }
    }

    private async Task RefreshTechnicalAsync()
    {
        try
        {
            var history = await GoldService.Shared.FetchHistoryPricesAsync("q");
            var quote = await GoldService.Shared.FetchQuoteAsync();
            var prices = history.Select(p => p.Price).ToList();
            var snapshot = TechnicalIndicators.BuildSnapshot(prices, quote.CnyPerGram);

            IndicatorGrid.Children.Clear();
            AddIndicator("MA5", Format2(snapshot.Sma5));
            AddIndicator("MA20", Format2(snapshot.Sma20));
            AddIndicator("RSI(14)", Format2(snapshot.Rsi14));
            AddIndicator("MACD", Format2(snapshot.MacdHistogram, "F3"));
            AddIndicator("布林上轨", Format2(snapshot.BollingerUpper));
            AddIndicator("布林下轨", Format2(snapshot.BollingerLower));
            AddIndicator("支撑位", Format2(snapshot.SupportLevel));
            AddIndicator("压力位", Format2(snapshot.ResistanceLevel));

            TechHintText.Text = BuildHint(snapshot);
        }
        catch
        {
            TechHintText.Text = "技术指标加载失败";
        }
    }

    private async Task RefreshMultiSourceAsync()
    {
        try
        {
            var prices = await GoldService.Shared.FetchMultiSourcePricesAsync();
            MultiSourceList.Children.Clear();
            foreach (var item in prices)
            {
                var row = new DockPanel { Margin = new Avalonia.Thickness(0, 3) };
                var name = new TextBlock
                {
                    Text = item.Name,
                    Foreground = NeutralBrush,
                    FontSize = 12,
                };
                var value = new TextBlock
                {
                    Text = item.ChangeRatePercent is { } rate
                        ? $"¥{item.Price:F2}  {rate:+0.00;-0.00}%"
                        : $"¥{item.Price:F2}",
                    Foreground = item.ChangeRatePercent switch
                    {
                        > 0 => RisingBrush,
                        < 0 => FallingBrush,
                        _ => ValueBrush,
                    },
                    FontSize = 12,
                    FontWeight = FontWeight.SemiBold,
                    HorizontalAlignment = HorizontalAlignment.Right,
                };
                row.Children.Add(name);
                row.Children.Add(value);
                MultiSourceList.Children.Add(row);
            }
        }
        catch
        {
            // 多源接口失败不影响主功能
        }
    }

    private void OnRangeClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is not Button button || button.Tag is not string range)
        {
            return;
        }

        _currentRange = range;
        foreach (var child in RangeSelector.Children.OfType<Button>())
        {
            child.Classes.Set("active", ReferenceEquals(child, button));
        }
        _ = RefreshChartAsync(range);
    }

    private void AddIndicator(string label, string value)
    {
        var cell = new DockPanel { Margin = new Avalonia.Thickness(0, 3) };
        cell.Children.Add(new TextBlock { Text = label, Foreground = NeutralBrush, FontSize = 12 });
        cell.Children.Add(new TextBlock
        {
            Text = value,
            Foreground = ValueBrush,
            FontSize = 12,
            FontWeight = FontWeight.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Avalonia.Thickness(0, 0, 10, 0),
        });
        IndicatorGrid.Children.Add(cell);
    }

    private static string BuildHint(TechnicalSnapshot snapshot)
    {
        var hints = new List<string>();
        if (snapshot.Rsi14 is { } rsi)
        {
            hints.Add(rsi >= 70 ? "RSI 超买区" : rsi <= 30 ? "RSI 超卖区" : "RSI 中性");
        }
        if (snapshot.MacdHistogram is { } histogram)
        {
            hints.Add(histogram >= 0 ? "MACD 多头动能" : "MACD 空头动能");
        }
        return hints.Count > 0 ? string.Join(" · ", hints) : "数据不足";
    }

    private static string Format2(double? value, string format = "F2")
    {
        return value?.ToString(format) ?? "--";
    }

    private static string FormatBytes(ulong bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double value = bytes;
        var index = 0;
        while (value >= 1024 && index < units.Length - 1)
        {
            value /= 1024;
            index++;
        }
        return $"{value:F1} {units[index]}";
    }

    private static string FormatUptime(TimeSpan uptime)
    {
        return uptime.Days > 0
            ? $"{uptime.Days} 天 {uptime.Hours} 小时"
            : $"{uptime.Hours} 小时 {uptime.Minutes} 分钟";
    }
}
