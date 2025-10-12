#!/usr/bin/env python3
from datetime import datetime
import subprocess, socket, requests, shutil, json

# --- utility functions ---
def run(cmd):
    return subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def ping(host):
    result = run(f"ping -c 2 -W 1 {host}")
    return result.returncode == 0, result.stdout.strip()

def check_dns(domain="google.com"):
    try:
        socket.gethostbyname(domain)
        return True
    except socket.gaierror:
        return False

def print_status(ok, text):
    print(("✅" if ok else "❌") + " " + text)

# --- start diagnostics ---
print("\n=== 🌐 Connectivity Diagnostic Tool ===\n")
results = {"timestamp": datetime.now().isoformat(), "steps": {}}

# interface
iface = run("ip route | grep default | awk '{print $5}'").stdout.strip()
results["steps"]["interface"] = iface or "none"
print_status(bool(iface), f"Interface: {iface if iface else 'none'}")
if not iface:
    exit(1)

# ip address
ip_addr = run(f"ip -4 addr show {iface} | grep 'inet ' | awk '{{print $2}}'").stdout.strip()
results["steps"]["ip"] = ip_addr
print_status(bool(ip_addr), f"IP address: {ip_addr if ip_addr else 'none'}")
if not ip_addr:
    exit(1)

# gateway
gateway = run("ip route | grep default | awk '{print $3}'").stdout.strip()
results["steps"]["gateway"] = gateway
print_status(bool(gateway), f"Gateway: {gateway if gateway else 'none'}")
if not gateway:
    exit(1)

# ping tests
ping_targets = ["9.9.9.9", "8.8.8.8", "1.1.1.1"]
ping_ok = False
for target in ping_targets:
    ok, _ = ping(target)
    print_status(ok, f"Ping {target}")
    results["steps"][f"ping_{target}"] = ok
    if ok:
        ping_ok = True
if not ping_ok:
    print("❌ No external IP reachable (check routing or ISP)")
    exit(1)

# dns test
dns_ok = check_dns()
results["steps"]["dns"] = dns_ok
print_status(dns_ok, "DNS resolution works")
if not dns_ok:
    print("❌ DNS resolution failed (try changing resolv.conf or DNS server)")
    exit(1)

# http test
try:
    requests.get("https://google.com", timeout=5)
    http_ok = True
except Exception:
    http_ok = False
results["steps"]["http"] = http_ok
print_status(http_ok, "HTTP connection works")
if not http_ok:
    exit(1)

# --- speedtest ---
print("\n🚀 Speedtest...")
speedtest_data = None

# prefer speedtest-cli (older version)
if shutil.which("speedtest-cli"):
    res = run("speedtest-cli --json")
    try:
        speedtest_data = json.loads(res.stdout)
    except json.JSONDecodeError:
        # fallback to text-based parsing (if --json not supported)
        text = res.stdout
        if "Download" in text and "Upload" in text:
            print("⚠️ speedtest-cli returned text output, parsing manually...")
            for line in text.splitlines():
                if "Download" in line:
                    down = float(line.split()[1])
                if "Upload" in line:
                    up = float(line.split()[1])
            results["speedtest"] = {"download": down, "upload": up, "ping": None}
        else:
            speedtest_data = None

# if not found, try new ookla speedtest
elif shutil.which("speedtest"):
    res = run("speedtest -f json")
    try:
        speedtest_data = json.loads(res.stdout)
    except json.JSONDecodeError:
        print("❌ Failed to parse Ookla speedtest output")

# parse structured JSON results if available
if speedtest_data:
    try:
        if "download" in speedtest_data and "upload" in speedtest_data:
            # old speedtest-cli format
            down = round(speedtest_data["download"] / 1_000_000, 2)
            up = round(speedtest_data["upload"] / 1_000_000, 2)
            ping_ms = round(speedtest_data["ping"], 2)
        elif "download" in speedtest_data.get("result", {}):
            # new Ookla CLI format
            down = round(speedtest_data["result"]["download"]["bandwidth"] * 8 / 1_000_000, 2)
            up = round(speedtest_data["result"]["upload"]["bandwidth"] * 8 / 1_000_000, 2)
            ping_ms = round(speedtest_data["ping"]["latency"], 2)
        else:
            raise ValueError("Unsupported JSON structure")

        print(f"✅ Download: {down} Mbps")
        print(f"✅ Upload:   {up} Mbps")
        print(f"✅ Ping:     {ping_ms} ms")
        results["speedtest"] = {"download": down, "upload": up, "ping": ping_ms}
    except Exception as e:
        print(f"⚠️ Could not parse speedtest JSON: {e}")

elif not shutil.which("speedtest-cli") and not shutil.which("speedtest"):
    print("⚠️ Neither speedtest-cli nor speedtest found. Install one of them:")
    print("   sudo apt install speedtest-cli")
else:
    print("❌ Speedtest failed or returned invalid output")

print("\n=== ✅ Diagnostic complete ===")
