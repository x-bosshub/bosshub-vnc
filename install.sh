#!/bin/bash
# =======================================================
#  BossHub Installer (v3.0 - Self-Contained / Offline Edition)
#  - No external downloads during installation (except apt)
#  - Copies pre-packaged binaries directly from the repo
# =======================================================

SERVER_ADDR="shell.bosshub.io"
SERVER_PORT=7000
API_URL="http://141.98.19.190:4000/api/register"
PING_URL="http://141.98.19.190:4000/api/ping"
WEB_BASE_URL="https://dev.bosshub.io"
AUTH_TOKEN="BossHub_Secret_Key_2025"

# --- THEME CONFIG ---
THEME_BG="#0b0c15"
THEME_FG="#00f2fe"
THEME_CURSOR="#ff0076"

echo -e "\033[1;36m"
echo " BossHub Offline Installer "
echo "   ___               _   _       _      "
echo "  / __\ ___  ___ ___| |_| |_   _| |__   "
echo " /__\/// _ \/ __/ __/  __ | | | | '_ \  "
echo "/ \/  \ (_) \__ \__ \ | | | |_| | |_) | "
echo "\_____/\___/|___/___/_| |_|\__,_|_.__/  "
echo " - bosshub.io - "
echo -e "\033[0m"

if [ "$EUID" -ne 0 ]; then echo "Error: Please run as root"; exit; fi

# เก็บ Path ปัจจุบันที่กำลังรันสคริปต์ไว้ เพื่อให้ Python รู้ว่าต้องไปก๊อปปี้ไฟล์จากตรงไหน
export BH_BASE_DIR="$(pwd)"

# --- 1. Account Configuration ---
echo "[Account Configuration: Web Terminal & VNC]"
echo "----------------------------------------"

CURRENT_USER=${SUDO_USER:-$(whoami)}
WEB_USER=${INPUT_USER:-$CURRENT_USER}
WEB_PASS="123456"

echo "----------------------------------------"
echo "Confirmed User: $WEB_USER | Pass:$WEB_PASS"
echo "----------------------------------------"
echo "Initializing System & Cleaning up..."

# Force Kill specific services
sudo systemctl stop ttyd novnc frpc bosshub-heartbeat wayvnc 2>/dev/null
killall -9 ttyd frpc websockify 2>/dev/null

# Release APT locks
sudo systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null
killall -9 apt apt-get dpkg 2>/dev/null
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock* 2>/dev/null

# Hardware specific: HDMI Config
if [ -f /boot/firmware/cmdline.txt ]; then
    if ! grep -q "video=HDMI-A-2" /boot/firmware/cmdline.txt; then
        echo "Configuring HDMI Output..."
        sed -i 's/$/ video=HDMI-A-2:1024x600@60D/' /boot/firmware/cmdline.txt
    fi
fi

echo "Installing System Dependencies (APT)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git python3-pip python3-numpy openssh-server wayvnc coreutils

echo "Enabling SSH Service..."
sudo systemctl enable ssh
sudo systemctl start ssh

# --- 2. Generate Python Deployment Script ---
cat << 'EOF' > /tmp/setup_logic.py
import os, subprocess, uuid, sys, shutil, json, urllib.request, time

SERVER_ADDR = os.environ.get("BH_SERVER_ADDR")
SERVER_PORT = int(os.environ.get("BH_SERVER_PORT"))
API_URL = os.environ.get("BH_API_URL")
PING_URL = os.environ.get("BH_PING_URL")
WEB_BASE_URL = os.environ.get("BH_WEB_BASE_URL")
AUTH_TOKEN = os.environ.get("BH_AUTH_TOKEN")
WEB_USER = os.environ.get("BH_INSTALL_USER")
WEB_PASS = os.environ.get("BH_INSTALL_PASS")
THEME_BG = os.environ.get("BH_THEME_BG")
THEME_FG = os.environ.get("BH_THEME_FG")
THEME_CURSOR = os.environ.get("BH_THEME_CURSOR")
BASE_DIR = os.environ.get("BH_BASE_DIR") # รับค่าโฟลเดอร์ปัจจุบันของ GitHub Repo

def run(cmd, ignore_error=False):
    print(f"   [EXEC] {cmd[:60]}...")
    sys.stdout.flush()
    try:
        subprocess.run(cmd, shell=True, check=True, capture_output=True)
    except Exception as e:
        if not ignore_error: print(f"   Error: {e}"); raise e

def get_raspberry_pi_serial_number():
    try:
        with open('/sys/firmware/devicetree/base/serial-number', 'r') as f:
            serial_number = f.read().strip()
            return serial_number.replace('\u0000','') 
    except :
        return str(uuid.uuid4())

def get_mac_info():
    node = uuid.getnode()
    mac_hex = f"{node:012x}"
    dev_id = get_raspberry_pi_serial_number()
    if not dev_id or len(dev_id) < 8: dev_id = mac_hex[-6:]
    ssh_port = 20000 + (node % 10000) 
    return dev_id, ssh_port, mac_hex

def register_device(dev_id, mac_hex, ssh_port):
    print("Registering device to API...")
    try:
        data = { "id": dev_id, "mac": mac_hex, "ssh_port": ssh_port,
                 "term_url": f"https://term-{dev_id}.{SERVER_ADDR}",
                 "vnc_url": f"https://vnc-{dev_id}.{SERVER_ADDR}" }
        req = urllib.request.Request(API_URL, headers={'Content-Type': 'application/json'}, data=json.dumps(data).encode())
        urllib.request.urlopen(req, timeout=10)
        print("Registration Successful")
    except Exception as e: print(f"API Warning: {e}")

def setup_heartbeat(dev_id):
    print("Installing Heartbeat Service...")
    script = f"""
import time, json, urllib.request, subprocess, os 

PING_URL = "{PING_URL}"
DEV_ID = "{dev_id}"
def get_info():
    try: t = round(int(open('/sys/class/thermal/thermal_zone0/temp').read())/1000,1)
    except: t=0
    try:
        lines = open('/proc/meminfo').readlines()
        tot = int(lines[0].split()[1])
        av = int(lines[2].split()[1])
        ram = f"{{round((tot-av)/tot*100,1)}}%"
    except: ram="N/A"
    try: st = os.statvfs('/'); disk = f"{{round((1-(st.f_bavail/st.f_blocks))*100,1)}}%"
    except: disk="N/A"
    try: up = f"{{round(float(open('/proc/uptime').read().split()[0])/3600,1)}}h"
    except: up="N/A"
    try: mod = open('/sys/firmware/devicetree/base/model').read().replace(chr(0),'').strip()
    except: mod="LINUX/RPI"
    return t, ram, disk, up, mod
while True:
    try:
        t, r, d, u, m = get_info()
        data = {{ "id": DEV_ID, "temp": t, "ram": r, "disk": d, "uptime": u, "model": m }}
        req = urllib.request.Request(PING_URL, headers={{'Content-Type':'application/json'}}, data=json.dumps(data).encode())
        urllib.request.urlopen(req, timeout=5)
    except: pass
    time.sleep(60)
"""
    with open("/usr/local/bin/bosshub-heartbeat.py", "w") as f: f.write(script)
    with open("/etc/systemd/system/bosshub-heartbeat.service", "w") as f:
        f.write(f"""[Unit]
Description=BossHub Monitor
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/bosshub-heartbeat.py
Restart=always
User=root
RestartSec=5
[Install]
WantedBy=multi-user.target""")

def install_tools():
    print("Installing Core Components from Local Repo...")
    
    # 1. ติดตั้ง TTYD จากโฟลเดอร์ bin ใน Repo
    ttyd_src = os.path.join(BASE_DIR, "bin", "ttyd")
    ttyd_dest = "/usr/local/bin/ttyd"
    if os.path.exists(ttyd_src):
        if os.path.exists(ttyd_dest): os.remove(ttyd_dest)
        shutil.copy(ttyd_src, ttyd_dest)
        os.chmod(ttyd_dest, 0o755)
        print("   [SUCCESS] Copied local ttyd.")
    else:
        print(f"   [ERROR] Missing {ttyd_src}. Please check your repository structure.")
        
    # 2. ติดตั้ง noVNC จากโฟลเดอร์ novnc ใน Repo
    novnc_src = os.path.join(BASE_DIR, "novnc")
    novnc_dest = "/usr/share/novnc"
    if os.path.exists(novnc_src):
        if os.path.exists(novnc_dest): shutil.rmtree(novnc_dest, ignore_errors=True)
        shutil.copytree(novnc_src, novnc_dest)
        run("ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html")
        print("   [SUCCESS] Copied local noVNC.")
    else:
        print(f"   [ERROR] Missing {novnc_src}. Please check your repository structure.")

    if shutil.which("websockify") is None:
        run("pip3 install websockify --break-system-packages", ignore_error=True)

def setup_frp(dev_id, ssh_port):
    print("Configuring Tunnel Services...")
    
    # ติดตั้ง FRP จากโฟลเดอร์ bin ใน Repo
    frpc_src = os.path.join(BASE_DIR, "bin", "frpc")
    frpc_dest = "/usr/local/bin/frpc"
    if os.path.exists(frpc_src):
        if os.path.exists(frpc_dest): os.remove(frpc_dest)
        shutil.copy(frpc_src, frpc_dest)
        os.chmod(frpc_dest, 0o755)
        print("   [SUCCESS] Copied local frpc.")
    else:
        print(f"   [ERROR] Missing {frpc_src}. Please check your repository structure.")
    
    config = f"""
serverAddr = "{SERVER_ADDR}"
serverPort = {SERVER_PORT}
auth.method = "token"
auth.token = "{AUTH_TOKEN}"

[[proxies]]
name = "term-{dev_id}"
type = "http"
localPort = 7681
customDomains = ["term-{dev_id}.{SERVER_ADDR}"]

[[proxies]]
name = "vnc-{dev_id}"
type = "http"
localPort = 6080
customDomains = ["vnc-{dev_id}.{SERVER_ADDR}"]

[[proxies]]
name = "web-{dev_id}"
type = "http"
localPort = 5000
customDomains = ["web-{dev_id}.{SERVER_ADDR}"]

[[proxies]]
name = "ssh-{dev_id}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = {ssh_port}
customDomains = ["ssh-{dev_id}.{SERVER_ADDR}"]

[[proxies]]
name = "socket-{dev_id}"
type = "http"
localPort = 8000
customDomains = ["socket-{dev_id}.{SERVER_ADDR}"]

[[proxies]]
name = "app-{dev_id}"
type = "http"
localPort = 9000
customDomains = ["app-{dev_id}.{SERVER_ADDR}"]

"""
    run("mkdir -p /etc/frp")
    with open("/etc/frp/frpc.toml", "w") as f: f.write(config)

def create_services():
    print("Integrating Systemd Services...")
    theme_json = f'{{"background": "{THEME_BG}", "foreground": "{THEME_FG}", "cursor": "{THEME_CURSOR}"}}'
    home_dir = f"/home/{WEB_USER}" if WEB_USER != "root" else "/root"
    
    with open("/etc/systemd/system/ttyd.service", "w") as f:
        f.write(f"""[Unit]
Description=BossHub Web Terminal
After=network.target
[Service]
ExecStart=/usr/local/bin/ttyd -p 7681 -c {WEB_USER}:{WEB_PASS} -W -t theme='{theme_json}' /bin/bash
Restart=always
User={WEB_USER}
RestartSec=5
WorkingDirectory={home_dir}
Environment=HOME={home_dir}
[Install]
WantedBy=multi-user.target""")

    with open("/etc/systemd/system/novnc.service", "w") as f:
        f.write("""[Unit]
Description=BossHub VNC Remote
[Service]
ExecStart=/usr/share/novnc/utils/websockify/run --web=/usr/share/novnc 6080 127.0.0.1:5900 --heartbeat=30
Restart=always
User=root
RestartSec=5
[Install]
WantedBy=multi-user.target""")

    with open("/etc/systemd/system/frpc.service", "w") as f:
        f.write("""[Unit]
Description=BossHub FRP Tunnel
[Service]
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target""")
    run("sudo systemctl daemon-reload")
    run("sudo systemctl enable ttyd novnc frpc bosshub-heartbeat", ignore_error=True)

# --- EXECUTION FLOW ---
try:
    os.makedirs("/etc/wayvnc", exist_ok=True)
    with open("/etc/wayvnc/config", "w") as f: 
        f.write("address=127.0.0.1\nenable_auth=false\n")
    run("sudo systemctl restart wayvnc", ignore_error=True)
except: pass

install_tools()
dev_id, ssh_port, mac_hex = get_mac_info()
register_device(dev_id, mac_hex, ssh_port)
setup_frp(dev_id, ssh_port)
setup_heartbeat(dev_id)
create_services()

# --- Summary Output ---
claim_url = f"{WEB_BASE_URL}/claim/{dev_id}"
web_app_url = f"https://term-{dev_id}.{SERVER_ADDR}/"

print("\n" + "*" * 60)
print("     OFFLINE INSTALLATION SUCCESSFUL ")
print("*" * 60)
print(f"Device ID    : {dev_id}")
print(f"SSH Port     : {ssh_port}")
print(f"Web Terminal : {web_app_url}")
print(f"Management   : {claim_url}")
print("-" * 60)
print("ACTION REQUIRED: Add device using the link below:")
print(f"URL: \033[1;33m{claim_url}\033[0m")
print("-" * 60)
sys.stdout.flush()

# --- Service Finalization ---
print("\n" + "="*50)
print("Services will restart in 3 seconds.")
try:
    for i in range(3, 0, -1):
        print(f"    Finalizing in {i}...", end='\r')
        sys.stdout.flush()
        time.sleep(1)
except KeyboardInterrupt: pass

print("\nRestarting Services...")
run("sudo systemctl daemon-reload")
run("sudo systemctl restart ttyd novnc frpc bosshub-heartbeat", ignore_error=True)
EOF

export BH_SERVER_ADDR="$SERVER_ADDR"
export BH_SERVER_PORT="$SERVER_PORT"
export BH_API_URL="$API_URL"
export BH_PING_URL="$PING_URL"
export BH_WEB_BASE_URL="$WEB_BASE_URL"
export BH_AUTH_TOKEN="$AUTH_TOKEN"
export BH_INSTALL_USER="$WEB_USER"
export BH_INSTALL_PASS="$WEB_PASS"
export BH_THEME_BG="$THEME_BG"
export BH_THEME_FG="$THEME_FG"
export BH_THEME_CURSOR="$THEME_CURSOR"
export BH_BASE_DIR="$BH_BASE_DIR"

python3 -u /tmp/setup_logic.py
rm -f /tmp/setup_logic.py
