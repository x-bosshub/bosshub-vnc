# วิธีที่ 1 ติดตั้งใน บน Raspberry Pi5 (ผ่านหน้าจอ)
```bash
cd /home/pi5
git clone https://github.com/x-bosshub/bosshub-vnc.git
cd bosshub-vnc

chmod +x install.sh
sudo ./install.sh

```
# 2 ติดตั้งแบบ Remote TERM 
```bash
cd /home/pi5
sudo rm -rf ~/bosshub-vnc

git clone https://github.com/x-bosshub/bosshub-vnc.git
cd bosshub-vnc

chmod +x install.sh
nohup sudo ./install.sh > install_log.txt 2>&1 &

```
# ติดตั้ง เฉพาะ Term 64Bit
```
curl -sL https://raw.githubusercontent.com/x-bosshub/bosshub-vnc/refs/heads/main/install_term.sh | sudo bash
```

# ติดตั้ง Term 32Bit
```
curl -sL https://raw.githubusercontent.com/x-bosshub/bosshub-vnc/refs/heads/main/install_32bit.sh | sudo bash
```
# Raspberry Pi/ Linux
ดาวห์โหลดและติดตั้ง
```
# เปิดใช้งาน VNC (0 = เปิด, 1 = ปิด)
# sudo raspi-config nonint do_vnc 0
# เปิดใช้งาน I2C (0 = เปิด, 1 = ปิด)
# sudo raspi-config nonint do_i2c 0
# เปิดใช้งาน SPI (0 = เปิด, 1 = ปิด)
# sudo raspi-config nonint do_spi 0
# sudo raspi-config nonint do_boot_behaviour B4

cd ~ && sudo rm -rf ~/bosshub-vnc && git clone https://github.com/x-bosshub/bosshub-vnc.git ~/bosshub-vnc && chmod +x ~/bosshub-vnc/install.sh && nohup sudo bash ~/bosshub-vnc/install.sh > install_update.log 2>&1 &


```
# ลบการติเตั่ง
```
sudo bash ~/bosshub-vnc/remove.sh
sudo rm -f -r ~/bosshub-vnc
```
# bosshub-vnc
