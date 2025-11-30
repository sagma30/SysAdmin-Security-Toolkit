#!/bin/bash

DISK_THRESHOLD=85
need_sudo()
{
    if [ "$EUID" -ne 0 ]; then
        echo "Note: some features require sudo to read system logs. Run: sudo ./toolkit.sh"
    fi
}
system_uptime() {
    echo "------ System Uptime ------"
    uptime
    echo
}
disk_usage()
{
    echo "------ Disk Usage (df -h) ------"
    df -h --output=source,fstype,size,used,avail,pcent,target
    echo
    echo "Checking for partitions over ${DISK_THRESHOLD}%..."
    df -P | awk 'NR>1 {gsub("%","",$5); if ($5+0 > '"${DISK_THRESHOLD}"') print $1 " " $5"% used on " $6}' || true
    echo
}
logged_in_users() {
    echo "------ Logged-In Users ------"
    who || true
    echo
}
network_info() {
    echo "------ Network Information ------"
    ip -br a
    echo
    echo "Routing table:"
    ip route
    echo
}
failed_logins() {
    echo "------ Failed Login Attempts ------"

    if [ -f /var/log/auth.log ]; then
        LOGFILE=/var/log/auth.log
    elif [ -f /var/log/secure ]; then
        LOGFILE=/var/log/secure
    else
        LOGFILE=""
    fi
    if [ -n "$LOGFILE" ]; then
        echo "Parsing: $LOGFILE (top offending IPs / users)"
        # Common patterns differ per distro; attempt to capture IPs and usernames
        sudo grep -iE "failed|authentication failure|invalid user|authentication failure" "$LOGFILE" 2>/dev/null \
          | awk '{ for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print $i; }' \
          | sort | uniq -c | sort -nr | head -n 10
        echo
        echo "Top failed login lines (last 30 matches):"
        sudo grep -iE "failed|authentication failure|invalid user|authentication failure" "$LOGFILE" 2>/dev/null | tail -n 30
    else
        # Last resort: systemd journal (if available)
        if command -v journalctl >/dev/null 2>&1; then
            echo "No auth log file found. Using journalctl (requires sudo)."
            sudo journalctl _SYSTEMD_UNIT=sshd.service -o short-iso | grep -i "failed" | tail -n 30
        else
            echo "No authentication logs found on this system."
        fi
    fi
    echo
}
process_list() {
    echo "------ Top Running Processes ------"
    ps aux --sort=-%cpu | head -n 12
    echo
    echo "Top by memory:"
    ps aux --sort=-%mem | head -n 12
    echo
}
show_help() {
    echo "SysAdmin Security Toolkit"
    echo "Run the script and choose options from the menu. For log parsing, run with sudo if you want full output."
    echo
}
need_sudo

while true; do
    echo "------------------------------------"
    echo "     SysAdmin Security Toolkit"
    echo "------------------------------------"
    echo "1) System Uptime"
    echo "2) Disk Usage"
    echo "3) Logged-In Users"
    echo "4) Network Information"
    echo "5) Failed Login Attempts"
    echo "6) Running Processes"
    echo "7) Help"
    echo "8) Exit"
    echo
    read -rp "Enter your choice: " choice

    case $choice in
        1) system_uptime ;;
        2) disk_usage ;;
        3) logged_in_users ;;
        4) network_info ;;
        5) failed_logins ;;
        6) process_list ;;
        7) show_help ;;
        8) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice. Try again." ;;
    esac
done
