using System;
using System.Collections.Generic;
using System.Linq;

namespace GoldRun.Services;

// 技术指标计算，移植自 macOS 版 TechnicalIndicators.swift。

public sealed record TechnicalSnapshot(
    double? Sma5,
    double? Sma20,
    double? Sma60,
    double? Ema12,
    double? Ema26,
    double? Rsi14,
    double? MacdLine,
    double? MacdSignal,
    double? MacdHistogram,
    double? BollingerUpper,
    double? BollingerMiddle,
    double? BollingerLower,
    double? Volatility,
    double? Roc10,
    double? SupportLevel,
    double? ResistanceLevel);

public static class TechnicalIndicators
{
    public static List<double?> Sma(IReadOnlyList<double> prices, int period)
    {
        if (period <= 0 || prices.Count < period)
        {
            return Enumerable.Repeat<double?>(null, prices.Count).ToList();
        }

        var result = Enumerable.Repeat<double?>(null, period - 1).ToList();
        var sum = prices.Take(period).Sum();
        result.Add(sum / period);

        for (var index = period; index < prices.Count; index++)
        {
            sum += prices[index] - prices[index - period];
            result.Add(sum / period);
        }

        return result;
    }

    public static double? LastSma(IReadOnlyList<double> prices, int period)
    {
        if (period <= 0 || prices.Count < period)
        {
            return null;
        }
        return prices.Skip(prices.Count - period).Sum() / period;
    }

    public static List<double?> Ema(IReadOnlyList<double> prices, int period)
    {
        if (period <= 0 || prices.Count < period)
        {
            return Enumerable.Repeat<double?>(null, prices.Count).ToList();
        }

        var multiplier = 2.0 / (period + 1);
        var result = Enumerable.Repeat<double?>(null, period - 1).ToList();
        result.Add(prices.Take(period).Sum() / period);

        for (var index = period; index < prices.Count; index++)
        {
            if (result[^1] is { } previous)
            {
                result.Add((prices[index] - previous) * multiplier + previous);
            }
            else
            {
                result.Add(null);
            }
        }

        return result;
    }

    public static double? LastEma(IReadOnlyList<double> prices, int period)
    {
        var series = Ema(prices, period);
        return series.Count > 0 ? series[^1] : null;
    }

    public static List<double?> Rsi(IReadOnlyList<double> prices, int period = 14)
    {
        if (period <= 0 || prices.Count <= period)
        {
            return Enumerable.Repeat<double?>(null, prices.Count).ToList();
        }

        var gains = new List<double>();
        var losses = new List<double>();
        for (var index = 1; index < prices.Count; index++)
        {
            var change = prices[index] - prices[index - 1];
            gains.Add(Math.Max(change, 0));
            losses.Add(Math.Max(-change, 0));
        }

        var result = Enumerable.Repeat<double?>(null, period).ToList();
        var averageGain = gains.Take(period).Sum() / period;
        var averageLoss = losses.Take(period).Sum() / period;
        result.Add(RsiValue(averageGain, averageLoss));

        for (var index = period; index < gains.Count; index++)
        {
            averageGain = (averageGain * (period - 1) + gains[index]) / period;
            averageLoss = (averageLoss * (period - 1) + losses[index]) / period;
            result.Add(RsiValue(averageGain, averageLoss));
        }

        return result.Take(prices.Count).ToList();
    }

    public static double? LastRsi(IReadOnlyList<double> prices, int period = 14)
    {
        var series = Rsi(prices, period);
        return series.Count > 0 ? series[^1] : null;
    }

    public static (List<double?> MacdLine, List<double?> SignalLine, List<double?> Histogram) Macd(
        IReadOnlyList<double> prices, int fastPeriod = 12, int slowPeriod = 26, int signalPeriod = 9)
    {
        var fastEma = Ema(prices, fastPeriod);
        var slowEma = Ema(prices, slowPeriod);

        var macdValues = new List<double>();
        var macdIndices = new List<int>();
        for (var index = 0; index < prices.Count; index++)
        {
            if (fastEma[index] is { } fast && slowEma[index] is { } slow)
            {
                macdValues.Add(fast - slow);
                macdIndices.Add(index);
            }
        }

        var signalEma = Ema(macdValues, signalPeriod);
        var macdLine = Enumerable.Repeat<double?>(null, prices.Count).ToList();
        var signalLine = Enumerable.Repeat<double?>(null, prices.Count).ToList();
        var histogram = Enumerable.Repeat<double?>(null, prices.Count).ToList();

        for (var index = 0; index < macdValues.Count; index++)
        {
            var alignedIndex = macdIndices[index];
            macdLine[alignedIndex] = macdValues[index];
            if (index < signalEma.Count && signalEma[index] is { } signal)
            {
                signalLine[alignedIndex] = signal;
                histogram[alignedIndex] = macdValues[index] - signal;
            }
        }

        return (macdLine, signalLine, histogram);
    }

    public static (List<double?> Upper, List<double?> Middle, List<double?> Lower) BollingerBands(
        IReadOnlyList<double> prices, int period = 20, double multiplier = 2.0)
    {
        var middle = Sma(prices, period);
        var upper = new List<double?>();
        var lower = new List<double?>();

        for (var index = 0; index < prices.Count; index++)
        {
            if (middle[index] is { } mean && index >= period - 1)
            {
                var variance = 0.0;
                for (var i = index - period + 1; i <= index; i++)
                {
                    variance += Math.Pow(prices[i] - mean, 2);
                }
                var deviation = Math.Sqrt(variance / period);
                upper.Add(mean + multiplier * deviation);
                lower.Add(mean - multiplier * deviation);
            }
            else
            {
                upper.Add(null);
                lower.Add(null);
            }
        }

        return (upper, middle, lower);
    }

    public static double? AnnualizedVolatility(IReadOnlyList<double> prices, int period = 20)
    {
        if (prices.Count < 2)
        {
            return null;
        }

        var returns = LogReturns(prices);
        var slice = returns.Skip(Math.Max(0, returns.Count - period)).ToList();
        if (slice.Count < 2)
        {
            return null;
        }

        var mean = slice.Average();
        var variance = slice.Sum(r => Math.Pow(r - mean, 2)) / (slice.Count - 1);
        return Math.Sqrt(variance) * Math.Sqrt(252);
    }

    public static List<double?> Roc(IReadOnlyList<double> prices, int period = 10)
    {
        if (prices.Count <= period)
        {
            return Enumerable.Repeat<double?>(null, prices.Count).ToList();
        }

        var result = Enumerable.Repeat<double?>(null, period).ToList();
        for (var index = period; index < prices.Count; index++)
        {
            var previous = prices[index - period];
            result.Add(previous == 0 ? null : (prices[index] - previous) / previous * 100);
        }
        return result;
    }

    public static (double? Support, double? Resistance) FindSupportResistance(
        IReadOnlyList<double> prices, int window, double currentPrice)
    {
        if (prices.Count <= window * 2 + 1)
        {
            return (null, null);
        }

        var supports = new List<double>();
        var resistances = new List<double>();

        for (var index = window; index < prices.Count - window; index++)
        {
            var value = prices[index];
            var isLocalMin = true;
            var isLocalMax = true;
            for (var i = index - window; i <= index + window; i++)
            {
                if (i == index)
                {
                    continue;
                }
                if (prices[i] < value)
                {
                    isLocalMin = false;
                }
                if (prices[i] > value)
                {
                    isLocalMax = false;
                }
            }

            if (isLocalMin && value < currentPrice)
            {
                supports.Add(value);
            }
            if (isLocalMax && value > currentPrice)
            {
                resistances.Add(value);
            }
        }

        return (
            supports.Count > 0 ? supports.Max() : null,
            resistances.Count > 0 ? resistances.Min() : null);
    }

    public static TechnicalSnapshot BuildSnapshot(IReadOnlyList<double> prices, double currentPrice)
    {
        if (prices.Count == 0)
        {
            return new TechnicalSnapshot(
                null, null, null, null, null, null, null, null,
                null, null, null, null, null, null, null, null);
        }

        var (macdLine, signalLine, histogram) = Macd(prices);
        var (upper, middle, lower) = BollingerBands(prices);
        var lastIndex = prices.Count - 1;
        var (support, resistance) = FindSupportResistance(prices, 5, currentPrice);
        var roc = Roc(prices);

        return new TechnicalSnapshot(
            Sma5: LastSma(prices, 5),
            Sma20: LastSma(prices, 20),
            Sma60: LastSma(prices, 60),
            Ema12: LastEma(prices, 12),
            Ema26: LastEma(prices, 26),
            Rsi14: LastRsi(prices),
            MacdLine: macdLine[lastIndex],
            MacdSignal: signalLine[lastIndex],
            MacdHistogram: histogram[lastIndex],
            BollingerUpper: upper[lastIndex],
            BollingerMiddle: middle[lastIndex],
            BollingerLower: lower[lastIndex],
            Volatility: AnnualizedVolatility(prices),
            Roc10: roc.Count > 0 ? roc[^1] : null,
            SupportLevel: support,
            ResistanceLevel: resistance);
    }

    private static double RsiValue(double averageGain, double averageLoss)
    {
        if (averageLoss == 0)
        {
            return averageGain == 0 ? 50 : 100;
        }
        var relativeStrength = averageGain / averageLoss;
        return 100 - 100 / (1 + relativeStrength);
    }

    private static List<double> LogReturns(IReadOnlyList<double> prices)
    {
        var returns = new List<double>();
        for (var index = 1; index < prices.Count; index++)
        {
            if (prices[index - 1] > 0 && prices[index] > 0)
            {
                returns.Add(Math.Log(prices[index] / prices[index - 1]));
            }
        }
        return returns;
    }
}
