# Archived CAN0 Interface Setup Guide

This guide is retained as historical reference for the previous Manta M8P USB-to-CAN bridge and EBB SB2209 CAN toolhead setup.

It is **not** part of the current printer configuration.

## Current Repository Hardware

The current printer uses:

- **Mainboard:** BigTreeTech Manta M8P V2.0 connected to Klipper by USB serial
- **Toolhead:** LDO Nitehawk-SB connected to Klipper by USB serial
- **Active toolhead config:** `nitehawk-sb.cfg`
- **Not used anymore:** BigTreeTech EBB SB2209 CAN

Do **not** configure `can0`, install CAN systemd services, or convert the Manta to USB-to-CAN bridge mode for the current Nitehawk-SB USB setup.

Expected current MCU shape:

```ini
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32h723xx_...

[mcu nhk]
serial: /dev/serial/by-id/usb-Klipper_rp2040_...
restart_method: command
```

## When This Guide Applies

Use the archived procedure below only if you intentionally restore a CAN topology, for example:

- Manta M8P V2.0 flashed as a USB-to-CAN bridge
- EBB SB2209 or another CAN toolhead board
- CAN wiring and termination installed
- All CAN devices flashed with matching CAN bitrate

## Archived Hardware Setup Required

1. BTT Manta M8P controller board
2. Raspberry Pi CM4 core board installed on Manta M8P
3. CAN-enabled toolhead board such as EBB SB2209
4. CAN twisted pair wiring between boards
5. 120 ohm termination resistors at both ends of the CAN bus

## Archived Software Prerequisites

Before following this archived CAN procedure, ensure you have:

- CM4 running with SSH access
- Manta M8P flashed with Klipper firmware in USB-to-CAN bridge mode
- Network connectivity configured
- Root/sudo access on CM4
- CAN toolhead boards flashed with appropriate Klipper firmware

## Archived System Overview

The old setup created a CAN network where:

- **CM4:** Runs Klipper host software and configures CAN interface
- **Manta M8P:** Acts as USB-to-CAN bridge
- **Toolhead board:** Runs Klipper firmware and communicates over CAN

## Step 1: Test CAN Interface Manually

Verify that CAN hardware is working:

```bash
ip link show can0

sudo ip link set can0 down
sudo ip link set can0 type can bitrate 1000000 sample-point 0.875
sudo ip link set can0 up
sudo ip link set can0 txqueuelen 1024

ip link show can0
```

Expected output:

```text
6: can0: <NOARP,UP,LOWER_UP,ECHO> mtu 16 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1024
    link/can
```

Key indicators:

- `UP,LOWER_UP` means the interface is active
- `ECHO` means CAN echo is working
- `state UP` means the interface is operational
- `qlen 1024` gives a larger queue for stable Klipper CAN communication

## Step 2: Test CAN Device Detection

```bash
~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
```

Expected old-CAN output:

```text
Found canbus_uuid=<manta_uuid>, Application: Klipper
Found canbus_uuid=<toolhead_uuid>, Application: Klipper
Total 2 uuids found
```

## Step 3: Configure Automatic CAN Management

Create a udev rule:

```bash
sudo nano /etc/udev/rules.d/80-can-ifup.rules
```

Content:

```text
ACTION=="add", SUBSYSTEM=="net", KERNEL=="can*", ENV{SYSTEMD_WANTS}+="can-ifup@%k.service"
```

Create the systemd service:

```bash
sudo nano /etc/systemd/system/can-ifup@.service
```

Content:

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

Apply:

```bash
sudo udevadm control --reload-rules
sudo systemctl daemon-reload
sudo systemctl start can-ifup@can0.service
```

## Step 4: Archived Klipper CAN Configuration

Only use this if restoring CAN hardware:

```ini
[mcu]
canbus_uuid: <manta_uuid>

[mcu EBBCan]
canbus_uuid: <toolhead_uuid>
```

This is **not** valid for the current Nitehawk-SB USB setup.

## Troubleshooting Old CAN Setup

### CAN interface shows `state DOWN`

```bash
systemctl status can-ifup@can0.service
journalctl -u can-ifup@can0.service
```

### No CAN devices detected

Check:

- CAN H and CAN L wiring
- 120 ohm termination at both ends
- Board power
- Matching bitrate across all CAN devices
- Correct Klipper firmware communication mode

### Timer too close errors

Verify queue length:

```bash
ip link show can0 | grep qlen
```

Expected:

```text
qlen 1024
```

---

**Archived guide tested on:** BigTreeTech Manta M8P V2.0 with Raspberry Pi CM4 and EBB SB2209 CAN boards.

**Current repository setup:** BigTreeTech Manta M8P V2.0 USB serial plus LDO Nitehawk-SB USB serial.
