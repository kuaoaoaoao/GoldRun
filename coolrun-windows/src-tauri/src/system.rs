//! 系统监控采样，对应 macOS 版 SystemSampler.swift / SystemMetrics.swift。
//! 基于 sysinfo 实现：CPU / 内存 / 磁盘 / 网络速率 / 开机时长 / 温度传感器。

use std::time::Instant;

use serde::Serialize;
use sysinfo::{Components, Disks, Networks, System};
use tokio::sync::Mutex;

// MARK: - DTO

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct SystemSnapshot {
    pub cpu_usage: f64,
    pub core_count: usize,
    pub memory_used: u64,
    pub memory_total: u64,
    pub storage_used: u64,
    pub storage_total: u64,
    pub download_speed: u64,
    pub upload_speed: u64,
    pub uptime_seconds: u64,
    pub cpu_temperature: Option<f64>,
    pub sensors: Vec<SensorReading>,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct SensorReading {
    pub name: String,
    pub temperature: f64,
}

// MARK: - State

pub struct SystemState {
    inner: Mutex<Sampler>,
}

struct Sampler {
    sys: System,
    networks: Networks,
    last_net_refresh: Instant,
}

impl SystemState {
    pub fn new() -> Self {
        let mut sys = System::new();
        sys.refresh_cpu_usage();
        sys.refresh_memory();

        Self {
            inner: Mutex::new(Sampler {
                sys,
                networks: Networks::new_with_refreshed_list(),
                last_net_refresh: Instant::now(),
            }),
        }
    }
}

pub async fn snapshot(state: &SystemState) -> SystemSnapshot {
    let mut sampler = state.inner.lock().await;

    // CPU / 内存
    sampler.sys.refresh_cpu_usage();
    sampler.sys.refresh_memory();
    let cpu_usage = (sampler.sys.global_cpu_usage() as f64 / 100.0).clamp(0.0, 1.0);
    let core_count = sampler.sys.cpus().len();
    let memory_used = sampler.sys.used_memory();
    let memory_total = sampler.sys.total_memory();

    // 网络速率：两次刷新之间的字节增量 / 间隔时间
    let elapsed = sampler.last_net_refresh.elapsed().as_secs_f64().max(0.001);
    sampler.networks.refresh(true);
    sampler.last_net_refresh = Instant::now();
    let (received, transmitted) = sampler
        .networks
        .iter()
        .fold((0u64, 0u64), |acc, (_, data)| {
            (acc.0 + data.received(), acc.1 + data.transmitted())
        });
    let download_speed = (received as f64 / elapsed) as u64;
    let upload_speed = (transmitted as f64 / elapsed) as u64;

    // 磁盘：优先系统盘（Windows 为 C:\，其他平台为 /）
    let disks = Disks::new_with_refreshed_list();
    let system_disk = disks.list().iter().find(|disk| {
        let mount = disk.mount_point().to_string_lossy();
        mount == "C:\\" || mount == "/"
    });
    let (storage_total, storage_used) = match system_disk.or_else(|| disks.list().first()) {
        Some(disk) => (
            disk.total_space(),
            disk.total_space().saturating_sub(disk.available_space()),
        ),
        None => (0, 0),
    };

    // 温度传感器（Windows 上部分机型需管理员权限才可读取，读不到则为空）
    let components = Components::new_with_refreshed_list();
    let mut sensors: Vec<SensorReading> = Vec::new();
    let mut cpu_temperature: Option<f64> = None;
    for component in components.list() {
        let Some(temperature) = component.temperature().map(f64::from) else {
            continue;
        };
        if !temperature.is_finite() || temperature <= 0.0 {
            continue;
        }
        let name = component.label().to_string();
        let lowered = name.to_lowercase();
        if cpu_temperature.is_none()
            && (lowered.contains("cpu") || lowered.contains("tctl") || lowered.contains("package"))
        {
            cpu_temperature = Some(temperature);
        }
        sensors.push(SensorReading { name, temperature });
    }
    // 未匹配到 CPU 关键字时，取首个传感器兜底
    if cpu_temperature.is_none() {
        cpu_temperature = sensors.first().map(|s| s.temperature);
    }

    SystemSnapshot {
        cpu_usage,
        core_count,
        memory_used,
        memory_total,
        storage_used,
        storage_total,
        download_speed,
        upload_speed,
        uptime_seconds: System::uptime(),
        cpu_temperature,
        sensors,
    }
}
