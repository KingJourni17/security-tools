#!/bin/bash

# Security Hardening Script for Linux Systems
# Run with root privileges: sudo ./security_script.sh

# Log File
LOG_FILE="/var/log/security_hardening.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root. Use 'sudo ./security_script.sh'."
  exit 1
fi

echo "Starting security hardening tasks: $(date)"

# -------------------------
# 1. System Updates
# -------------------------
echo "Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq

# -------------------------
# 2. Check Unauthorized Users
# -------------------------
echo "Checking for unauthorized users..."
cut -d: -f1 /etc/passwd | grep -E -v "(root|sync|halt|shutdown)" | while read user; do
  if ! id "$user" &>/dev/null; then
    echo "ALERT: Unauthorized user detected: $user"
  fi
done

# -------------------------
# 3. Firewall Configuration (UFW)
# -------------------------
echo "Configuring firewall (UFW)..."
if command -v ufw &>/dev/null; then
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw enable
  ufw status verbose
else
  echo "WARNING: UFW not installed. Install with 'apt install ufw'."
fi

# -------------------------
# 4. SSH Hardening
# -------------------------
SSH_CONFIG="/etc/ssh/sshd_config"
echo "Hardening SSH configuration..."
cp "$SSH_CONFIG" "$SSH_CONFIG.bak"  # Backup original config

# Disable root login and password authentication
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"

# Restart SSH service
systemctl restart sshd
echo "SSH configuration updated. Root login and password authentication disabled."

# -------------------------
# 5. Check Open Ports
# -------------------------
echo "Checking listening ports..."
ss -tuln | awk 'NR>1 {print $5}' | cut -d':' -f2 | sort -nu

# -------------------------
# 6. Monitor Suspicious Processes
# -------------------------
echo "Checking for suspicious processes..."
ps aux | grep -E "(cryptominer|malware_keyword)" | grep -v grep

# -------------------------
# 7. File Integrity Monitoring (Tripwire)
# -------------------------
echo "Setting up Tripwire..."
if command -v tripwire &>/dev/null; then
  tripwire --init
  echo "Tripwire initialized."
else
  echo "WARNING: Tripwire not installed. Install with 'apt install tripwire'."
fi

# -------------------------
# 8. ClamAV Installation and Scan
# -------------------------
echo "Installing ClamAV..."
apt-get install -y clamav
echo "Updating ClamAV database..."
freshclam
echo "Scanning for malware..."
clamscan -r / --bell -i

# -------------------------
# 9. Fail2Ban Installation
# -------------------------
echo "Installing Fail2Ban..."
apt-get install -y fail2ban
systemctl start fail2ban
systemctl enable fail2ban
echo "Fail2Ban is running."

# -------------------------
# 10. Check File Permissions
# -------------------------
echo "Checking file permissions..."
for file in /etc/passwd /etc/shadow /etc/group; do
  if [ "$(stat -c %a "$file")" != "644" ]; then
    echo "ALERT: Incorrect permissions for $file"
    chmod 644 "$file"
  fi
done

# -------------------------
# 11. Check Failed Login Attempts
# -------------------------
echo "Checking failed login attempts..."
grep "Failed password" /var/log/auth.log | tail -n 20

# -------------------------
# 12. Enable Security Modules
# -------------------------
echo "Checking security modules..."
if [ "$(cat /sys/kernel/security/ima/enabled)" != "1" ]; then
  echo "WARNING: IMA (Integrity Measurement Architecture) is disabled."
fi

# SELinux/AppArmor Check
if command -v sestatus &>/dev/null; then
  sestatus | grep "SELinux status:.*enabled"
elif command -v apparmor_status &>/dev/null; then
  apparmor_status | grep "apparmor module is loaded."
else
  echo "WARNING: No mandatory access control (MAC) system found."
fi

echo "Security hardening tasks completed: $(date)"
