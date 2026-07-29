//! 金价数据服务，移植自 macOS 版 GoldPriceService.swift / GoldMarketDataService.swift。
//! 数据源：京东金融（现价/分时/历史）+ gold.rsky.cn（多平台对比）。

use std::collections::HashMap;
use std::time::{Duration, Instant};

use chrono::{NaiveDateTime, TimeZone};
use chrono_tz::Asia::Shanghai;
use serde::Serialize;
use serde_json::Value;
use tokio::sync::Mutex;

// MARK: - DTO

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct GoldQuote {
    pub cny_per_gram: f64,
    pub updated_at_ms: i64,
    pub yesterday_price: Option<f64>,
    pub change_amount: Option<f64>,
    pub change_rate_percent: Option<f64>,
    pub is_market_closed: bool,
    pub source: String,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct PricePoint {
    pub price: f64,
    pub timestamp_ms: i64,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MultiSourcePrice {
    pub name: String,
    pub price: f64,
    pub change: Option<f64>,
    pub change_rate_percent: Option<f64>,
    pub updated_at_ms: Option<i64>,
}

// MARK: - State（带缓存：分时 2 分钟 / 历史 30 分钟 / 多源 5 分钟）

struct Cache {
    today: Option<(Vec<PricePoint>, Instant)>,
    history: HashMap<String, (Vec<PricePoint>, Instant)>,
    multi_source: Option<(Vec<MultiSourcePrice>, Instant)>,
}

pub struct GoldState {
    client: reqwest::Client,
    cache: Mutex<Cache>,
}

impl GoldState {
    pub fn new() -> Self {
        Self {
            client: reqwest::Client::builder()
                .timeout(Duration::from_secs(10))
                .build()
                .expect("failed to build http client"),
            cache: Mutex::new(Cache {
                today: None,
                history: HashMap::new(),
                multi_source: None,
            }),
        }
    }
}

// MARK: - 现价（京东 latestPrice 主源，旧接口回退）

pub async fn fetch_quote(state: &GoldState) -> Result<GoldQuote, String> {
    match fetch_latest_quote(state).await {
        Ok(quote) => Ok(quote),
        Err(_) => fetch_legacy_quote(state).await,
    }
}

async fn fetch_latest_quote(state: &GoldState) -> Result<GoldQuote, String> {
    let payload = post_jd(state, "/gw/generic/hj/h5/m/latestPrice", "{}").await?;

    if !payload["success"].as_bool().unwrap_or(false) {
        return Err(api_message(&payload));
    }

    let datas = &payload["resultData"]["datas"];
    let price = lenient_f64(&datas["price"]).ok_or_else(|| api_message(&payload))?;

    let updated_at_ms = lenient_f64(&datas["time"])
        .map(|millis| millis as i64)
        .unwrap_or_else(now_ms);

    Ok(GoldQuote {
        cny_per_gram: price,
        updated_at_ms,
        yesterday_price: lenient_f64(&datas["yesterdayPrice"]),
        change_amount: lenient_f64(&datas["upAndDownAmt"]),
        change_rate_percent: lenient_f64(&datas["upAndDownRate"]),
        is_market_closed: datas["demode"].as_bool().unwrap_or(false),
        source: "JD-MS".into(),
    })
}

async fn fetch_legacy_quote(state: &GoldState) -> Result<GoldQuote, String> {
    let url = "https://api.jdjygold.com/gw2/generic/produTools/h5/m/getGoldPrice?goldCode=CZB-JCJ";
    let payload: Value = state
        .client
        .get(url)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())?;

    let result_data = &payload["resultData"];
    if !payload["success"].as_bool().unwrap_or(false)
        || result_data["code"].as_str() != Some("0000")
    {
        return Err(api_message(&payload));
    }

    let data = &result_data["data"];
    let price = lenient_f64(&data["lastPrice"]).ok_or("Invalid gold price response")?;

    // tradeDateTime 为上海时区的年月日时分秒字段
    let t = &data["tradeDateTime"];
    let updated_at_ms = Shanghai
        .with_ymd_and_hms(
            t["year"].as_i64().unwrap_or(1970) as i32,
            t["monthValue"].as_i64().unwrap_or(1) as u32,
            t["dayOfMonth"].as_i64().unwrap_or(1) as u32,
            t["hour"].as_i64().unwrap_or(0) as u32,
            t["minute"].as_i64().unwrap_or(0) as u32,
            t["second"].as_i64().unwrap_or(0) as u32,
        )
        .single()
        .map(|d| d.timestamp_millis())
        .unwrap_or_else(now_ms);

    Ok(GoldQuote {
        cny_per_gram: price,
        updated_at_ms,
        yesterday_price: None,
        change_amount: None,
        change_rate_percent: None,
        is_market_closed: false,
        source: "CZB-JCJ".into(),
    })
}

// MARK: - 今日分时（缓存 2 分钟）

pub async fn fetch_today_prices(state: &GoldState) -> Result<Vec<PricePoint>, String> {
    {
        let cache = state.cache.lock().await;
        if let Some((points, at)) = &cache.today {
            if at.elapsed() < Duration::from_secs(120) {
                return Ok(points.clone());
            }
        }
    }

    let payload = post_jd(state, "/gw/generic/hj/h5/m/todayPrices", "{}").await?;
    let datas = payload["resultData"]["datas"]
        .as_array()
        .ok_or("Invalid todayPrices response")?;

    let mut points: Vec<PricePoint> = Vec::new();
    for item in datas {
        let Some(value) = item["value"].as_array() else { continue };
        if value.len() < 2 {
            continue;
        }
        let Some(time_str) = value[0].as_str() else { continue };
        let Some(price) = lenient_f64(&value[1]) else { continue };
        let Some(timestamp_ms) = parse_shanghai(time_str) else { continue };
        points.push(PricePoint { price, timestamp_ms });
    }

    if points.is_empty() {
        return Err("Empty todayPrices response".into());
    }

    let mut cache = state.cache.lock().await;
    cache.today = Some((points.clone(), Instant::now()));
    Ok(points)
}

// MARK: - 历史走势（period: w/m/q/h/y，缓存 30 分钟）

pub async fn fetch_history_prices(state: &GoldState, period: &str) -> Result<Vec<PricePoint>, String> {
    if !matches!(period, "w" | "m" | "q" | "h" | "y") {
        return Err(format!("Unsupported period: {period}"));
    }

    {
        let cache = state.cache.lock().await;
        if let Some((points, at)) = cache.history.get(period) {
            if at.elapsed() < Duration::from_secs(30 * 60) {
                return Ok(points.clone());
            }
        }
    }

    let req_data = format!(r#"{{"period":"{period}"}}"#);
    let payload = post_jd(state, "/gw/generic/hj/h5/m/historyPrices", &req_data).await?;
    let datas = payload["resultData"]["datas"]
        .as_array()
        .ok_or("Invalid historyPrices response")?;

    let mut points: Vec<PricePoint> = Vec::new();
    for item in datas {
        let Some(price) = lenient_f64(&item["price"]) else { continue };
        let Some(millis) = lenient_f64(&item["time"]) else { continue };
        points.push(PricePoint { price, timestamp_ms: millis as i64 });
    }

    if points.is_empty() {
        return Err("Empty historyPrices response".into());
    }

    let mut cache = state.cache.lock().await;
    cache.history.insert(period.to_string(), (points.clone(), Instant::now()));
    Ok(points)
}

// MARK: - 多平台金价（gold.rsky.cn，缓存 5 分钟，8 秒超时）

pub async fn fetch_multi_source_prices(state: &GoldState) -> Result<Vec<MultiSourcePrice>, String> {
    {
        let cache = state.cache.lock().await;
        if let Some((prices, at)) = &cache.multi_source {
            if at.elapsed() < Duration::from_secs(5 * 60) {
                return Ok(prices.clone());
            }
        }
    }

    let payload: Value = state
        .client
        .get("https://gold.rsky.cn/api/multi-source-prices")
        .timeout(Duration::from_secs(8))
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())?;

    if payload["code"].as_i64() != Some(200) {
        return Err(payload["message"]
            .as_str()
            .unwrap_or("Invalid multi-source response")
            .to_string());
    }

    let items = payload["data"]["prices"]
        .as_array()
        .ok_or("Invalid multi-source response")?;

    let mut prices: Vec<MultiSourcePrice> = Vec::new();
    for item in items {
        if !item["success"].as_bool().unwrap_or(true) {
            continue;
        }
        let Some(price) = lenient_f64(&item["price"]) else { continue };
        if price <= 0.0 {
            continue;
        }
        let Some(name) = item["name"].as_str() else { continue };
        prices.push(MultiSourcePrice {
            name: name.to_string(),
            price,
            change: lenient_f64(&item["change"]),
            change_rate_percent: lenient_f64(&item["change_rate"]),
            updated_at_ms: item["readable_time"].as_str().and_then(parse_shanghai),
        });
    }

    if prices.is_empty() {
        return Err("Empty multi-source response".into());
    }

    let mut cache = state.cache.lock().await;
    cache.multi_source = Some((prices.clone(), Instant::now()));
    Ok(prices)
}

// MARK: - Helpers

async fn post_jd(state: &GoldState, path: &str, req_data: &str) -> Result<Value, String> {
    let url = format!("https://ms.jr.jd.com{path}");
    let body = format!("reqData={}", percent_encode(req_data));

    state
        .client
        .post(&url)
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())
}

/// 与 macOS 版一致：仅字母数字保留，其余按 UTF-8 字节百分号编码
fn percent_encode(input: &str) -> String {
    let mut out = String::with_capacity(input.len() * 3);
    for byte in input.bytes() {
        if byte.is_ascii_alphanumeric() {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }
    out
}

/// 兼容 Number 与 String（可含 % 号）的数值字段
fn lenient_f64(value: &Value) -> Option<f64> {
    match value {
        Value::Number(number) => number.as_f64(),
        Value::String(text) => text.trim().trim_end_matches('%').trim().parse::<f64>().ok(),
        _ => None,
    }
}

/// "yyyy-MM-dd HH:mm:ss"（Asia/Shanghai）→ epoch 毫秒
fn parse_shanghai(text: &str) -> Option<i64> {
    let naive = NaiveDateTime::parse_from_str(text, "%Y-%m-%d %H:%M:%S").ok()?;
    Shanghai
        .from_local_datetime(&naive)
        .single()
        .map(|d| d.timestamp_millis())
}

fn api_message(payload: &Value) -> String {
    payload["resultMsg"]
        .as_str()
        .unwrap_or("Invalid gold price response")
        .to_string()
}

fn now_ms() -> i64 {
    chrono::Utc::now().timestamp_millis()
}
