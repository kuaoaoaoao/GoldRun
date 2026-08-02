//! 技术指标计算，移植自 macOS 版 TechnicalIndicators.swift。

use serde::Serialize;

#[derive(Serialize, Clone, Default)]
#[serde(rename_all = "camelCase")]
pub struct TechnicalSnapshot {
    pub sma5: Option<f64>,
    pub sma20: Option<f64>,
    pub sma60: Option<f64>,
    pub ema12: Option<f64>,
    pub ema26: Option<f64>,
    pub rsi14: Option<f64>,
    pub macd_line: Option<f64>,
    pub macd_signal: Option<f64>,
    pub macd_histogram: Option<f64>,
    pub bollinger_upper: Option<f64>,
    pub bollinger_middle: Option<f64>,
    pub bollinger_lower: Option<f64>,
    pub volatility: Option<f64>,
    pub roc10: Option<f64>,
    pub support_level: Option<f64>,
    pub resistance_level: Option<f64>,
}

pub fn sma(prices: &[f64], period: usize) -> Vec<Option<f64>> {
    if period == 0 || prices.len() < period {
        return vec![None; prices.len()];
    }

    let mut result: Vec<Option<f64>> = vec![None; period - 1];
    let mut sum: f64 = prices[..period].iter().sum();
    result.push(Some(sum / period as f64));

    for index in period..prices.len() {
        sum += prices[index] - prices[index - period];
        result.push(Some(sum / period as f64));
    }

    result
}

pub fn last_sma(prices: &[f64], period: usize) -> Option<f64> {
    if prices.len() < period || period == 0 {
        return None;
    }
    Some(prices[prices.len() - period..].iter().sum::<f64>() / period as f64)
}

pub fn ema(prices: &[f64], period: usize) -> Vec<Option<f64>> {
    if period == 0 || prices.len() < period {
        return vec![None; prices.len()];
    }

    let multiplier = 2.0 / (period as f64 + 1.0);
    let mut result: Vec<Option<f64>> = vec![None; period - 1];
    let seed = prices[..period].iter().sum::<f64>() / period as f64;
    result.push(Some(seed));

    for index in period..prices.len() {
        match result.last().copied().flatten() {
            Some(previous) => {
                result.push(Some((prices[index] - previous) * multiplier + previous));
            }
            None => result.push(None),
        }
    }

    result
}

pub fn last_ema(prices: &[f64], period: usize) -> Option<f64> {
    ema(prices, period).last().copied().flatten()
}

pub fn rsi(prices: &[f64], period: usize) -> Vec<Option<f64>> {
    if period == 0 || prices.len() <= period {
        return vec![None; prices.len()];
    }

    let mut gains: Vec<f64> = Vec::new();
    let mut losses: Vec<f64> = Vec::new();

    for index in 1..prices.len() {
        let change = prices[index] - prices[index - 1];
        gains.push(change.max(0.0));
        losses.push((-change).max(0.0));
    }

    let mut result: Vec<Option<f64>> = vec![None; period];
    let mut average_gain = gains[..period].iter().sum::<f64>() / period as f64;
    let mut average_loss = losses[..period].iter().sum::<f64>() / period as f64;

    result.push(Some(rsi_value(average_gain, average_loss)));

    for index in period..gains.len() {
        average_gain = (average_gain * (period as f64 - 1.0) + gains[index]) / period as f64;
        average_loss = (average_loss * (period as f64 - 1.0) + losses[index]) / period as f64;
        result.push(Some(rsi_value(average_gain, average_loss)));
    }

    result.truncate(prices.len());
    result
}

pub fn last_rsi(prices: &[f64], period: usize) -> Option<f64> {
    rsi(prices, period).last().copied().flatten()
}

pub struct MacdResult {
    pub macd_line: Vec<Option<f64>>,
    pub signal_line: Vec<Option<f64>>,
    pub histogram: Vec<Option<f64>>,
}

pub fn macd(prices: &[f64], fast_period: usize, slow_period: usize, signal_period: usize) -> MacdResult {
    let fast_ema = ema(prices, fast_period);
    let slow_ema = ema(prices, slow_period);

    let mut macd_values: Vec<f64> = Vec::new();
    let mut macd_indices: Vec<usize> = Vec::new();

    for index in 0..prices.len() {
        if let (Some(fast), Some(slow)) = (fast_ema[index], slow_ema[index]) {
            macd_values.push(fast - slow);
            macd_indices.push(index);
        }
    }

    let signal_ema = ema(&macd_values, signal_period);
    let mut macd_line: Vec<Option<f64>> = vec![None; prices.len()];
    let mut signal_line: Vec<Option<f64>> = vec![None; prices.len()];
    let mut histogram: Vec<Option<f64>> = vec![None; prices.len()];

    for index in 0..macd_values.len() {
        let aligned_index = macd_indices[index];
        macd_line[aligned_index] = Some(macd_values[index]);
        if index < signal_ema.len() {
            if let Some(signal) = signal_ema[index] {
                signal_line[aligned_index] = Some(signal);
                histogram[aligned_index] = Some(macd_values[index] - signal);
            }
        }
    }

    MacdResult { macd_line, signal_line, histogram }
}

pub struct BollingerBands {
    pub upper: Vec<Option<f64>>,
    pub middle: Vec<Option<f64>>,
    pub lower: Vec<Option<f64>>,
}

pub fn bollinger_bands(prices: &[f64], period: usize, multiplier: f64) -> BollingerBands {
    let middle = sma(prices, period);
    let mut upper: Vec<Option<f64>> = Vec::new();
    let mut lower: Vec<Option<f64>> = Vec::new();

    for index in 0..prices.len() {
        match middle[index] {
            Some(mean) if index + 1 >= period => {
                let slice = &prices[index + 1 - period..=index];
                let variance = slice.iter().map(|p| (p - mean).powi(2)).sum::<f64>() / period as f64;
                let deviation = variance.sqrt();
                upper.push(Some(mean + multiplier * deviation));
                lower.push(Some(mean - multiplier * deviation));
            }
            _ => {
                upper.push(None);
                lower.push(None);
            }
        }
    }

    BollingerBands { upper, middle, lower }
}

pub fn annualized_volatility(prices: &[f64], period: usize) -> Option<f64> {
    if prices.len() < 2 {
        return None;
    }
    let returns = log_returns(prices);
    let start = returns.len().saturating_sub(period);
    let slice = &returns[start..];
    if slice.len() < 2 {
        return None;
    }

    let mean = slice.iter().sum::<f64>() / slice.len() as f64;
    let variance = slice.iter().map(|r| (r - mean).powi(2)).sum::<f64>() / (slice.len() as f64 - 1.0);
    Some(variance.sqrt() * (252.0_f64).sqrt())
}

pub fn roc(prices: &[f64], period: usize) -> Vec<Option<f64>> {
    if prices.len() <= period {
        return vec![None; prices.len()];
    }

    let mut result: Vec<Option<f64>> = vec![None; period];
    for index in period..prices.len() {
        let previous = prices[index - period];
        if previous == 0.0 {
            result.push(None);
        } else {
            result.push(Some((prices[index] - previous) / previous * 100.0));
        }
    }
    result
}

pub fn find_support_resistance(prices: &[f64], window: usize, current_price: f64) -> (Option<f64>, Option<f64>) {
    if prices.len() <= window * 2 + 1 {
        return (None, None);
    }

    let mut supports: Vec<f64> = Vec::new();
    let mut resistances: Vec<f64> = Vec::new();

    for index in window..prices.len() - window {
        let value = prices[index];
        let left = &prices[index - window..index];
        let right = &prices[index + 1..=index + window];

        if left.iter().all(|p| *p >= value) && right.iter().all(|p| *p >= value) && value < current_price {
            supports.push(value);
        }
        if left.iter().all(|p| *p <= value) && right.iter().all(|p| *p <= value) && value > current_price {
            resistances.push(value);
        }
    }

    let support = supports.iter().copied().fold(None, |acc: Option<f64>, v| Some(acc.map_or(v, |a| a.max(v))));
    let resistance = resistances.iter().copied().fold(None, |acc: Option<f64>, v| Some(acc.map_or(v, |a| a.min(v))));
    (support, resistance)
}

pub fn build_snapshot(prices: &[f64], current_price: f64) -> TechnicalSnapshot {
    if prices.is_empty() {
        return TechnicalSnapshot::default();
    }

    let macd_result = macd(prices, 12, 26, 9);
    let bollinger = bollinger_bands(prices, 20, 2.0);
    let last_index = prices.len() - 1;
    let (support, resistance) = find_support_resistance(prices, 5, current_price);

    TechnicalSnapshot {
        sma5: last_sma(prices, 5),
        sma20: last_sma(prices, 20),
        sma60: last_sma(prices, 60),
        ema12: last_ema(prices, 12),
        ema26: last_ema(prices, 26),
        rsi14: last_rsi(prices, 14),
        macd_line: macd_result.macd_line[last_index],
        macd_signal: macd_result.signal_line[last_index],
        macd_histogram: macd_result.histogram[last_index],
        bollinger_upper: bollinger.upper[last_index],
        bollinger_middle: bollinger.middle[last_index],
        bollinger_lower: bollinger.lower[last_index],
        volatility: annualized_volatility(prices, 20),
        roc10: roc(prices, 10).last().copied().flatten(),
        support_level: support,
        resistance_level: resistance,
    }
}

fn rsi_value(average_gain: f64, average_loss: f64) -> f64 {
    if average_loss == 0.0 {
        return if average_gain == 0.0 { 50.0 } else { 100.0 };
    }
    let relative_strength = average_gain / average_loss;
    100.0 - 100.0 / (1.0 + relative_strength)
}

fn log_returns(prices: &[f64]) -> Vec<f64> {
    let mut returns: Vec<f64> = Vec::new();
    for index in 1..prices.len() {
        if prices[index - 1] > 0.0 && prices[index] > 0.0 {
            returns.push((prices[index] / prices[index - 1]).ln());
        }
    }
    returns
}
