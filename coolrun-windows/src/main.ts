import { invoke } from "@tauri-apps/api/core";

// ===== 类型（与 Rust DTO 对应） =====

interface SystemSnapshot {
  cpuUsage: number;
  coreCount: number;
  memoryUsed: number;
  memoryTotal: number;
  storageUsed: number;
  storageTotal: number;
  downloadSpeed: number;
  uploadSpeed: number;
  uptimeSeconds: number;
  cpuTemperature: number | null;
  sensors: { name: string; temperature: number }[];
}

interface GoldQuote {
  cnyPerGram: number;
  updatedAtMs: number;
  yesterdayPrice: number | null;
  changeAmount: number | null;
  changeRatePercent: number | null;
  isMarketClosed: boolean;
  source: string;
}

interface PricePoint {
  price: number;
  timestampMs: number;
}

interface MultiSourcePrice {
  name: string;
  price: number;
  change: number | null;
  changeRatePercent: number | null;
  updatedAtMs: number | null;
}

interface TechnicalSnapshot {
  sma5: number | null;
  sma20: number | null;
  sma60: number | null;
  ema12: number | null;
  ema26: number | null;
  rsi14: number | null;
  macdLine: number | null;
  macdSignal: number | null;
  macdHistogram: number | null;
  bollingerUpper: number | null;
  bollingerMiddle: number | null;
  bollingerLower: number | null;
  volatility: number | null;
  roc10: number | null;
  supportLevel: number | null;
  resistanceLevel: number | null;
}

// ===== DOM 帮助函数 =====

const $ = <T extends HTMLElement = HTMLElement>(id: string): T =>
  document.getElementById(id) as T;

function formatBytes(bytes: number): string {
  if (bytes >= 1024 ** 4) return `${(bytes / 1024 ** 4).toFixed(2)} TB`;
  if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
  if (bytes >= 1024 ** 2) return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  return `${(bytes / 1024).toFixed(0)} KB`;
}

function formatSpeed(bytesPerSec: number): string {
  if (bytesPerSec >= 1024 ** 2) return `${(bytesPerSec / 1024 ** 2).toFixed(1)} MB/s`;
  return `${(bytesPerSec / 1024).toFixed(0)} KB/s`;
}

function formatUptime(seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (days > 0) return `${days}天${hours}时`;
  if (hours > 0) return `${hours}时${minutes}分`;
  return `${minutes}分`;
}

function formatTime(ms: number): string {
  return new Date(ms).toLocaleString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function setBar(el: HTMLElement, ratio: number) {
  const percent = Math.min(Math.max(ratio, 0), 1) * 100;
  el.style.width = `${percent}%`;
  el.classList.toggle("danger", percent >= 90);
  el.classList.toggle("warn", percent >= 70 && percent < 90);
}

// ===== Tab 切换 =====

document.querySelectorAll<HTMLButtonElement>(".tab").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
    button.classList.add("active");
    const tab = button.dataset.tab!;
    $("tab-system").hidden = tab !== "system";
    $("tab-gold").hidden = tab !== "gold";
    if (tab === "gold") void refreshGold();
  });
});

// ===== 系统监控 =====

async function refreshSystem() {
  try {
    const s = await invoke<SystemSnapshot>("system_snapshot");

    $("cpu-usage").textContent = `${(s.cpuUsage * 100).toFixed(0)}%`;
    setBar($("cpu-bar"), s.cpuUsage);
    $("cpu-detail").textContent = `${s.coreCount} 核心`;

    const memRatio = s.memoryTotal > 0 ? s.memoryUsed / s.memoryTotal : 0;
    $("mem-usage").textContent = `${(memRatio * 100).toFixed(0)}%`;
    setBar($("mem-bar"), memRatio);
    $("mem-detail").textContent = `${formatBytes(s.memoryUsed)} / ${formatBytes(s.memoryTotal)}`;

    const diskRatio = s.storageTotal > 0 ? s.storageUsed / s.storageTotal : 0;
    $("disk-usage").textContent = `${(diskRatio * 100).toFixed(0)}%`;
    setBar($("disk-bar"), diskRatio);
    $("disk-detail").textContent = `${formatBytes(s.storageUsed)} / ${formatBytes(s.storageTotal)}`;

    $("net-speed").textContent = `↓ ${formatSpeed(s.downloadSpeed)}  ↑ ${formatSpeed(s.uploadSpeed)}`;
    $("uptime").textContent = formatUptime(s.uptimeSeconds);
    $("cpu-temp").textContent =
      s.cpuTemperature != null ? `${s.cpuTemperature.toFixed(1)}°C` : "不可用";

    const sensorsCard = $("sensors-card");
    if (s.sensors.length > 0) {
      sensorsCard.hidden = false;
      $("sensor-list").innerHTML = s.sensors
        .slice(0, 8)
        .map(
          (sensor) =>
            `<div class="list-row"><span class="name">${sensor.name}</span>` +
            `<span class="price">${sensor.temperature.toFixed(1)}°C</span></div>`,
        )
        .join("");
    } else {
      sensorsCard.hidden = true;
    }

    $("footer-status").textContent = `CoolRun for Windows · ${new Date().toLocaleTimeString("zh-CN")}`;
  } catch (error) {
    $("footer-status").textContent = `系统采样失败: ${error}`;
  }
}

// ===== 金价：走势图 =====

let currentRange = "today";
let chartPoints: PricePoint[] = [];

function drawChart() {
  const canvas = $<HTMLCanvasElement>("gold-chart");
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  const ratio = window.devicePixelRatio || 1;
  const width = canvas.clientWidth || 372;
  const height = 160;
  canvas.width = width * ratio;
  canvas.height = height * ratio;
  ctx.scale(ratio, ratio);
  ctx.clearRect(0, 0, width, height);

  if (chartPoints.length < 2) return;

  const prices = chartPoints.map((p) => p.price);
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const span = max - min || 1;
  const padding = { top: 8, bottom: 4, left: 2, right: 44 };
  const plotW = width - padding.left - padding.right;
  const plotH = height - padding.top - padding.bottom;

  const xAt = (i: number) => padding.left + (i / (chartPoints.length - 1)) * plotW;
  const yAt = (price: number) => padding.top + (1 - (price - min) / span) * plotH;

  const rising = prices[prices.length - 1] >= prices[0];
  const lineColor = rising ? "#f0524f" : "#34c77b";

  // 渐变填充
  const gradient = ctx.createLinearGradient(0, padding.top, 0, height);
  gradient.addColorStop(0, rising ? "rgba(240,82,79,0.25)" : "rgba(52,199,123,0.25)");
  gradient.addColorStop(1, "rgba(0,0,0,0)");

  ctx.beginPath();
  chartPoints.forEach((point, i) => {
    const x = xAt(i);
    const y = yAt(point.price);
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  });
  ctx.strokeStyle = lineColor;
  ctx.lineWidth = 1.6;
  ctx.stroke();

  ctx.lineTo(xAt(chartPoints.length - 1), height);
  ctx.lineTo(xAt(0), height);
  ctx.closePath();
  ctx.fillStyle = gradient;
  ctx.fill();

  // 最高/最低价标注
  ctx.fillStyle = "#8b90a0";
  ctx.font = "10px 'Segoe UI', sans-serif";
  ctx.textAlign = "left";
  ctx.fillText(max.toFixed(2), width - padding.right + 4, yAt(max) + 3);
  ctx.fillText(min.toFixed(2), width - padding.right + 4, yAt(min) + 3);
}

async function refreshChart() {
  try {
    chartPoints = await invoke<PricePoint[]>("gold_chart", { range: currentRange });
    drawChart();
    if (chartPoints.length > 0) {
      const first = chartPoints[0];
      const last = chartPoints[chartPoints.length - 1];
      $("chart-range").innerHTML =
        `<span>${formatTime(first.timestampMs)}</span><span>${formatTime(last.timestampMs)}</span>`;
    }
  } catch (error) {
    $("chart-range").textContent = `走势加载失败: ${error}`;
  }
}

$("range-selector").addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  if (!target.classList.contains("range")) return;
  document.querySelectorAll(".range").forEach((r) => r.classList.remove("active"));
  target.classList.add("active");
  currentRange = target.dataset.range!;
  void refreshChart();
});

// ===== 金价：现价 / 指标 / 多源 =====

async function refreshQuote() {
  try {
    const quote = await invoke<GoldQuote>("gold_quote");
    $("gold-price").textContent = `¥${quote.cnyPerGram.toFixed(2)}`;
    $("gold-updated").textContent =
      `${formatTime(quote.updatedAtMs)} · ${quote.source}${quote.isMarketClosed ? " · 休市" : ""}`;

    const changeEl = $("gold-change");
    if (quote.changeAmount != null && quote.changeRatePercent != null) {
      const sign = quote.changeAmount >= 0 ? "+" : "";
      changeEl.textContent = `${sign}${quote.changeAmount.toFixed(2)} (${sign}${quote.changeRatePercent.toFixed(2)}%)`;
      changeEl.className = `gold-change ${quote.changeAmount >= 0 ? "up" : "down"}`;
    } else {
      changeEl.textContent = "--";
      changeEl.className = "gold-change";
    }
  } catch (error) {
    $("gold-price").textContent = "加载失败";
    $("gold-updated").textContent = String(error);
  }
}

function indicatorRow(name: string, value: string): string {
  return `<div class="indicator-item"><span class="name">${name}</span><span class="value">${value}</span></div>`;
}

const fmt = (v: number | null, digits = 2) => (v != null ? v.toFixed(digits) : "--");

async function refreshTechnical() {
  try {
    const t = await invoke<TechnicalSnapshot>("gold_technical");
    $("indicator-grid").innerHTML = [
      indicatorRow("RSI(14)", fmt(t.rsi14, 1)),
      indicatorRow("MACD", fmt(t.macdLine, 3)),
      indicatorRow("SMA5", fmt(t.sma5)),
      indicatorRow("SMA20", fmt(t.sma20)),
      indicatorRow("SMA60", fmt(t.sma60)),
      indicatorRow("年化波动", t.volatility != null ? `${(t.volatility * 100).toFixed(1)}%` : "--"),
      indicatorRow("布林上轨", fmt(t.bollingerUpper)),
      indicatorRow("布林下轨", fmt(t.bollingerLower)),
      indicatorRow("支撑位", fmt(t.supportLevel)),
      indicatorRow("压力位", fmt(t.resistanceLevel)),
    ].join("");

    // 简要解读（与 macOS 版分析引擎的阈值一致：RSI 70/30，MACD 柱正负）
    const hints: string[] = [];
    if (t.rsi14 != null) {
      if (t.rsi14 >= 70) hints.push("RSI 超买，短期回调风险");
      else if (t.rsi14 <= 30) hints.push("RSI 超卖，或有反弹机会");
      else hints.push("RSI 中性");
    }
    if (t.macdHistogram != null) {
      hints.push(t.macdHistogram >= 0 ? "MACD 多头动能" : "MACD 空头动能");
    }
    $("tech-hint").textContent = hints.join(" · ") || "--";
  } catch (error) {
    $("tech-hint").textContent = `指标加载失败: ${error}`;
  }
}

async function refreshMultiSource() {
  try {
    const prices = await invoke<MultiSourcePrice[]>("gold_multi_source");
    $("multi-source-list").innerHTML = prices
      .map((item) => {
        const rate = item.changeRatePercent;
        const rateText = rate != null ? `${rate >= 0 ? "+" : ""}${rate.toFixed(2)}%` : "--";
        const rateClass = rate != null ? (rate >= 0 ? "up" : "down") : "";
        return (
          `<div class="list-row"><span class="name">${item.name}</span>` +
          `<span class="price">¥${item.price.toFixed(2)}</span>` +
          `<span class="rate ${rateClass}">${rateText}</span></div>`
        );
      })
      .join("");
  } catch (error) {
    $("multi-source-list").innerHTML = `<div class="list-row"><span class="name">加载失败: ${error}</span></div>`;
  }
}

async function refreshGold() {
  await Promise.allSettled([refreshQuote(), refreshChart(), refreshTechnical(), refreshMultiSource()]);
}

// ===== 定时刷新 =====

void refreshSystem();
setInterval(() => void refreshSystem(), 3000);

void refreshGold();
setInterval(() => void refreshGold(), 60_000);
