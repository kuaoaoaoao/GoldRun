using System;
using System.IO;
using System.Linq;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;

namespace CoolRun.Services;

// 系统监控采样，对应 macOS 版 SystemSampler.swift。
// CPU/内存使用 Windows 原生 API（P/Invoke），磁盘/网络/开机时长为跨平台实现，
// 便于在 macOS 上开发预览（CPU/内存在非 Windows 平台显示为不可用）。

public sealed record SystemSnapshot(
    double? CpuUsage,
    int CoreCount,
    ulong? MemoryUsed,
    ulong? MemoryTotal,
    ulong StorageUsed,
    ulong StorageTotal,
    ulong DownloadSpeed,
    ulong UploadSpeed,
    TimeSpan Uptime);

public sealed class SystemSampler
{
    public static readonly SystemSampler Shared = new();

    private long _lastIdleTime;
    private long _lastKernelTime;
    private long _lastUserTime;
    private long _lastReceived;
    private long _lastSent;
    private DateTime _lastNetworkSample = DateTime.UtcNow;

    public SystemSnapshot Sample()
    {
        var (download, upload) = SampleNetworkSpeed();
        var (storageUsed, storageTotal) = SampleSystemDisk();
        var (memoryUsed, memoryTotal) = SampleMemory();

        return new SystemSnapshot(
            CpuUsage: SampleCpuUsage(),
            CoreCount: Environment.ProcessorCount,
            MemoryUsed: memoryUsed,
            MemoryTotal: memoryTotal,
            StorageUsed: storageUsed,
            StorageTotal: storageTotal,
            DownloadSpeed: download,
            UploadSpeed: upload,
            Uptime: TimeSpan.FromMilliseconds(Environment.TickCount64));
    }

    // MARK: CPU（Windows: GetSystemTimes 两次采样差值）

    private double? SampleCpuUsage()
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return null;
        }

        if (!GetSystemTimes(out var idle, out var kernel, out var user))
        {
            return null;
        }

        var idleTime = FileTimeToLong(idle);
        var kernelTime = FileTimeToLong(kernel);
        var userTime = FileTimeToLong(user);

        double? usage = null;
        if (_lastIdleTime != 0)
        {
            var idleDelta = idleTime - _lastIdleTime;
            // kernel 时间包含 idle 时间
            var totalDelta = (kernelTime - _lastKernelTime) + (userTime - _lastUserTime);
            if (totalDelta > 0)
            {
                usage = Math.Clamp(1.0 - (double)idleDelta / totalDelta, 0, 1);
            }
        }

        _lastIdleTime = idleTime;
        _lastKernelTime = kernelTime;
        _lastUserTime = userTime;
        return usage;
    }

    // MARK: 内存（Windows: GlobalMemoryStatusEx）

    private static (ulong? Used, ulong? Total) SampleMemory()
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return (null, null);
        }

        var status = new MemoryStatusEx { dwLength = (uint)Marshal.SizeOf<MemoryStatusEx>() };
        if (!GlobalMemoryStatusEx(ref status))
        {
            return (null, null);
        }
        return (status.ullTotalPhys - status.ullAvailPhys, status.ullTotalPhys);
    }

    // MARK: 磁盘（跨平台：优先系统盘）

    private static (ulong Used, ulong Total) SampleSystemDisk()
    {
        try
        {
            var systemRoot = Path.GetPathRoot(Environment.SystemDirectory) ?? "/";
            var drives = DriveInfo.GetDrives().Where(d => d.IsReady).ToList();
            var drive = drives.FirstOrDefault(d => d.RootDirectory.FullName == systemRoot)
                        ?? drives.FirstOrDefault();
            if (drive is null)
            {
                return (0, 0);
            }

            var total = (ulong)drive.TotalSize;
            var used = total - (ulong)drive.AvailableFreeSpace;
            return (used, total);
        }
        catch
        {
            return (0, 0);
        }
    }

    // MARK: 网络速率（跨平台：全接口字节数两次采样差值）

    private (ulong Download, ulong Upload) SampleNetworkSpeed()
    {
        long received = 0;
        long sent = 0;
        try
        {
            foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback
                    || nic.OperationalStatus != OperationalStatus.Up)
                {
                    continue;
                }
                var stats = nic.GetIPStatistics();
                received += stats.BytesReceived;
                sent += stats.BytesSent;
            }
        }
        catch
        {
            return (0, 0);
        }

        var now = DateTime.UtcNow;
        var elapsed = Math.Max((now - _lastNetworkSample).TotalSeconds, 0.001);

        ulong download = 0;
        ulong upload = 0;
        if (_lastReceived > 0 && received >= _lastReceived)
        {
            download = (ulong)((received - _lastReceived) / elapsed);
        }
        if (_lastSent > 0 && sent >= _lastSent)
        {
            upload = (ulong)((sent - _lastSent) / elapsed);
        }

        _lastReceived = received;
        _lastSent = sent;
        _lastNetworkSample = now;
        return (download, upload);
    }

    // MARK: - Windows P/Invoke

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemTimes(
        out System.Runtime.InteropServices.ComTypes.FILETIME lpIdleTime,
        out System.Runtime.InteropServices.ComTypes.FILETIME lpKernelTime,
        out System.Runtime.InteropServices.ComTypes.FILETIME lpUserTime);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MemoryStatusEx lpBuffer);

    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryStatusEx
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    private static long FileTimeToLong(System.Runtime.InteropServices.ComTypes.FILETIME time)
    {
        return ((long)(uint)time.dwHighDateTime << 32) | (uint)time.dwLowDateTime;
    }
}
