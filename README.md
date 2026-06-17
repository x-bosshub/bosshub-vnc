
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

cd ~
sudo rm -f -r ~/bosshub-vnc
git clone https://github.com/x-bosshub/bosshub-vnc.git
cd ~/bosshub-vnc
chmod +x ~/bosshub-vnc/install.sh
nohup sudo bash ~/bosshub-vnc/install.sh > install_update.log 2>&1 &


```
# ลบการติเตั่ง
```
sudo bash ~/bosshub-vnc/remove.sh
sudo rm -f -r ~/bosshub-vnc
```
# bosshub-vnc
