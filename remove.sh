# 1. หยุดการทำงานของ Service ที่รันอยู่เบื้องหลังทั้งหมด
sudo systemctl stop bosshub-vnc 2>/dev/null
sudo systemctl stop bosshub-heartbeat 2>/dev/null
sudo systemctl stop wayvnc 2>/dev/null
sudo systemctl stop novnc 2>/dev/null
sudo systemctl stop ttyd 2>/dev/null
sudo systemctl stop frpc 2>/dev/null


# 2. ปิดไม่ให้ Service เปิดตัวเองตอนบูทเครื่อง (Disable)
sudo systemctl disable bosshub-vnc 2>/dev/null
sudo systemctl disable bosshub-heartbeat 2>/dev/null
sudo systemctl disable wayvnc 2>/dev/null
sudo systemctl disable novnc 2>/dev/null
sudo systemctl disable ttyd 2>/dev/null
sudo systemctl disable frpc 2>/dev/null

# 3. ลบไฟล์ Service ออกจากระบบจัดการของ Linux
sudo rm -f /etc/systemd/system/bosshub-vnc.service
sudo rm -f /etc/systemd/system/bosshub-heartbeat.service
sudo rm -f /etc/systemd/system/wayvnc.service
sudo rm -f /etc/systemd/system/novnc.service
sudo rm -f /etc/systemd/system/ttyd.service
sudo rm -f /etc/systemd/system/frpc.service

sudo systemctl daemon-reload
sudo systemctl reset-failed

# 4. กวาดล้างไฟล์โปรแกรม สคริปต์ และคอนฟิกทั้งหมด
sudo rm -rf /usr/share/novnc
sudo rm -rf /etc/wayvnc
sudo rm -f /usr/local/bin/bosshub-heartbeat.py
sudo rm -f /usr/local/bin/frpc
sudo rm -f /usr/local/bin/ttyd


# 5. ถอนการติดตั้งแพ็กเกจ WayVNC และเคลียร์ไฟล์ขยะในระบบ
sudo apt-get remove --purge wayvnc -y
sudo apt-get autoremove -y
sudo apt-get clean

# 6. ลบโฟลเดอร์ Repository ที่ Clone มาติดตั้ง
cd ~
rm -rf ~/bosshub-vnc

echo "------------------------------------------------"
echo "✅ ล้างบางระบบ BossHub VNC และ Tunnel ออกจากเครื่อง 100% เรียบร้อยครับบอส!"
echo "------------------------------------------------"
