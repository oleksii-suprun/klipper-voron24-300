# CB1 NetworkManager Setup Guide

Complete guide to switch from systemd-networkd to NetworkManager on BigTreeTech CB1 boards.

## Prerequisites

- CB1 board with Armbian
- Root/sudo access
- WiFi network credentials

## Part 1: Install and Enable NetworkManager

```bash
# Update package list and install NetworkManager
sudo apt update
sudo apt install -y network-manager

# Enable and start NetworkManager
sudo systemctl enable --now NetworkManager.service

# Verify installation
sudo systemctl status NetworkManager
```

## Part 2: Stop and Disable Conflicting Services

```bash
# Stop all conflicting network services
sudo systemctl stop systemd-networkd systemd-networkd-wait-online wpa_supplicant netplan-wpa-wlan0

# Disable conflicting services
sudo systemctl disable systemd-networkd systemd-networkd-wait-online wpa_supplicant

# Mask systemd-networkd services to prevent reactivation
sudo systemctl mask systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service
```

## Part 3: Clean Up Configuration Files

```bash
# Check if /etc/network/interfaces exists and disable WiFi if present
if [ -f /etc/network/interfaces ]; then
    sudo sed -i 's/^\(auto\|allow-hotplug\)\s*wlan[0-9].*$/# disabled by NetworkManager/g' /etc/network/interfaces
    sudo sed -i 's/^\s*iface\s*wlan[0-9].*$/# disabled by NetworkManager/g' /etc/network/interfaces
fi

# Remove systemd-networkd configuration files
sudo rm -f /etc/systemd/network/*.network /etc/systemd/network/*.netdev

# Remove wpa_supplicant configs
sudo rm -f /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

# Clean up wait-online service dependencies
sudo rm -f /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
sudo rm -f /lib/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service

# Clean up netplan generated systemd-networkd files
sudo rm -f /run/systemd/network/10-netplan-*.network
```

## Part 4: Fix Boot Delays

```bash
# Create override directory
sudo mkdir -p /etc/systemd/system/network-online.target.d

# Create override configuration
sudo tee /etc/systemd/system/network-online.target.d/override.conf >/dev/null <<'EOF'
[Unit]
Wants=NetworkManager-wait-online.service
After=NetworkManager-wait-online.service
EOF

# Reload systemd configuration
sudo systemctl daemon-reload
```

## Part 5: CB1-Specific WiFi Optimizations

```bash
# Add CB1 RTL8189FS WiFi stability fixes
echo 'options 8189fs rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0' | sudo tee /etc/modprobe.d/8189fs.conf

# Create NetworkManager dispatcher script directory
sudo mkdir -p /etc/NetworkManager/dispatcher.d

# Create WiFi power management script
sudo tee /etc/NetworkManager/dispatcher.d/99-wifi-powersave >/dev/null <<'EOF'
#!/bin/bash
# Disable WiFi power save when interface comes up
if [ "$1" = "wlan0" ] && [ "$2" = "up" ]; then
    sleep 2
    iw wlan0 set power_save off 2>/dev/null || true
fi
EOF

# Make script executable
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-wifi-powersave
```

## Part 6: Configure WiFi Connection

```bash
# Get WiFi interface name
ip -o link | awk -F': ' '/wl/{print $2; exit}'

# Enable WiFi radio and scan
sudo nmcli radio wifi on
sudo nmcli dev wifi rescan

# Wait for scan to complete
sleep 3

# List available networks
nmcli dev wifi list

# Add WiFi connection (replace YOUR_SSID and YOUR_PASSWORD)
sudo nmcli con add type wifi ifname wlan0 con-name "home" ssid "YOUR_SSID"
sudo nmcli con modify home wifi-sec.key-mgmt wpa-psk wifi-sec.psk "YOUR_PASSWORD"
sudo nmcli con modify home connection.autoconnect yes

# Set WiFi regulatory domain for Canada (change country code as needed)
sudo iw reg set CA

# Connect to WiFi
sudo nmcli con up home
```

## Part 7: Remove Netplan (Recommended)

Since NetworkManager handles all network configuration, netplan is no longer needed and will cause errors:

```bash
# Option 1: Remove netplan completely (recommended)
sudo apt remove --purge netplan.io

# Option 2: Keep netplan but disable all its configurations
sudo rm -f /etc/netplan/*.yaml
sudo systemctl disable netplan-wpa-* 2>/dev/null || true

# Verify NetworkManager is handling everything
nmcli device status
nmcli connection show --active
```

## Part 8: Clean Up Failed Services (Optional)

```bash
# Reset any failed systemd-networkd states (cosmetic cleanup)
sudo systemctl reset-failed systemd-networkd.service 2>/dev/null || true

# Optionally disable console-setup service if it fails on headless systems
sudo systemctl disable console-setup.service 2>/dev/null || true
sudo systemctl reset-failed console-setup.service 2>/dev/null || true

# Reload systemd daemon
sudo systemctl daemon-reload
```

## Part 9: Verification Commands

```bash
# Check NetworkManager status
sudo systemctl status NetworkManager

# Check network connections
nmcli device status
nmcli connection show --active

# Check WiFi signal and connection info
iw dev wlan0 link
iw dev wlan0 info

# Check regulatory domain
iw reg get

# Test connectivity
ping -c 4 8.8.8.8

# Check for any remaining failed services
systemctl list-units --failed
```

## Part 10: Reboot and Final Testing

```bash
# Reboot system
sudo reboot
```

**After reboot, verify:**

```bash
# Check NetworkManager is managing WiFi
nmcli device status

# Check active connections
nmcli connection show --active

# Test internet connectivity
ping -c 4 google.com

# Check boot performance
systemd-analyze blame | head -10

# Verify no failed network services
systemctl list-units --failed | grep -E "(networkd|wpa_supplicant)"
```

## Troubleshooting Commands

### Check WiFi Hardware
```bash
# Check WiFi interface exists
ip link show wlan0

# Check WiFi driver
lsmod | grep 8189

# Check hardware detection
lsusb | grep -i realtek
```

### WiFi Connection Issues
```bash
# Rescan networks
sudo nmcli dev wifi rescan

# Check available networks
nmcli dev wifi list

# Restart NetworkManager
sudo systemctl restart NetworkManager

# Check logs
journalctl -u NetworkManager -f
```

### WiFi Signal and Status (Modern Commands)
```bash
# Check WiFi connection status and signal strength
iw dev wlan0 link

# Check WiFi interface info
iw dev wlan0 info

# Check signal strength via NetworkManager
nmcli dev wifi list --rescan no

# Show detailed connection info
nmcli connection show home

# Install wireless-tools for iwconfig if preferred
sudo apt install wireless-tools
```

### WiFi Regulatory Domain
```bash
# Check current regulatory domain
iw reg get

# Set regulatory domain (replace with your country code)
sudo iw reg set CA

# Verify regulatory settings
iw dev wlan0 info | grep country

# Check available channels
iw list | grep -A15 "Frequencies"

# Common country codes: US, CA, GB, DE, FR, AU, JP
```

### Reset WiFi Connection
```bash
# Delete existing connection
sudo nmcli con delete home

# Re-add connection
sudo nmcli con add type wifi ifname wlan0 con-name "home" ssid "YOUR_SSID"
sudo nmcli con modify home wifi-sec.key-mgmt wpa-psk wifi-sec.psk "YOUR_PASSWORD"
sudo nmcli con modify home connection.autoconnect yes
sudo nmcli con up home
```

### Service Status Debugging
```bash
# Check what services are masked (should include systemd-networkd)
systemctl list-unit-files | grep masked

# Verify NetworkManager is active
systemctl is-active NetworkManager.service

# Check systemd-networkd is properly masked
systemctl is-masked systemd-networkd.service

# View recent NetworkManager logs
journalctl -u NetworkManager -n 20
```

## Performance Optimization (Optional)

```bash
# Install entropy tools for better performance
sudo apt install -y rng-tools

# Check boot timing
systemd-analyze
systemd-analyze critical-chain

# Check which services take the longest to start
systemd-analyze blame | head -10
```

## Key Benefits

- **Faster boot times** - No more 40+ second wait delays
- **Reliable WiFi** - Better reconnection handling with CB1 optimizations
- **Simplified management** - Single service for all networking
- **CB1 optimized** - Specific fixes for RTL8189FS WiFi chip
- **Auto-reconnect** - WiFi automatically reconnects after reboot
- **Clean service state** - No conflicting network services

## Important Notes

- Replace `YOUR_SSID` and `YOUR_PASSWORD` with actual WiFi credentials
- The `home` connection name can be customized
- All systemd-networkd services are disabled and masked (this is intentional)
- WiFi power saving is disabled for stability on CB1
- Regulatory domain is set to CA (Canada) - change `iw reg set XX` for your country
- Use modern `iw` and `nmcli` commands instead of deprecated `iwconfig`
- Failed `console-setup.service` is normal and harmless on headless systems
- Netplan removal prevents configuration conflicts

## Expected System State After Setup

**Active Services:**
- ✅ NetworkManager.service (active)
- ✅ NetworkManager-wait-online.service (active)

**Masked Services (Intentional):**
- 🚫 systemd-networkd.service (masked)
- 🚫 systemd-networkd.socket (masked) 
- 🚫 systemd-networkd-wait-online.service (masked)

**Common Harmless Failures:**
- ⚠️ console-setup.service (normal on headless systems)

## Verification Checklist

- [ ] NetworkManager service is active
- [ ] WiFi interface shows as managed by NetworkManager
- [ ] Internet connectivity works
- [ ] WiFi auto-connects after reboot
- [ ] systemd-networkd services are masked (not failed)
- [ ] Boot time is improved (no 40s delays)
- [ ] Regulatory domain is set correctly
- [ ] No netplan configuration conflicts
- [ ] Only harmless console-setup failure (if any)

---

*Guide tested on BigTreeTech CB1 with Armbian and RTL8189FS WiFi chip*