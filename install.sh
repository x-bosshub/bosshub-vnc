#!/bin/bash

SERVER_ADDR="shell.bosshub.io"
SERVER_PORT=7000
API_URL="http://141.98.19.190:4000/api/register"
PING_URL="http://141.98.19.190:4000/api/ping"
WEB_BASE_URL="https://dev.bosshub.io"
AUTH_TOKEN="BossHub_Secret_Key_2025"

THEME_BG="#0b0c15"
THEME_FG="#00f2fe"
THEME_CURSOR="#ff0076"

echo -e "\033[1;36m"
echo " BossHub Installer "
echo "   ___               _   _       _      "
echo "  / __\ ___  ___ ___| |_| |_   _| |__   "
echo " /__\/// _ \/ __/ __/  __ | | | | '_ \  "
echo "/ \/  \ (_) \__ \__ \ | | | |_| | |_) | "
echo "\_____/\___/|___/___/_| |_|\__,_|_.__/  "
echo " - bosshub.io - "
echo -e "\033[0m"

if [ "$EUID" -ne 0 ]; then echo "Error: Please run as root"; exit; fi

echo "[Account Configuration: Web Terminal & VNC]"
echo "----------------------------------------"

CURRENT_USER=${SUDO_USER:-$(whoami)}
WEB_USER=${INPUT_USER:-$CURRENT_USER}
WEB_PASS="123456"
 
echo "----------------------------------------"
echo "Confirmed User: $WEB_USER | Pass:$WEB_PASS"
echo "----------------------------------------"
echo "Initializing System..."

sudo systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null
killall apt apt-get 2>/dev/null
rm /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock* 2>/dev/null

if [ -f /boot/firmware/cmdline.txt ]; then
    if ! grep -q "video=HDMI-A-2" /boot/firmware/cmdline.txt; then
        echo "Configuring HDMI Output..."
        sed -i 's/$/ video=HDMI-A-2:1024x600@60D/' /boot/firmware/cmdline.txt
    fi
fi

echo "Installing Dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git python3-pip python3-numpy wget curl sed openssh-server

echo "Enabling SSH Service..."
sudo systemctl enable ssh
sudo systemctl start ssh

cat << EOF > /tmp/setup_logic.py
import os, subprocess, uuid, sys, shutil, json, urllib.request, time

SERVER_ADDR = "$SERVER_ADDR"
SERVER_PORT = $SERVER_PORT
API_URL = "$API_URL"
PING_URL = "$PING_URL"
WEB_BASE_URL = "$WEB_BASE_URL"
AUTH_TOKEN = "$AUTH_TOKEN"

WEB_USER = "$WEB_USER"
WEB_PASS = "$WEB_PASS"

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
    except:
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
    except: mod="RPi"
    return t, ram, disk, up, mod
while True:
    try:
        t, r, d, u, m = get_info()
        data = {{ "id": DEV_ID, "temp": t, "ram": r, "disk": d, "uptime": u, "model": "PI5" }}
        req = urllib.request.Request(PING_URL, headers={{'Content-Type':'application/json'}}, data=json.dumps(data).encode())
        urllib.request.urlopen(req, timeout=5)
    except: pass
    time.sleep(60)
"""
    with open("/usr/local/bin/bosshub-heartbeat.py", "w") as f: f.write(script)
    with open("/etc/systemd/system/bosshub-heartbeat.service", "w") as f:
        f.write(f"""[Unit]
Description=BossHub Monitor
After=network.target network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/bosshub-heartbeat.py
Restart=always
User=root
RestartSec=5
[Install]
WantedBy=multi-user.target""")

def install_tools():
    print("Downloading Core Components...")
    if not os.path.exists("/usr/local/bin/ttyd"):
        run("wget -4 -qO /tmp/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.aarch64")
        run("mv /tmp/ttyd /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd")
    if not os.path.exists("/usr/share/novnc"):
        run("git clone https://github.com/novnc/noVNC.git /usr/share/novnc")
        run("git clone https://github.com/novnc/websockify.git /usr/share/novnc/utils/websockify")
        run("ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html")
    if shutil.which("websockify") is None:
        run("pip3 install websockify --break-system-packages", ignore_error=True)

def setup_frp(dev_id, ssh_port):
    print("Configuring Tunnel Services...")
    arch = subprocess.check_output("uname -m", shell=True).decode().strip()
    
    frp_ver = "0.69.1"
    frp_arch = "arm64" if "aarch64" in arch or "arm" in arch else "amd64"
    
    if not os.path.exists("/usr/local/bin/frpc"):
        url = f"https://github.com/fatedier/frp/releases/download/v{frp_ver}/frp_{frp_ver}_linux_{frp_arch}.tar.gz"
        run(f"wget -4 -O /tmp/frp.tar.gz {url}")
        run(f"tar -xzf /tmp/frp.tar.gz -C /tmp")
        run(f"mv /tmp/frp_{frp_ver}_linux_{frp_arch}/frpc /usr/local/bin/frpc && chmod +x /usr/local/bin/frpc")
    
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
remotePort = 22
customDomains = ["ssh-{dev_id}.{SERVER_ADDR}"]

[[proxies]]
name = "socket-{dev_id}"
type = "http"
localIP = "127.0.0.1"
localPort = 8000
remotePort = 8000
customDomains = ["socket-{dev_id}.{SERVER_ADDR}"]

[[proxies]]
name = "app-{dev_id}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 9000
remotePort = 9000
customDomains = ["app-{dev_id}.{SERVER_ADDR}"]
"""

    run("mkdir -p /etc/frp")
    with open("/tmp/frpc.toml", "w") as f: f.write(config)
    run("mv /tmp/frpc.toml /etc/frp/frpc.toml")

def create_services():
    print("Integrating Systemd Services...")
    theme_json = '{"background": "$THEME_BG", "foreground": "$THEME_FG", "cursor": "$THEME_CURSOR"}'
    
    with open("/etc/systemd/system/ttyd.service", "w") as f:
        f.write(f"""[Unit]
Description=BossHub Web Terminal
After=network.target network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/local/bin/ttyd -p 7681 -W -t theme='{theme_json}' /bin/bash
Restart=always
User={WEB_USER}
RestartSec=5
WorkingDirectory=/home/{WEB_USER}
Environment=HOME=/home/{WEB_USER}
[Install]
WantedBy=multi-user.target""")

    with open("/etc/systemd/system/novnc.service", "w") as f:
        f.write("""[Unit]
Description=BossHub VNC Remote
After=network.target network-online.target
Wants=network-online.target
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
After=network.target network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target""")
    
    run("sudo systemctl daemon-reload")
    run("sudo systemctl enable ttyd.service novnc.service frpc.service bosshub-heartbeat.service")

try:
    if os.path.exists("/etc/wayvnc/config"):
        run("mkdir -p /etc/wayvnc", ignore_error=True)
        with open("/etc/wayvnc/config", "w") as f: f.write("address=127.0.0.1\nenable_auth=false\n")
        run("sudo systemctl restart wayvnc", ignore_error=True)
except: pass

install_tools()
dev_id, ssh_port, mac_hex = get_mac_info()
register_device(dev_id, mac_hex, ssh_port)
setup_frp(dev_id, ssh_port)
setup_heartbeat(dev_id)
create_services()

claim_url = f"{WEB_BASE_URL}/claim/{dev_id}"
web_app_url = f"https://term-{dev_id}.{SERVER_ADDR}/"

print("\n" + "*" * 60)
print("     INSTALLATION SUCCESSFUL ")
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

print("\n" + "="*50)
print("Services will restart in 3 seconds.")
try:
    for i in range(5, 0, -1):
        print(f"    Finalizing in {i}...", end='\r')
        sys.stdout.flush()
        time.sleep(1)
except KeyboardInterrupt:
    print("\n    Skipping delay...")

print("\nRestarting Services...")
run("sudo systemctl daemon-reload")
run("sudo systemctl restart ttyd.service novnc.service frpc.service bosshub-heartbeat.service", ignore_error=True)
EOF

export BH_INSTALL_USER="$WEB_USER"
export BH_INSTALL_PASS="$WEB_PASS"
python3 -u /tmp/setup_logic.py
rm /tmp/setup_logic.py
