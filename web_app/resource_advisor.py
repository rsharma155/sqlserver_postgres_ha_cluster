import sys

GIB = 1024 ** 3

SCALE_TIERS = [
    (32, 1.0),
    (16, 0.5),
    (8, 0.30),
    (0, 0.15),
]


def get_total_ram_gb():
    if sys.platform == "win32":
        import ctypes

        kernel32 = ctypes.windll.kernel32

        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        mem = MEMORYSTATUSEX()
        mem.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        kernel32.GlobalMemoryStatusEx(ctypes.byref(mem))
        return round(mem.ullTotalPhys / GIB, 1)

    if sys.platform == "darwin":
        import subprocess
        try:
            out = subprocess.check_output(["sysctl", "hw.memsize"], text=True)
            bytes_ = int(out.split(":")[1].strip())
            return round(bytes_ / GIB, 1)
        except Exception:
            return 8.0

    # Linux
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    kb = int(line.split()[1])
                    return round(kb / (1024 * 1024), 1)
    except Exception:
        pass

    return 8.0


def recommend():
    ram = get_total_ram_gb()
    for threshold, scale in SCALE_TIERS:
        if ram >= threshold:
            break

    return {
        "total_ram_gb": ram,
        "scale": scale,
        "pg_patroni_mem": f"{max(round(2 * scale, 1), 0.5)}g",
        "pg_etcd_mem": f"{max(int(256 * scale), 128)}m",
        "pg_haproxy_mem": f"{max(int(128 * scale), 64)}m",
        "pg_backup_mem": f"{max(int(512 * scale), 256)}m",
        "pg_seaweed_mem": f"{max(int(512 * scale), 256)}m",
        "sql_node_mem": f"{max(round(6 * scale, 1), 1)}g",
        "sql_node3_mem": f"{max(round(4 * scale, 1), 1)}g",
        "pg_shared_buffers": f"{max(int(512 * scale), 64)}MB",
        "pg_effective_cache_size": f"{max(int(1536 * scale), 192)}MB",
    }


if __name__ == "__main__":
    import json
    print(json.dumps(recommend(), indent=2))
