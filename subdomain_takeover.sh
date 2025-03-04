#!/bin/bash

# ============================================
# Subdomain Takeover Detection Script 🏴
# Created by Fonki Njinwi A.K.A KingJourni17
# ============================================

# Check if a domain is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target_domain>"
    exit 1
fi

TARGET=$1
OUTPUT_DIR="takeover_$TARGET"
mkdir -p $OUTPUT_DIR

echo "[+] Checking for subdomain takeover vulnerabilities on $TARGET..."
echo "[+] Output will be saved in $OUTPUT_DIR/"

# 1. Subdomain Enumeration
echo "[+] Enumerating subdomains..."
subfinder -d $TARGET -o $OUTPUT_DIR/subdomains.txt
amass enum -passive -d $TARGET -o $OUTPUT_DIR/amass_subdomains.txt
cat $OUTPUT_DIR/*.txt | sort -u > $OUTPUT_DIR/all_subdomains.txt
echo "[+] Found $(wc -l < $OUTPUT_DIR/all_subdomains.txt) subdomains"

# 2. Checking for dangling subdomains
echo "[+] Checking for unclaimed subdomains..."
subjack -w $OUTPUT_DIR/all_subdomains.txt -o $OUTPUT_DIR/takeover_vulnerable.txt -ssl -c ~/subjack_fingerprints.json

# 3. Manual verification prompt
echo "[+] Potential subdomain takeovers saved in $OUTPUT_DIR/takeover_vulnerable.txt"
echo "[+] Please verify manually before reporting!"

echo "[+] Subdomain takeover scan completed!"
