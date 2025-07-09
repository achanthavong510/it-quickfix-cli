#!/bin/bash

# IT QuickFix CLI (macOS)
# A Bash-based utility to automate and diagnose common macOS IT support and maintenance tasks.
# Features include: network fixes, cache cleaning, UI restarts, firewall management, VPN check, disk cleanup, and more.

# --- Logging and Error Handling ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

LOG_WARNINGS=0
LOG_ERRORS=0
LOG_ACTIONS=()
LOG_RECOMMENDATIONS=()

log() {
    local level="$1"
    local msg="$2"
    local color="$NC"
    local symbol=""
    case "$level" in
        DEBUG)   color="$CYAN"; symbol="🐞";;
        INFO)    color="$BLUE"; symbol="ℹ️ ";;
        SUCCESS) color="$GREEN"; symbol="✅";;
        WARNING) color="$YELLOW"; symbol="⚠️ "; LOG_WARNINGS=$((LOG_WARNINGS+1));;
        ERROR)   color="$RED"; symbol="❌"; LOG_ERRORS=$((LOG_ERRORS+1));;
        *)       color="$NC"; symbol="";;
    esac
    if [[ "$level" == "ERROR" || "$level" == "WARNING" || "$VERBOSE" == "1" ]]; then
        echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $symbol $msg${NC}"
    fi
    [[ "$level" == "SUCCESS" || "$level" == "INFO" ]] && LOG_ACTIONS+=("$msg")
}

add_recommendation() {
    LOG_RECOMMENDATIONS+=("$1")
}

show_log_summary() {
    echo -e "\n\033[1mSummary for this action:\033[0m"
    if (( ${#LOG_ACTIONS[@]} > 0 )); then
        echo -e "${BLUE}What was checked/fixed:${NC}"
        for a in "${LOG_ACTIONS[@]}"; do
            echo -e "  - $a"
        done
    fi
    if (( LOG_WARNINGS > 0 || LOG_ERRORS > 0 )); then
        echo -e "${YELLOW}Warnings: $LOG_WARNINGS${NC}  ${RED}Errors: $LOG_ERRORS${NC}"
    else
        echo -e "${GREEN}No warnings or errors detected.${NC}"
    fi
    if (( ${#LOG_RECOMMENDATIONS[@]} > 0 )); then
        echo -e "\n${BLUE}Recommended next steps:${NC}"
        for r in "${LOG_RECOMMENDATIONS[@]}"; do
            echo -e "  - $r"
        done
    fi
    LOG_WARNINGS=0
    LOG_ERRORS=0
    LOG_ACTIONS=()
    LOG_RECOMMENDATIONS=()
}

error_exit() {
    log ERROR "ERROR: $1"
    exit 1
}

check_for_update() {
    clear
    echo "⬆️  Checking for macOS & App Store Updates..."
    log INFO "Checking for macOS updates..."
    local updates=$(softwareupdate -l 2>&1)
    if echo "$updates" | grep -q '\*'; then
        echo -e "${YELLOW}⚠️  Pending macOS updates found:${NC}"
        echo "$updates" | grep '^\*' | sed 's/^/  /'
        log WARNING "Pending macOS updates found."
    else
        echo -e "${GREEN}✅ No pending macOS updates.${NC}"
        log SUCCESS "No pending macOS updates."
    fi
    echo
    if command -v mas &> /dev/null; then
        log INFO "Checking for App Store updates (mas)..."
        local mas_updates=$(mas outdated)
        if [[ -n "$mas_updates" ]]; then
            echo -e "${YELLOW}⚠️  Pending App Store updates found:${NC}"
            echo "$mas_updates" | sed 's/^/  /'
            log WARNING "Pending App Store updates found."
        else
            echo -e "${GREEN}✅ No pending App Store updates.${NC}"
            log SUCCESS "No pending App Store updates."
        fi
    else
        echo -e "${BLUE}ℹ️  'mas' (Mac App Store CLI) not installed. Skipping App Store update check.${NC}"
        log INFO "'mas' (Mac App Store CLI) not installed. Skipping App Store update check."
    fi
    echo
    read -p $'Press Enter to return...'
}

firewall_status() {
    log INFO "Enabling firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    log INFO "Firewall status: $status"
}

show_help() {
    cat <<EOF
IT QuickFix CLI (macOS)
Usage: $0 <command>

Commands:
  all       Run all safe fixes
  network   Flush DNS & renew DHCP lease
  clean     Clear caches & restart UI
  help      Show this help message
EOF
}

# --- Network-related functions ---
# Flushes the macOS DNS cache to resolve name resolution issues
flush_dns() {
    log INFO "Flushing DNS cache..."
    sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && log SUCCESS "DNS cache flushed." || error_exit "Failed to flush DNS cache."
}

# Renews the DHCP lease for all network devices (en0, en1, etc.)
renew_dhcp() {
    log INFO "Renewing DHCP lease..."
    devices=$(networksetup -listallhardwareports | awk '/Device: /{print $2}')
    local any_failed=0
    for dev in $devices; do
        if sudo ipconfig set "$dev" DHCP; then
            log SUCCESS "Renewed DHCP for $dev."
        else
            log ERROR "Failed to renew DHCP for $dev."
            any_failed=1
        fi
    done
    if [[ $any_failed -eq 1 ]]; then
        log ERROR "One or more DHCP renewals failed."
    else
        log SUCCESS "All DHCP renewals succeeded."
    fi
}

# Checks for active VPN connections by looking for utun interfaces and scutil status
check_vpn_status() {
    log INFO "Checking for active VPN connections..."
    local vpn_active=0
    if ifconfig | grep -q 'utun'; then
        log SUCCESS "🔒 VPN appears to be active (utun interface detected)."
        vpn_active=1
    fi
    if scutil --nc list 2>/dev/null | grep -q 'Connected'; then
        log SUCCESS "🔒 VPN is active via scutil (Network Configuration)."
        vpn_active=1
    fi
    if [[ $vpn_active -eq 0 ]]; then
        log WARNING "🔓 No VPN interface detected. VPN likely inactive."
    fi
}

# Runs a network speed test using speedtest-cli (installs if missing)
network_speed_test() {
    log INFO "Running network speed test..."
    if ! command -v speedtest &> /dev/null; then
        log INFO "speedtest-cli not found. Installing via Homebrew..."
        brew install speedtest-cli || {
            log ERROR "Installation failed. Skipping speed test."
            return
        }
    fi
    speedtest | tee -a "$LOGFILE"
}

# Runs network diagnostics: ping, traceroute, or DNS lookup
network_diagnostics() {
    echo "Choose a network diagnostic test:"
    select diag in "Ping" "Traceroute" "DNS Lookup" "Cancel"; do
        case $REPLY in
            1)
                read -p "Enter host to ping: " host
                log INFO "Pinging $host..."
                ping -c 4 "$host" | tee -a "$LOGFILE"
                ;;
            2)
                read -p "Enter host for traceroute: " host
                log INFO "Running traceroute to $host..."
                traceroute "$host" | tee -a "$LOGFILE"
                ;;
            3)
                read -p "Enter domain for DNS lookup: " domain
                log INFO "Running DNS lookup for $domain..."
                dig "$domain" | tee -a "$LOGFILE"
                ;;
            4)
                log INFO "Network diagnostics cancelled."
                ;;
            *)
                echo "Invalid choice." ;;
        esac
        break
    done
}

# --- System cleanup and maintenance functions ---
# Clears system and user cache folders to free up space and resolve cache-related issues
clear_caches() {
    read -p $'Are you sure you want to clear system and user caches? (y/n): ' confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log INFO "Clearing system and user caches..."
        sudo rm -rf /Library/Caches/* 2> >(grep -v 'Operation not permitted' >&2) && log SUCCESS "System cache cleared."
        rm -rf ~/Library/Caches/* 2> >(grep -v 'Operation not permitted' >&2) && log SUCCESS "User cache cleared."
    else
        log INFO "Cache clearing cancelled by user."
    fi
}

# Resets the macOS printing system by removing printer configs and restarting CUPS
reset_printing() {
    read -p $'Are you sure you want to reset the printing system? This will remove all printers and queues. (y/n): ' confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log INFO "Resetting printing system..."
        sudo launchctl stop org.cups.cupsd
        sudo rm -rf /Library/Printers/PPDs/Contents/Resources/*
        sudo rm -rf /Library/Printers/*
        sudo rm -rf /Library/Preferences/org.cups.*
        sudo launchctl start org.cups.cupsd
        log SUCCESS "Printing system reset."
    else
        log INFO "Printing system reset cancelled by user."
    fi
}

# Restarts the Dock and Finder processes to resolve UI glitches
restart_ui() {
    log INFO "Restarting Dock and Finder..."
    killall Dock && log SUCCESS "Dock restarted."
    killall Finder && log SUCCESS "Finder restarted."
}

# Purges inactive memory to free up RAM
purge_memory() {
    log INFO "Purging inactive memory..."
    sudo purge && log SUCCESS "Inactive memory purged."
}

# --- Diagnostics and reporting functions ---
# Runs a series of diagnostic checks and attempts to fix detected issues
smart_scan() {
    log INFO "🔍 Running SmartScan diagnostics..."
    if ! ping -c 2 1.1.1.1 &> /dev/null; then
        log ERROR "❌ No internet connection detected."
        log INFO "✔ Suggestion: Flush DNS and Renew DHCP."
        flush_dns
        renew_dhcp
    else
        log SUCCESS "✅ Internet connectivity: OK"
    fi
    if ! ifconfig | grep -q 'utun'; then
        log INFO "⚠️ VPN is not active (utun interface missing)."
    else
        log SUCCESS "✅ VPN is active."
    fi
    fw_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    if [[ "$fw_status" == *"disabled"* ]]; then
        log ERROR "❌ Firewall is disabled."
        firewall_status
    else
        log SUCCESS "✅ Firewall is enabled."
    fi
    mem_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    if [[ $mem_free -lt 50000 ]]; then
        log INFO "⚠️ Low free memory detected. Suggesting purge."
        purge_memory
    else
        log SUCCESS "✅ Memory levels: OK"
    fi
    if lpq | grep -q 'active'; then
        log INFO "🖨 Print jobs stuck in queue."
        reset_printing
    else
        log SUCCESS "✅ No active print jobs."
    fi
    log SUCCESS "🧠 SmartScan complete. All relevant issues logged and fixed where needed."
}

# Toggles Wi-Fi off and on to reset the wireless connection
reset_wifi() {
    log INFO "Toggling Wi-Fi off and on..."
    wifi_service=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
    networksetup -setairportpower "$wifi_service" off && sleep 2
    networksetup -setairportpower "$wifi_service" on && log SUCCESS "Wi-Fi has been reset." || log ERROR "Failed to toggle Wi-Fi."
}

# Checks for pending macOS and App Store updates
software_update_check() {
    log INFO "Checking for macOS software updates..."
    softwareupdate -l 2>&1 | tee -a "$LOGFILE"
    if command -v mas &> /dev/null; then
        log INFO "Checking for App Store updates (mas)..."
        mas outdated | tee -a "$LOGFILE"
    else
        log INFO "'mas' (Mac App Store CLI) not installed. Skipping App Store update check."
    fi
}

# Checks S.M.A.R.T. status for all disks
hardware_health_check() {
    log INFO "Checking hardware S.M.A.R.T. status for all disks..."
    diskutil list | awk '/^\/dev\//{print $1}' | while read disk; do
        log INFO "S.M.A.R.T. status for $disk:"
        diskutil info $disk | grep -E 'Device Identifier|SMART Status' | tee -a "$LOGFILE"
    done
}

run_all() {
    flush_dns || log ERROR "Flush DNS failed. Continuing..."
    renew_dhcp || log ERROR "Renew DHCP failed. Continuing..."
    clear_caches || log ERROR "Clear caches failed. Continuing..."
    restart_ui || log ERROR "Restart UI failed. Continuing..."
    purge_memory || log ERROR "Purge memory failed. Continuing..."
    firewall_status || log ERROR "Firewall status failed. Continuing..."
}

run_network() {
    flush_dns
    renew_dhcp
}

run_clean() {
    clear_caches
    restart_ui
}

main_menu() {
    while true; do
        clear
        echo "🧰 IT QuickFix CLI (macOS)"
        echo ""
        echo "1) 🚦  Quick System Scan / Pre-Check"
        echo "2) 🌐  Network Tools"
        echo "3) 🛠️   System Maintenance"
        echo "4) 📝  Reports & Utilities"
        echo "5) ❌  Quit"
        echo ""
        read -p "Enter your choice (1-5): " main_choice
        case $main_choice in
            1) quick_system_scan; ;;
            2) network_tools_menu; ;;
            3) system_maintenance_menu; ;;
            4) reports_utilities_menu; ;;
            5) echo "👋 Exiting."; exit 0 ;;
            *) echo "❌ Invalid choice. Press Enter to try again."; read;;
        esac
    done
}

network_pre_scan() {
    clear
    echo "🌐  Network Pre-Scan"
    local recommendations=()
    echo

    # Internet connectivity
    if ping -c 2 1.1.1.1 &>/dev/null; then
        echo -e "${GREEN}✅ Internet connectivity: OK${NC}"
    else
        echo -e "${RED}❌ No internet connectivity${NC}"
        recommendations+=("Run All Network Fixes or check your router connection.")
    fi

    # Default gateway
    local gw=$(netstat -rn | awk '/default/ {print $2; exit}')
    if [[ -n "$gw" ]] && ping -c 2 "$gw" &>/dev/null; then
        echo -e "${GREEN}✅ Gateway ($gw): Reachable${NC}"
    else
        echo -e "${RED}❌ Gateway: Not reachable${NC}"
        recommendations+=("Renew DHCP Lease or check your router.")
    fi

    # DNS resolution
    if dig +short apple.com | grep -qE '^[0-9.]+'; then
        echo -e "${GREEN}✅ DNS resolution: OK${NC}"
    else
        echo -e "${RED}❌ DNS resolution failed${NC}"
        recommendations+=("Flush DNS Cache or check your DNS settings.")
    fi

    # VPN status
    local vpn_active=0
    if ifconfig | grep -q 'utun'; then vpn_active=1; fi
    if scutil --nc list 2>/dev/null | grep -q 'Connected'; then vpn_active=1; fi
    if [[ $vpn_active -eq 1 ]]; then
        echo -e "${GREEN}✅ VPN: Active${NC}"
    else
        echo -e "${YELLOW}⚠️  VPN: Inactive${NC}"
        recommendations+=("Check VPN Connection if you expect to be on VPN.")
    fi

    # IP address and interface
    local ip_info=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
    if [[ -n "$ip_info" ]]; then
        echo -e "${GREEN}✅ IP Address: $ip_info${NC}"
    else
        echo -e "${RED}❌ No IP address assigned${NC}"
        recommendations+=("Renew DHCP Lease or Reset Wi-Fi Connection.")
    fi

    echo
    if (( ${#recommendations[@]} > 0 )); then
        echo -e "${BLUE}Recommended next steps:${NC}"
        for r in "${recommendations[@]}"; do
            echo -e "  - $r"
        done
    else
        echo -e "${GREEN}No network issues detected. Your connection looks good!${NC}"
    fi
    echo
    read -p $'Press Enter to return to the Network Tools menu...'
}

network_tools_menu() {
    while true; do
        clear
        echo "🌐  Network Tools"
        echo "1) Run Network Pre-Scan"
        echo "2) Run All Network Fixes (Flush DNS & Renew DHCP)"
        echo "3) Reset Wi-Fi Connection"
        echo "4) Test Network Speed"
        echo "5) Run Network Diagnostics (Ping, Traceroute, DNS)"
        echo "6) Check VPN Connection"
        echo "7) ⬅️  Back to Main Menu"
        echo ""
        read -p "Enter your choice (1-7): " net_choice
        case $net_choice in
            1) network_pre_scan ;;
            2) run_network ;;
            3) reset_wifi ;;
            4) network_speed_test ;;
            5) network_diagnostics ;;
            6) check_vpn_status ;;
            7) break ;;
            *) echo "❌ Invalid choice. Press Enter to try again."; read;;
        esac
        show_log_summary
        read -p $'\nPress Enter to return to the Network Tools menu...'
    done
}

system_maintenance_menu() {
    while true; do
        clear
        echo "🛠️  System Maintenance"
        echo "1) Clean System (Clear Cache & Restart UI)"
        echo "2) Reset Printing System"
        echo "3) Enable Firewall & Show Status"
        echo "4) Check for Software Updates"
        echo "5) Check Hardware Health (S.M.A.R.T. Status)"
        echo "6) ⬅️  Back to Main Menu"
        echo ""
        read -p "Enter your choice (1-6): " sys_choice
        case $sys_choice in
            1) run_clean ;;
            2) reset_printing ;;
            3) firewall_status ;;
            4) software_update_check ;;
            5) hardware_health_check ;;
            6) break ;;
            *) echo "❌ Invalid choice. Press Enter to try again."; read;;
        esac
        echo -e "\n✅ Logs have been saved to $LOGFILE"
        show_log_summary
        read -p $'\nPress Enter to return to the System Maintenance menu...'
    done
}

reports_utilities_menu() {
    while true; do
        clear
        echo "📝  Reports & Utilities"
        echo "1) Run All Fixes"
        echo "2) Check for Updates"
        echo "3) ⬅️  Back to Main Menu"
        echo ""
        read -p "Enter your choice (1-3): " rep_choice
        case $rep_choice in
            1) run_all ;;
            2) check_for_update ;;
            3) break ;;
            *) echo "❌ Invalid choice. Press Enter to try again."; read;;
        esac
        show_log_summary
        read -p $'\nPress Enter to return to the Reports & Utilities menu...'
    done
}

quick_system_scan() {
    clear
    echo "🚦  Quick System Scan / Pre-Check"
    local issues=0
    local suggestions=()
    echo

    # Internet connectivity
    if ping -c 2 1.1.1.1 &>/dev/null; then
        echo -e "${GREEN}✅ Internet connectivity: OK${NC}"
        log SUCCESS "Internet connectivity: OK"
    else
        echo -e "${RED}❌ No internet connectivity${NC}"
        log ERROR "No internet connectivity"
        add_recommendation "Run Network Fixes (Flush DNS & Renew DHCP)"
        issues=1
    fi

    # VPN status
    local vpn_active=0
    if ifconfig | grep -q 'utun'; then vpn_active=1; fi
    if scutil --nc list 2>/dev/null | grep -q 'Connected'; then vpn_active=1; fi
    if [[ $vpn_active -eq 1 ]]; then
        echo -e "${GREEN}✅ VPN: Active${NC}"
        log SUCCESS "VPN: Active"
    else
        echo -e "${YELLOW}⚠️  VPN: Inactive${NC}"
        log WARNING "VPN: Inactive"
        add_recommendation "Check VPN Connection"
    fi

    # Firewall status
    local fw_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)
    if [[ "$fw_status" == *"enabled"* ]]; then
        echo -e "${GREEN}✅ Firewall: Enabled${NC}"
        log SUCCESS "Firewall: Enabled"
    else
        echo -e "${YELLOW}⚠️  Firewall: Disabled${NC}"
        log WARNING "Firewall: Disabled"
        add_recommendation "Enable Firewall & Show Status"
    fi

    # Disk space
    local disk_free=$(df -H / | awk 'NR==2 {print $4}')
    local disk_perc=$(df -H / | awk 'NR==2 {print $5}')
    if df -H / | awk 'NR==2 {exit ($5+0 < 90) ? 0 : 1}'; then
        echo -e "${GREEN}✅ Disk space: $disk_free free ($disk_perc used)${NC}"
        log SUCCESS "Disk space: $disk_free free ($disk_perc used)"
    else
        echo -e "${RED}❌ Low disk space: $disk_free free ($disk_perc used)${NC}"
        log ERROR "Low disk space: $disk_free free ($disk_perc used)"
        add_recommendation "Clean System (Clear Cache & Restart UI)"
        issues=1
    fi

    # Memory usage
    local mem_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    if [[ $mem_free -lt 50000 ]]; then
        echo -e "${YELLOW}⚠️  Low free memory detected${NC}"
        log WARNING "Low free memory detected"
        add_recommendation "Clean System (Clear Cache & Restart UI)"
    else
        echo -e "${GREEN}✅ Memory: OK${NC}"
        log SUCCESS "Memory: OK"
    fi

    # Pending updates
    if softwareupdate -l 2>&1 | grep -q '\*'; then
        echo -e "${YELLOW}⚠️  Pending software updates${NC}"
        log WARNING "Pending software updates"
        add_recommendation "Check for Software Updates"
    else
        echo -e "${GREEN}✅ No pending software updates${NC}"
        log SUCCESS "No pending software updates"
    fi

    # Printer status
    if lpstat -p 2>/dev/null | grep -q 'disabled'; then
        echo -e "${YELLOW}⚠️  Printer(s) disabled${NC}"
        log WARNING "Printer(s) disabled"
        add_recommendation "Reset Printing System"
    else
        echo -e "${GREEN}✅ Printer(s): OK${NC}"
        log SUCCESS "Printer(s): OK"
    fi

    echo
    if (( ${#LOG_RECOMMENDATIONS[@]} > 0 )); then
        echo -e "${BLUE}Recommended actions:${NC}"
        for r in "${LOG_RECOMMENDATIONS[@]}"; do
            echo -e "  - $r"
        done
    else
        echo -e "${GREEN}No issues detected. Your system looks good!${NC}"
    fi
    echo
    log INFO "Quick System Scan completed."
    read -p $'Press Enter to return to the main menu...'
}

main_menu
