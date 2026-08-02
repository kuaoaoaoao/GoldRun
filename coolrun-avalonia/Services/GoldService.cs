using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

namespace CoolRun.Services;

// 移植自 macOS 版 GoldPriceService.swift / GoldMarketDataService.swift。
// 数据源：京东金融（现价/分时/历史）+ gold.rsky.cn（多平台对比）。

public sealed record GoldQuote(
    double CnyPerGram,
    DateTimeOffset UpdatedAt,
    double? YesterdayPrice,
    double? ChangeAmount,
    double? ChangeRatePercent,
    bool IsMarketClosed,
    string Source);

public sealed record PricePoint(double Price, DateTimeOffset Timestamp);

public sealed record MultiSourcePrice(
    string Name,
    double Price,
    double? Change,
    double? ChangeRatePercent,
    DateTimeOffset? UpdatedAt);

public sealed class GoldService
{
    public static readonly GoldService Shared = new();

    private static readonly TimeZoneInfo Shanghai =
        TimeZoneInfo.FindSystemTimeZoneById("Asia/Shanghai");

    private readonly HttpClient _client = new() { Timeout = TimeSpan.FromSeconds(10) };
    private readonly object _cacheLock = new();

    // 缓存策略与 macOS 版一致：分时 2 分钟 / 历史 30 分钟 / 多源 5 分钟
    private (List<PricePoint> Points, DateTime At)? _todayCache;
    private readonly Dictionary<string, (List<PricePoint> Points, DateTime At)> _historyCache = new();
    private (List<MultiSourcePrice> Prices, DateTime At)? _multiSourceCache;

    // MARK: 现价（京东 latestPrice 主源，旧接口回退）

    public async Task<GoldQuote> FetchQuoteAsync()
    {
        try
        {
            return await FetchLatestQuoteAsync();
        }
        catch
        {
            return await FetchLegacyQuoteAsync();
        }
    }

    private async Task<GoldQuote> FetchLatestQuoteAsync()
    {
        using var doc = await PostJdAsync("/gw/generic/hj/h5/m/latestPrice", "{}");
        var root = doc.RootElement;

        if (!root.TryGetProperty("success", out var success) || !success.GetBoolean())
        {
            throw new InvalidOperationException(ApiMessage(root));
        }

        var datas = root.GetProperty("resultData").GetProperty("datas");
        var price = LenientDouble(datas, "price")
                    ?? throw new InvalidOperationException(ApiMessage(root));

        var updatedAt = LenientDouble(datas, "time") is { } millis
            ? DateTimeOffset.FromUnixTimeMilliseconds((long)millis)
            : DateTimeOffset.Now;

        return new GoldQuote(
            CnyPerGram: price,
            UpdatedAt: updatedAt,
            YesterdayPrice: LenientDouble(datas, "yesterdayPrice"),
            ChangeAmount: LenientDouble(datas, "upAndDownAmt"),
            ChangeRatePercent: LenientDouble(datas, "upAndDownRate"),
            IsMarketClosed: datas.TryGetProperty("demode", out var demode)
                            && demode.ValueKind == JsonValueKind.True,
            Source: "JD-MS");
    }

    private async Task<GoldQuote> FetchLegacyQuoteAsync()
    {
        const string url = "https://api.jdjygold.com/gw2/generic/produTools/h5/m/getGoldPrice?goldCode=CZB-JCJ";
        using var response = await _client.GetAsync(url);
        response.EnsureSuccessStatusCode();
        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var root = doc.RootElement;

        var resultData = root.GetProperty("resultData");
        if (!root.GetProperty("success").GetBoolean()
            || resultData.GetProperty("code").GetString() != "0000")
        {
            throw new InvalidOperationException(ApiMessage(root));
        }

        var data = resultData.GetProperty("data");
        var price = data.GetProperty("lastPrice").GetDouble();

        // tradeDateTime 为上海时区的年月日时分秒字段
        var t = data.GetProperty("tradeDateTime");
        var local = new DateTime(
            t.GetProperty("year").GetInt32(),
            t.GetProperty("monthValue").GetInt32(),
            t.GetProperty("dayOfMonth").GetInt32(),
            t.GetProperty("hour").GetInt32(),
            t.GetProperty("minute").GetInt32(),
            t.GetProperty("second").GetInt32(),
            DateTimeKind.Unspecified);
        var updatedAt = new DateTimeOffset(local, Shanghai.GetUtcOffset(local));

        return new GoldQuote(price, updatedAt, null, null, null, false, "CZB-JCJ");
    }

    // MARK: 今日分时（缓存 2 分钟）

    public async Task<List<PricePoint>> FetchTodayPricesAsync()
    {
        lock (_cacheLock)
        {
            if (_todayCache is { } cached && DateTime.UtcNow - cached.At < TimeSpan.FromMinutes(2))
            {
                return cached.Points;
            }
        }

        using var doc = await PostJdAsync("/gw/generic/hj/h5/m/todayPrices", "{}");
        var datas = doc.RootElement.GetProperty("resultData").GetProperty("datas");

        var points = new List<PricePoint>();
        foreach (var item in datas.EnumerateArray())
        {
            if (!item.TryGetProperty("value", out var value)
                || value.ValueKind != JsonValueKind.Array
                || value.GetArrayLength() < 2)
            {
                continue;
            }

            var timeText = value[0].GetString();
            var price = LenientDouble(value[1]);
            if (timeText is null || price is null || ParseShanghai(timeText) is not { } timestamp)
            {
                continue;
            }
            points.Add(new PricePoint(price.Value, timestamp));
        }

        if (points.Count == 0)
        {
            throw new InvalidOperationException("Empty todayPrices response");
        }

        lock (_cacheLock)
        {
            _todayCache = (points, DateTime.UtcNow);
        }
        return points;
    }

    // MARK: 历史走势（period: w/m/q/h/y，缓存 30 分钟）

    public async Task<List<PricePoint>> FetchHistoryPricesAsync(string period)
    {
        if (period is not ("w" or "m" or "q" or "h" or "y"))
        {
            throw new ArgumentException($"Unsupported period: {period}", nameof(period));
        }

        lock (_cacheLock)
        {
            if (_historyCache.TryGetValue(period, out var cached)
                && DateTime.UtcNow - cached.At < TimeSpan.FromMinutes(30))
            {
                return cached.Points;
            }
        }

        using var doc = await PostJdAsync(
            "/gw/generic/hj/h5/m/historyPrices",
            $"{{\"period\":\"{period}\"}}");
        var datas = doc.RootElement.GetProperty("resultData").GetProperty("datas");

        var points = new List<PricePoint>();
        foreach (var item in datas.EnumerateArray())
        {
            var price = LenientDouble(item, "price");
            var millis = LenientDouble(item, "time");
            if (price is null || millis is null)
            {
                continue;
            }
            points.Add(new PricePoint(
                price.Value,
                DateTimeOffset.FromUnixTimeMilliseconds((long)millis.Value)));
        }

        if (points.Count == 0)
        {
            throw new InvalidOperationException("Empty historyPrices response");
        }

        lock (_cacheLock)
        {
            _historyCache[period] = (points, DateTime.UtcNow);
        }
        return points;
    }

    // MARK: 多平台金价（gold.rsky.cn，缓存 5 分钟，8 秒超时）

    public async Task<List<MultiSourcePrice>> FetchMultiSourcePricesAsync()
    {
        lock (_cacheLock)
        {
            if (_multiSourceCache is { } cached && DateTime.UtcNow - cached.At < TimeSpan.FromMinutes(5))
            {
                return cached.Prices;
            }
        }

        using var cts = new System.Threading.CancellationTokenSource(TimeSpan.FromSeconds(8));
        using var response = await _client.GetAsync(
            "https://gold.rsky.cn/api/multi-source-prices", cts.Token);
        response.EnsureSuccessStatusCode();
        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cts.Token));
        var root = doc.RootElement;

        if (root.GetProperty("code").GetInt32() != 200)
        {
            throw new InvalidOperationException(
                root.TryGetProperty("message", out var msg) && msg.ValueKind == JsonValueKind.String
                    ? msg.GetString()!
                    : "Invalid multi-source response");
        }

        var prices = new List<MultiSourcePrice>();
        foreach (var item in root.GetProperty("data").GetProperty("prices").EnumerateArray())
        {
            if (item.TryGetProperty("success", out var ok) && ok.ValueKind == JsonValueKind.False)
            {
                continue;
            }

            var price = LenientDouble(item, "price");
            var name = item.TryGetProperty("name", out var n) ? n.GetString() : null;
            if (price is null or <= 0 || name is null)
            {
                continue;
            }

            DateTimeOffset? updatedAt = null;
            if (item.TryGetProperty("readable_time", out var rt)
                && rt.ValueKind == JsonValueKind.String
                && ParseShanghai(rt.GetString()!) is { } parsed)
            {
                updatedAt = parsed;
            }

            prices.Add(new MultiSourcePrice(
                name, price.Value,
                LenientDouble(item, "change"),
                LenientDouble(item, "change_rate"),
                updatedAt));
        }

        if (prices.Count == 0)
        {
            throw new InvalidOperationException("Empty multi-source response");
        }

        lock (_cacheLock)
        {
            _multiSourceCache = (prices, DateTime.UtcNow);
        }
        return prices;
    }

    // MARK: Helpers

    private async Task<JsonDocument> PostJdAsync(string path, string reqData)
    {
        var content = new FormUrlEncodedContent(new[]
        {
            new KeyValuePair<string, string>("reqData", reqData),
        });

        using var response = await _client.PostAsync($"https://ms.jr.jd.com{path}", content);
        response.EnsureSuccessStatusCode();
        return JsonDocument.Parse(await response.Content.ReadAsStringAsync());
    }

    /// <summary>兼容 Number 与 String（可含 % 号）的数值字段。</summary>
    private static double? LenientDouble(JsonElement parent, string property)
    {
        return parent.TryGetProperty(property, out var value) ? LenientDouble(value) : null;
    }

    private static double? LenientDouble(JsonElement value)
    {
        return value.ValueKind switch
        {
            JsonValueKind.Number => value.GetDouble(),
            JsonValueKind.String when double.TryParse(
                value.GetString()!.Trim().TrimEnd('%').Trim(),
                NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed) => parsed,
            _ => null,
        };
    }

    /// <summary>"yyyy-MM-dd HH:mm:ss"（Asia/Shanghai）→ DateTimeOffset。</summary>
    private static DateTimeOffset? ParseShanghai(string text)
    {
        if (!DateTime.TryParseExact(
                text, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var naive))
        {
            return null;
        }
        return new DateTimeOffset(naive, Shanghai.GetUtcOffset(naive));
    }

    private static string ApiMessage(JsonElement root)
    {
        return root.TryGetProperty("resultMsg", out var msg) && msg.ValueKind == JsonValueKind.String
            ? msg.GetString()!
            : "Invalid gold price response";
    }
}
