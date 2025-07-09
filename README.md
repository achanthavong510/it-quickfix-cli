# IT QuickFix CLI (macOS)

## Quick Start (One-Liner)
Run the tool directly from GitHub (no install needed):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/quickfix.sh)
```

> Replace `YOUR-USERNAME/YOUR-REPO` with the actual GitHub repo path if you fork or clone this project.

---

A Bash-based command-line utility to automate and diagnose common macOS IT support and maintenance tasks, now with a modern, interactive terminal menu.

## Features
- **Clean, Sectioned Menus:** Main menu with submenus for Network Tools, System Maintenance, and Reports & Utilities.
- **Quick System Scan:** One-click scan for internet, VPN, firewall, disk, memory, updates, and printer status, with color-coded results and recommendations.
- **Network Pre-Scan:** Checks internet, gateway, DNS, VPN, and IP status before troubleshooting, and suggests the best fixes.
- **Network Tools:**
  - Run All Network Fixes (Flush DNS & Renew DHCP)
  - Reset Wi-Fi Connection
  - Test Network Speed
  - Run Network Diagnostics (Ping, Traceroute, DNS)
  - Check VPN Connection
- **System Maintenance:**
  - Clean System (Clear Cache & Restart UI)
  - Reset Printing System
  - Enable Firewall & Show Status
  - Check for Software Updates (macOS & App Store)
  - Check Hardware Health (S.M.A.R.T. Status)
- **Reports & Utilities:**
  - Run All Fixes
  - Check for Updates
- **Colorful, Actionable Output:** Color-coded summaries and recommendations after every action.
- **No Desktop Log Clutter:** All results are summarized in the terminal.

## Usage

### Main Menu
When you run:
```sh
./quickfix.sh
```
You’ll see a menu like this:

1. 🚦  Quick System Scan / Pre-Check
2. 🌐  Network Tools
3. 🛠️  System Maintenance
4. 📝  Reports & Utilities
5. ❌  Quit

### Network Tools Submenu
```
1) Run Network Pre-Scan
2) Run All Network Fixes (Flush DNS & Renew DHCP)
3) Reset Wi-Fi Connection
4) Test Network Speed
5) Run Network Diagnostics (Ping, Traceroute, DNS)
6) Check VPN Connection
7) ⬅️  Back to Main Menu
```

### Command-Line Arguments (Advanced)
You can still run specific actions directly:
```sh
./quickfix.sh <command>
```
Where `<command>` is one of:
- `all`      : Run all safe fixes
- `network`  : Flush DNS & renew DHCP lease
- `clean`    : Clear caches & restart UI
- `report`   : (deprecated)
- `help`     : Show help message

### Quick System Scan & Network Pre-Scan
- **Quick System Scan:** Checks your system’s health (internet, VPN, firewall, disk, memory, updates, printer) and recommends fixes.
- **Network Pre-Scan:** Checks your network health (internet, gateway, DNS, VPN, IP) and recommends the best network fixes.
- **All results and recommendations are shown in the terminal—no log files to hunt for!**

## Installation
1. Download or clone this repository.
2. Make the script executable:
   ```sh
   chmod +x quickfix.sh
   ```
3. (Optional) Move it to a directory in your PATH, e.g. `/usr/local/bin`.

## Optional: Double-Click Usability
To run the tool by double-clicking in Finder:
1. Duplicate `quickfix.sh` and rename it to `quickfix.command`.
2. Ensure it starts with `#!/bin/bash` and is executable:
   ```sh
   chmod +x quickfix.command
   ```
3. Double-click `quickfix.command` in Finder to launch in Terminal.

## Troubleshooting
- **Permission Denied:**
  - Make sure the script is executable: `chmod +x quickfix.sh`
  - Some actions require `sudo` and will prompt for your password.
- **Operation Not Permitted (cache clearing):**
  - Some system/user cache files are protected by macOS and cannot be deleted, even with `sudo`. These are safely ignored.
- **Missing tools:**
  - Some features require tools like `dig`, `traceroute`, or `mas`. Install them via Homebrew if missing.

## License
MIT License. See [LICENSE](LICENSE) for details. 