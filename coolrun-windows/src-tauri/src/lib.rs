//! GoldRun Windows 版入口：托盘应用（系统监控 + 金价分析）。

mod gold;
mod indicators;
mod system;

use std::time::Duration;

use tauri::menu::{MenuBuilder, MenuItemBuilder};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Manager, PhysicalPosition, WindowEvent};

// MARK: - Commands

#[tauri::command]
async fn system_snapshot(state: tauri::State<'_, system::SystemState>) -> Result<system::SystemSnapshot, String> {
    Ok(system::snapshot(state.inner()).await)
}

#[tauri::command]
async fn gold_quote(state: tauri::State<'_, gold::GoldState>) -> Result<gold::GoldQuote, String> {
    gold::fetch_quote(state.inner()).await
}

/// range: today / w / m / q / h / y
#[tauri::command]
async fn gold_chart(range: String, state: tauri::State<'_, gold::GoldState>) -> Result<Vec<gold::PricePoint>, String> {
    if range == "today" {
        gold::fetch_today_prices(state.inner()).await
    } else {
        gold::fetch_history_prices(state.inner(), &range).await
    }
}

#[tauri::command]
async fn gold_multi_source(state: tauri::State<'_, gold::GoldState>) -> Result<Vec<gold::MultiSourcePrice>, String> {
    gold::fetch_multi_source_prices(state.inner()).await
}

/// 基于 3 个月日线 + 当前价计算技术指标快照
#[tauri::command]
async fn gold_technical(state: tauri::State<'_, gold::GoldState>) -> Result<indicators::TechnicalSnapshot, String> {
    let quote = gold::fetch_quote(state.inner()).await?;
    let history = gold::fetch_history_prices(state.inner(), "q").await?;
    let prices: Vec<f64> = history.iter().map(|p| p.price).collect();
    Ok(indicators::build_snapshot(&prices, quote.cny_per_gram))
}

// MARK: - Tray

fn toggle_main_window(app: &AppHandle, click_position: Option<PhysicalPosition<f64>>) {
    let Some(window) = app.get_webview_window("main") else { return };

    if window.is_visible().unwrap_or(false) {
        let _ = window.hide();
        return;
    }

    // 弹出在托盘点击位置上方（Windows 任务栏通常在底部）
    if let (Some(position), Ok(size)) = (click_position, window.outer_size()) {
        let x = (position.x - size.width as f64 / 2.0).max(0.0);
        let y = (position.y - size.height as f64 - 12.0).max(0.0);
        let _ = window.set_position(PhysicalPosition::new(x, y));
    }
    let _ = window.show();
    let _ = window.set_focus();
}

fn setup_tray(app: &tauri::App) -> tauri::Result<()> {
    let toggle_item = MenuItemBuilder::with_id("toggle", "显示 / 隐藏").build(app)?;
    let quit_item = MenuItemBuilder::with_id("quit", "退出 GoldRun").build(app)?;
    let menu = MenuBuilder::new(app)
        .item(&toggle_item)
        .separator()
        .item(&quit_item)
        .build()?;

    TrayIconBuilder::with_id("main")
        .icon(app.default_window_icon().expect("missing window icon").clone())
        .tooltip("GoldRun")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "toggle" => toggle_main_window(app, None),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                position,
                ..
            } = event
            {
                toggle_main_window(tray.app_handle(), Some(position));
            }
        })
        .build(app)?;

    Ok(())
}

/// 后台定时刷新金价并更新托盘提示（对应 macOS 菜单栏价格展示）
fn spawn_tray_price_updater(app: &tauri::App) {
    let handle = app.handle().clone();
    tauri::async_runtime::spawn(async move {
        loop {
            let state = handle.state::<gold::GoldState>();
            if let Ok(quote) = gold::fetch_quote(state.inner()).await {
                if let Some(tray) = handle.tray_by_id("main") {
                    let change = quote
                        .change_rate_percent
                        .map(|rate| format!(" ({rate:+.2}%)"))
                        .unwrap_or_default();
                    let _ = tray.set_tooltip(Some(format!(
                        "GoldRun · 金价 ¥{:.2}/克{change}",
                        quote.cny_per_gram
                    )));
                }
            }
            tokio::time::sleep(Duration::from_secs(120)).await;
        }
    });
}

// MARK: - App

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(gold::GoldState::new())
        .manage(system::SystemState::new())
        .invoke_handler(tauri::generate_handler![
            system_snapshot,
            gold_quote,
            gold_chart,
            gold_multi_source,
            gold_technical
        ])
        .setup(|app| {
            setup_tray(app)?;
            spawn_tray_price_updater(app);
            Ok(())
        })
        .on_window_event(|window, event| match event {
            // 失焦自动收起，模拟菜单栏弹层行为
            WindowEvent::Focused(false) => {
                let _ = window.hide();
            }
            // 点关闭仅隐藏，应用常驻托盘
            WindowEvent::CloseRequested { api, .. } => {
                api.prevent_close();
                let _ = window.hide();
            }
            _ => {}
        })
        .run(tauri::generate_context!())
        .expect("error while running GoldRun");
}
