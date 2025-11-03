# CAN0 Interface Setup Guide for BTT Manta M8P + CM4

Complete guide to configure CAN communication on Raspberry Pi CM4 boards with Manta M8P controller boards and CAN-enabled toolhead boards (like EBB SB2209).

## Hardware Setup Required

1. **BTT Manta M8P controller board**
2. **Raspberry Pi CM4 core board** (installed on Manta M8P)
3. **CAN-enabled toolhead board** (like EBB SB2209)
4. **CAN wiring** between boards (twisted pair cable, CAN H and CAN L)
5. **120Ω termination resistors** at both ends of CAN bus

## Software Prerequisites

Before following this guide, ensure you have:

- CM4 running with SSH access
- Manta M8P flashed with Klipper firmware in "USB to CAN bus bridge" mode
- Network connectivity configured (WiFi/Ethernet)
- Root/sudo access on CM4
- CAN toolhead boards flashed with appropriate Klipper firmware

## System Overview

This setup creates a CAN network where:
- **CM4**: Runs Klipper host software and configures CAN interface
- **Manta M8P**: Acts as USB-to-CAN bridge (runs Klipper firmware)
- **Toolhead boards**: Run Klipper firmware and communicate via CAN

## Step 1: Test CAN Interface Manually

First, verify that CAN hardware is working:

```bash
# Check if can0 interface exists
ip link show can0

# Configure CAN interface manually (temporary)
sudo ip link set can0 down
sudo ip link set can0 type can bitrate 1000000 sample-point 0.875
sudo ip link set can0 up
sudo ip link set can0 txqueuelen 1024

# Verify CAN is working
ip link show can0
```

**Expected output:**
```
6: can0: <NOARP,UP,LOWER_UP,ECHO> mtu 16 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1024
    link/can
```

Key indicators:
- `UP,LOWER_UP` = Interface is active
- `ECHO` = CAN echo is working
- `state UP` = Interface is operational
- **`qlen 1024`** = Proper queue length (prevents "Timer too close" errors)

## Step 2: Test CAN Device Detection

Test if your CAN devices are detected:

```bash
# Query CAN devices (requires Klipper flashed devices)
~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
```

**Expected output:**
```
Found canbus_uuid=8c2968dbfb37, Application: Klipper
Found canbus_uuid=c036ca33da25, Application: Klipper
Total 2 uuids found
```

If devices are detected, your hardware setup is correct.

## Step 3: Configure Automatic CAN Management

Create the configuration that will automatically manage your CAN interface.

### Create udev rule for automatic CAN detection:

```bash
sudo nano /etc/udev/rules.d/80-can-ifup.rules
```

Add this content:
```
ACTION=="add", SUBSYSTEM=="net", KERNEL=="can*", ENV{SYSTEMD_WANTS}+="can-ifup@%k.service"
```

### Create systemd service for CAN configuration:

```bash
sudo nano /etc/systemd/system/can-ifup@.service
```

Add this content:
```ini
[Unit]
Description=Configure CAN interface %i on appearance
BindsTo=sys-subsystem-net-devices-%i.device
After=sys-subsystem-net-devices-%i.device systemd-modules-load.service
Wants=systemd-modules-load.service
Before=klipper.service

[Service]
Type=oneshot
ExecStart=-ip link set dev %i down
ExecStart=ip link set dev %i type can bitrate 1000000 sample-point 0.875
ExecStart=ip link set dev %i up
ExecStart=ip link set dev %i txqueuelen 1024
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

### Apply the configuration:

```bash
sudo udevadm control --reload-rules
sudo systemctl daemon-reload
```

## Step 4: Test and Verify Configuration

### Start the CAN service manually to test:

```bash
sudo systemctl start can-ifup@can0.service
```

### Check service status:

```bash
systemctl status can-ifup@can0.service
```

**Expected output:**
```
● can-ifup@can0.service - Configure CAN interface can0 on appearance
     Loaded: loaded (/etc/systemd/system/can-ifup@.service; disabled; preset: enabled)
     Active: active (exited) since [timestamp]
    Process: [PID] ExecStart=ip link set dev can0 down (code=exited, status=0/SUCCESS)
    Process: [PID] ExecStart=ip link set dev can0 type can bitrate 1000000 sample-point 0.875 (code=exited, status=0/SUCCESS)
    Process: [PID] ExecStart=ip link set dev can0 up (code=exited, status=0/SUCCESS)
    Process: [PID] ExecStart=ip link set dev can0 txqueuelen 1024 (code=exited, status=0/SUCCESS)
   Main PID: [PID] (code=exited, status=0/SUCCESS)
```

### Verify CAN interface is configured correctly:

```bash
ip link show can0
```

**Expected output:**
```
6: can0: <NOARP,UP,LOWER_UP,ECHO> mtu 16 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1024
    link/can
```

Key indicators:
- `state UP` = Interface is active
- `qlen 1024` = Proper queue length (prevents communication errors)

### Test CAN device detection:

```bash
~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
```

**Expected output:**
```
Found canbus_uuid=[your-manta-uuid], Application: Klipper
Found canbus_uuid=[your-toolhead-uuid], Application: Klipper
Total 2 uuids found
```

Save these UUIDs - you'll need them for your Klipper configuration.

## Step 5: Configure Klipper for CAN Communication

Add the CAN device configurations to your `printer.cfg`:

```ini
# Main controller board (Manta M8P) via CAN
[mcu]
canbus_uuid: [your-manta-uuid-from-step-4]

# Toolhead board (EBB SB2209) via CAN  
[mcu EBBCan]
canbus_uuid: [your-toolhead-uuid-from-step-4]
```

Replace `[your-manta-uuid-from-step-4]` and `[your-toolhead-uuid-from-step-4]` with the actual UUIDs you obtained in Step 4.

## Step 6: Test Complete System

### Restart Klipper to test CAN communication:

```bash
sudo systemctl restart klipper
```

### Check Klipper status:

```bash
sudo systemctl status klipper
```

Klipper should start successfully and connect to both CAN devices.

### Test firmware restart functionality:

1. **Open your printer web interface** (Mainsail/Fluidd)
2. **Click "Firmware Restart"**
3. **Wait 10-15 seconds**
4. **Verify printer is ready** - both MCUs should reconnect automatically

The CAN interface will automatically reconfigure itself after firmware restarts.

## Configuration Complete

Your CAN0 interface is now properly configured for:
- Automatic setup on boot
- Automatic recovery after firmware restarts
- Stable communication with all CAN devices
- Optimal performance for 3D printing operations

## Troubleshooting Common Issues

### CAN interface shows "state DOWN"
Check if the automatic service is working:
```bash
systemctl status can-ifup@can0.service
```
If failed, check logs:
```bash
journalctl -u can-ifup@can0.service
```

### No CAN devices detected
Verify hardware connections:
- CAN H and CAN L wiring is correct
- 120Ω termination resistors installed at both ends of CAN bus
- All devices are powered on
- Devices are flashed with correct Klipper firmware

Check CAN interface is UP:
```bash
ip link show can0
```

### Klipper fails to connect after firmware restart
Monitor the automatic CAN recovery:
```bash
journalctl -f -u 'can-ifup@*.service'
```
Then do a firmware restart - you should see the service start automatically.

### "Timer too close" errors during printing
Verify queue length is set correctly:
```bash
ip link show can0 | grep qlen
```
Should show `qlen 1024`, not `qlen 10`.

## CAN Bus Configuration Options

### Different bitrate (if needed):
Edit the service file:
```bash
sudo nano /etc/systemd/system/can-ifup@.service
```
Change this line:
```ini
ExecStart=ip link set dev %i type can bitrate 500000 sample-point 0.875
```

### Custom sample point (for specific hardware):
```ini
ExecStart=ip link set dev %i type can bitrate 1000000 sample-point 0.800
```

After changes, reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart can-ifup@can0.service
```

---

**Guide tested on: BigTreeTech Manta M8P v2.0 with Raspberry Pi CM4 and EBB SB2209 CAN boards**

*This configuration provides reliable CAN communication that automatically handles system restarts and firmware restarts.*
