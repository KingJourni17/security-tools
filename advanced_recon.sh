#!/bin/bash

# ============================================
# Advanced Reconnaissance Script 🕵️
# Created by Fonki Njinwi A.K.A KingJourni17
# ============================================

# Check if a domain is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target_domain>"
    exit 1
fi

TARGET=$1
OUTPUT_DIR="recon_$TARGET"
mkdir -p $OUTPUT_DIR

echo "[+] Starting advanced reconnaissance on $TARGET..."
echo "[+] Output will be saved in $OUTPUT_DIR/"

# 1. Subdomain Enumeration
echo "[+] Enumerating subdomains..."
subfinder -d $TARGET -o $OUTPUT_DIR/subdomains.txt
amass enum -passive -d $TARGET -o $OUTPUT_DIR/amass_subdomains.txt
cat $OUTPUT_DIR/*.txt | sort -u > $OUTPUT_DIR/all_subdomains.txt
echo "[+] Found $(wc -l < $OUTPUT_DIR/all_subdomains.txt) subdomains"

# 2. Port Scanning
echo "[+] Scanning open ports on live subdomains..."
cat $OUTPUT_DIR/all_subdomains.txt | xargs -P10 -I{} sh -c 'echo {} | httpx -silent' > $OUTPUT_DIR/live_subdomains.txt
nmap -iL $OUTPUT_DIR/live_subdomains.txt -p- --open -oN $OUTPUT_DIR/nmap_scan.txt
echo "[+] Port scanning complete!"

# 3. Technology Stack Detection
echo "[+] Detecting technologies used by live subdomains..."
whatweb -i $OUTPUT_DIR/live_subdomains.txt --log-brief=$OUTPUT_DIR/whatweb.txt
echo "[+] Tech stack detection complete!"

# 4. Basic Vulnerability Scanning
echo "[+] Running nuclei for vulnerability scanning..."
nuclei -l $OUTPUT_DIR/live_subdomains.txt -t ~/nuclei-templates -o $OUTPUT_DIR/nuclei_scan.txt
echo "[+] Vulnerability scanning complete!"

echo "[+] Reconnaissance completed. Check $OUTPUT_DIR/ for results!"
