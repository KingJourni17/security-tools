#!/bin/bash

# Security Hardening Script for macOS
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
softwareupdate --install --all

# -------------------------
# 2. Check Unauthorized Users
# -------------------------
echo "Checking for unauthorized users..."
cut -d: -f1 /etc/passwd | grep -vE "^(root|daemon|nobody|_|#)" | while read user; do
  if ! id "$user" &>/dev/null; then
    echo "ALERT: Unauthorized user detected: $user"
  fi
done

# -------------------------
# 3. Firewall Configuration (PF)
# -------------------------
echo "Configuring firewall (PF)..."
pfctl -f /etc/pf.conf
pfctl -e
echo "Firewall configured and enabled."

# -------------------------
# 4. SSH Hardening
# -------------------------
SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
  echo "Hardening SSH configuration..."
  cp "$SSH_CONFIG" "$SSH_CONFIG.bak"  # Backup original config

  # Disable root login and password authentication
  sed -i '' 's/^#PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
  sed -i '' 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"

  # Restart SSH service
  launchctl stop com.openssh.sshd
  launchctl start com.openssh.sshd
  echo "SSH configuration updated. Root login and password authentication disabled."
else
  echo "WARNING: SSH configuration file not found at $SSH_CONFIG."
fi

# -------------------------
# 5. Check Open Ports
# -------------------------
echo "Checking listening ports..."
lsof -i -P | grep LISTEN

# -------------------------
# 6. Monitor Suspicious Processes
# -------------------------
echo "Checking for suspicious processes..."
ps aux | grep -E "(cryptominer|malware_keyword)" | grep -v grep

# -------------------------
# 7. File Integrity Monitoring (Basic)
# -------------------------
echo "Generating checksums for critical files..."
CRITICAL_FILES="/etc/passwd /etc/shadow /etc/ssh/sshd_config"
for file in $CRITICAL_FILES; do
  if [ -f "$file" ]; then
    shasum "$file" >> /var/log/file_checksums.log
  fi
done

# -------------------------
# 8. Check File Permissions
# -------------------------
echo "Checking file permissions..."
for file in /etc/passwd /etc/shadow /etc/group; do
  if [ -f "$file" ]; then
    PERM=$(stat -f "%Lp" "$file")
    if [ "$PERM" != "644" ]; then
      echo "ALERT: Incorrect permissions for $file"
      chmod 644 "$file"
    fi
  else
    echo "WARNING: $file not found."
  fi
done

# -------------------------
# 9. Check Failed Login Attempts
# -------------------------
echo "Checking failed login attempts..."
last | grep -i "failed"

# -------------------------
# 10. Enable Security Modules
# -------------------------
echo "Checking security modules..."
if [ "$(csrutil status | grep -i 'System Integrity Protection')" != "System Integrity Protection status: enabled." ]; then
  echo "WARNING: System Integrity Protection (SIP) is disabled."
fi

echo "Security hardening tasks completed: $(date)"
