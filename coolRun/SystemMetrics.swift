import Foundation

struct SystemSnapshot: Equatable {
    var cpu = CPUMetrics()
    var memory = MemoryMetrics()
    var storage = StorageMetrics()
    var battery = BatteryMetrics()
    var network = NetworkMetrics()
    var uptime = UptimeMetrics()
    var temperature = TemperatureMetrics()
    var updatedAt = Date()
}

struct CPUMetrics: Equatable {
    var usage: Double = 0
    var coreCount: Int = ProcessInfo.processInfo.activeProcessorCount
}

struct MemoryMetrics: Equatable {
    var used: UInt64 = 0
    var total: UInt64 = ProcessInfo.processInfo.physicalMemory

    var usage: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }
}

struct StorageMetrics: Equatable {
    var used: UInt64 = 0
    var total: UInt64 = 0

    var available: UInt64 {
        total > used ? total - used : 0
    }

    var usage: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }
}

struct BatteryMetrics: Equatable {
    var level: Double?
    var state: BatteryState = .unknown
    var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
}

enum BatteryState: String, Equatable {
    case unknown = "未知"
    case unplugged = "电池供电"
    case charging = "充电中"
    case full = "已充满"
    case noBattery = "无电池"
}

struct NetworkMetrics: Equatable {
    var activeInterfaceCount: Int = 0
    var primaryAddress: String?
    var downloadSpeed: UInt64 = 0  // bytes/sec
    var uploadSpeed: UInt64 = 0    // bytes/sec
}

struct UptimeMetrics: Equatable {
    var uptime: TimeInterval = 0  // seconds

    // 完整格式（用于展开详情）
    var formatted: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let lang = AppSettings.shared.language

        var parts: [String] = []
        if lang == .chinese {
            if days > 0 { parts.append("\(days)天") }
            if hours > 0 { parts.append("\(hours)小时") }
            if minutes > 0 || parts.isEmpty { parts.append("\(minutes)分钟") }
        } else {
            if days > 0 { parts.append("\(days)d") }
            if hours > 0 { parts.append("\(hours)h") }
            if minutes > 0 || parts.isEmpty { parts.append("\(minutes)m") }
        }
        return parts.joined(separator: " ")
    }

    // 紧凑格式（用于标题行，避免布局变化）
    var compactFormatted: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let lang = AppSettings.shared.language

        if lang == .chinese {
            if days > 0 {
                return "\(days)天\(hours)时"
            } else if hours > 0 {
                return "\(hours)时\(minutes)分"
            } else {
                return "\(minutes)分"
            }
        } else {
            if days > 0 {
                return "\(days)d \(hours)h"
            } else if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }
}

struct TemperatureMetrics: Equatable {
    var cpuTemperature: Double? = nil  // Celsius, nil if unavailable
    var gpuTemperature: Double? = nil  // Celsius
    var sensors: [SensorReading] = []  // 所有温度传感器
}

struct SensorReading: Equatable, Identifiable {
    let id = UUID()
    let name: String
    let temperature: Double

    var formatted: String {
        String(format: "%.1f°C", temperature)
    }
}
