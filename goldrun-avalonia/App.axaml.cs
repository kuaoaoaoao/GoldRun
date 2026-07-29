using System;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Platform;
using GoldRun.Services;

namespace GoldRun;

public class App : Application
{
    private MainWindow? _mainWindow;
    private TrayIcon? _trayIcon;

    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            // 托盘常驻：关闭最后一个窗口不退出
            desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;
            _mainWindow = new MainWindow();

            var icons = TrayIcon.GetIcons(this);
            if (icons is { Count: > 0 })
            {
                _trayIcon = icons[0];
            }

            _ = UpdateTrayTooltipLoopAsync();
        }

        base.OnFrameworkInitializationCompleted();
    }

    private void OnTrayClicked(object? sender, EventArgs e) => ToggleMainWindow();

    private void OnToggleMenuClicked(object? sender, EventArgs e) => ToggleMainWindow();

    private void OnQuitMenuClicked(object? sender, EventArgs e)
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.Shutdown();
        }
    }

    private void ToggleMainWindow()
    {
        if (_mainWindow is null)
        {
            return;
        }

        if (_mainWindow.IsVisible)
        {
            _mainWindow.Hide();
            return;
        }

        PositionNearTray(_mainWindow);
        _mainWindow.Show();
        _mainWindow.Activate();
    }

    /// <summary>面板停靠到主屏工作区右下角（Windows 任务栏托盘附近）。</summary>
    private static void PositionNearTray(Window window)
    {
        var screen = window.Screens.Primary ?? (window.Screens.All.Count > 0 ? window.Screens.All[0] : null);
        if (screen is null)
        {
            return;
        }

        var area = screen.WorkingArea;
        var scale = screen.Scaling;
        var width = (int)(window.Width * scale);
        var height = (int)(window.Height * scale);
        var x = area.X + area.Width - width - (int)(12 * scale);
        var y = area.Y + area.Height - height - (int)(12 * scale);
        window.Position = new PixelPoint(Math.Max(area.X, x), Math.Max(area.Y, y));
    }

    /// <summary>后台每 2 分钟刷新金价，更新托盘悬停提示（对应 macOS 菜单栏价格）。</summary>
    private async Task UpdateTrayTooltipLoopAsync()
    {
        while (true)
        {
            try
            {
                var quote = await GoldService.Shared.FetchQuoteAsync();
                var change = quote.ChangeRatePercent is { } rate ? $" ({rate:+0.00;-0.00}%)" : "";
                if (_trayIcon is not null)
                {
                    _trayIcon.ToolTipText = $"GoldRun · 金价 ¥{quote.CnyPerGram:F2}/克{change}";
                }
            }
            catch
            {
                // 网络失败时保持上一次提示
            }

            await Task.Delay(TimeSpan.FromMinutes(2));
        }
    }
}
