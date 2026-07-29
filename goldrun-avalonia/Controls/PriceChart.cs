using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using GoldRun.Services;

namespace GoldRun.Controls;

/// <summary>金价走势图：折线 + 渐变填充 + 最高/最低价标注（自绘，无第三方图表库）。</summary>
public sealed class PriceChart : Control
{
    public static readonly StyledProperty<IReadOnlyList<PricePoint>?> PointsProperty =
        AvaloniaProperty.Register<PriceChart, IReadOnlyList<PricePoint>?>(nameof(Points));

    private static readonly Color RisingColor = Color.FromRgb(0xF0, 0x52, 0x4F);
    private static readonly Color FallingColor = Color.FromRgb(0x34, 0xC7, 0x7B);
    private static readonly IBrush LabelBrush = new SolidColorBrush(Color.FromRgb(0x8B, 0x90, 0xA0));

    static PriceChart()
    {
        AffectsRender<PriceChart>(PointsProperty);
    }

    public IReadOnlyList<PricePoint>? Points
    {
        get => GetValue(PointsProperty);
        set => SetValue(PointsProperty, value);
    }

    public override void Render(DrawingContext context)
    {
        base.Render(context);

        var points = Points;
        if (points is null || points.Count < 2)
        {
            return;
        }

        var width = Bounds.Width;
        var height = Bounds.Height;
        const double rightPadding = 44;
        const double topPadding = 8;
        const double bottomPadding = 4;
        var plotWidth = width - rightPadding;
        var plotHeight = height - topPadding - bottomPadding;
        if (plotWidth <= 0 || plotHeight <= 0)
        {
            return;
        }

        var prices = points.Select(p => p.Price).ToList();
        var min = prices.Min();
        var max = prices.Max();
        var span = Math.Max(max - min, 1e-9);

        double XAt(int index) => index / (double)(points.Count - 1) * plotWidth;
        double YAt(double price) => topPadding + (1 - (price - min) / span) * plotHeight;

        var rising = prices[^1] >= prices[0];
        var lineColor = rising ? RisingColor : FallingColor;

        // 折线
        var line = new StreamGeometry();
        using (var ctx = line.Open())
        {
            ctx.BeginFigure(new Point(XAt(0), YAt(prices[0])), false);
            for (var index = 1; index < points.Count; index++)
            {
                ctx.LineTo(new Point(XAt(index), YAt(prices[index])));
            }
            ctx.EndFigure(false);
        }
        context.DrawGeometry(null, new Pen(new SolidColorBrush(lineColor), 1.6), line);

        // 渐变填充
        var fill = new StreamGeometry();
        using (var ctx = fill.Open())
        {
            ctx.BeginFigure(new Point(XAt(0), height), true);
            for (var index = 0; index < points.Count; index++)
            {
                ctx.LineTo(new Point(XAt(index), YAt(prices[index])));
            }
            ctx.LineTo(new Point(XAt(points.Count - 1), height));
            ctx.EndFigure(true);
        }
        var gradient = new LinearGradientBrush
        {
            StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
            EndPoint = new RelativePoint(0, 1, RelativeUnit.Relative),
            GradientStops =
            {
                new GradientStop(Color.FromArgb(0x40, lineColor.R, lineColor.G, lineColor.B), 0),
                new GradientStop(Colors.Transparent, 1),
            },
        };
        context.DrawGeometry(gradient, null, fill);

        // 最高 / 最低价标注
        DrawLabel(context, max.ToString("F2", CultureInfo.InvariantCulture), plotWidth + 4, YAt(max));
        DrawLabel(context, min.ToString("F2", CultureInfo.InvariantCulture), plotWidth + 4, YAt(min));
    }

    private static void DrawLabel(DrawingContext context, string text, double x, double y)
    {
        var formatted = new FormattedText(
            text, CultureInfo.InvariantCulture, FlowDirection.LeftToRight,
            new Typeface("Segoe UI, PingFang SC, sans-serif"), 10, LabelBrush);
        context.DrawText(formatted, new Point(x, y - formatted.Height / 2));
    }
}
