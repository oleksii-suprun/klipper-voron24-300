# BTT Manta M8P V2.0 CAN Configuration Guide

Complete guide to configure BigTreeTech Manta M8P V2.0 as a CAN bridge and flash EBB toolhead boards for CAN communication.

## Prerequisites

- BTT Manta M8P V2.0 with CB1 or CM4
- SSH access to CB1/CM4
- EBB SB2209 CAN or similar toolhead board
- CAN cable with proper wiring
- USB cable for initial flashing

## Important Setup Notes

- This guide is **specifically for Manta M8P V2.0** only
- Ensure you have the CAN0 interface configured (see CAN0 setup guide)
- All devices must use the same CAN bitrate (1000000 recommended)
- **CRITICAL**: Start with EBB toolhead board **DISCONNECTED**

## Overview

The CAN configuration process involves two main stages, each following an identical workflow to minimize errors:

### What We're Building
1. **Manta M8P as CAN Bridge** - Acts as USB-to-CAN converter between CB1 and CAN bus
2. **EBB Toolhead on CAN** - Communicates wirelessly over CAN bus for reduced wiring

### The Process
Each stage follows the same 12-phase workflow:

**Stage 1: Manta M8P V2.0**
1. **Flash Katapult bootloader** - Enables future CAN-based firmware updates
2. **Flash Klipper firmware** - Main firmware configured as USB-to-CAN bridge
3. **Verify CAN bridge operation** - Manta M8P appears as CAN adapter

**Stage 2: EBB Toolhead Board**  
1. **Flash Katapult bootloader** - Same process as Manta M8P
2. **Flash Klipper firmware** - Main firmware configured for CAN communication
3. **Switch to CAN communication** - Remove USB, connect CAN cable

### End Result
- **CB1** ↔ **USB** ↔ **Manta M8P** ↔ **CAN Bus** ↔ **EBB Toolhead**
- Both devices accessible via CAN for operation and future updates
- Simplified wiring with robust communication protocol

## Hardware Preparation

### Initial Hardware State
- [ ] EBB board unplugged from everything
- [ ] Only Manta M8P V2.0 powered on
- [ ] SSH connection to CB1/CM4 established
- [ ] CAN0 interface verified working

## Stage 1: Manta M8P V2.0 Configuration

### Phase 1: Clone and Setup Repositories

```bash
# Navigate to home directory
cd ~

# Clone Katapult (formerly CanBoot)
git clone https://github.com/Arksine/katapult.git
```

### Phase 2: Configure and Build Katapult

```bash
# Enter Katapult directory
cd ~/katapult/

# Open configuration menu
make menuconfig
```

**Katapult Configuration for Manta M8P V2.0:**
```
[*] Enable extra low-level configuration options
Micro-controller Architecture (STMicroelectronics STM32) --->
Processor model (STM32H723) --->
Build Katapult deployment application (Do not build) --->
Clock Reference (25 MHz crystal) --->
Communication interface (CAN bus (on PD0/PD1)) --->
Application start offset (128KiB offset) --->
(1000000) CAN bus speed
() GPIO pins to set at micro-controller startup
[*] Support bootloader entry on rapid double click of reset button
[ ] Enable bootloader entry on button (or gpio) state
[ ] Enable Status LED
```

Press `q` → `Yes` to save and exit.

```bash
# Build Katapult
make clean
make
```

### Phase 3: Configure and Build Klipper

```bash
# Enter Klipper directory
cd ~/klipper/

# Open configuration menu
make menuconfig
```

**Klipper Configuration for Manta M8P V2.0:**
```
[*] Enable extra low-level configuration options
Micro-controller Architecture (STMicroelectronics STM32) --->
Processor model (STM32H723) --->
Bootloader offset (128KiB bootloader) --->
Clock Reference (25 MHz crystal) --->
Communication interface (USB to CAN bus bridge (USB on PA11/PA12)) --->
CAN bus interface (CAN bus (on PD0/PD1)) --->
(1000000) CAN bus speed
() GPIO pins to set at micro-controller startup
```

Press `q` → `Yes` to save and exit.

```bash
# Build Klipper
make clean
make
```

### Phase 4: Hardware Preparation

1. **Install CAN termination resistor jumper** on Manta M8P V2.0
2. **Locate BOOT0 and RESET buttons** on Manta M8P

### Phase 5: Enter DFU Mode

**DFU Mode Entry Process:**
1. **Hold** BOOT0 button
2. **Press and release** RESET button (while holding BOOT0)
3. **Release** BOOT0 button

### Phase 6: Verify DFU Mode

```bash
# Check for DFU device
lsusb | grep -i dfu
```

**Expected result:**
```
Bus 001 Device XXX: ID 0483:df11 STMicroelectronics STM Device in DFU Mode
```

❌ **If not found:** Repeat DFU mode entry process

### Phase 7: Flash Katapult

```bash
# Flash Katapult bootloader
sudo dfu-util -a 0 -D ~/katapult/out/katapult.bin --dfuse-address 0x08000000:force:leave -d 0483:df11
```

⚠️ **Expected:** Error message at end is normal

### Phase 8: Re-enter DFU Mode

**Repeat DFU Mode Entry:**
1. **Press** RESET button
2. **Hold** BOOT0 button
3. **Press and release** RESET button (while holding BOOT0)
4. **Release** BOOT0 button

### Phase 9: Flash Klipper

```bash
# Flash Klipper firmware (V2.0 specific address)
sudo dfu-util -a 0 -d 0483:df11 --dfuse-address 0x08020000 -D ~/klipper/out/klipper.bin
```

### Phase 10: Verify Manta M8P Success

```bash
# Reset board (press RESET button once)

# Check for CAN adapter
lsusb | grep -i can
```

**Expected result:**
```
Bus 001 Device XXX: ID 1d50:606f OpenMoko, Inc. Geschwister Schneider CAN adapter
```

### Phase 11: Test CAN Communication

```bash
# Query CAN devices
python3 ~/katapult/scripts/flash_can.py -i can0 -q
```

**Expected result:**
```
Resetting all bootloader node IDs...
Checking for Katapult nodes...
Detected UUID: xxxxxxxxxxxxxxx, Application: Klipper
Query Complete
```

📝 **Record this UUID** - you'll need it for printer configuration

---

## Stage 2: EBB Toolhead Board Configuration

### Phase 1: Hardware Preparation

**Setup EBB board:**
1. **Connect** USB cable from Manta M8P to EBB board USB-C port
2. **Install** USB_5V jumper on EBB board
3. **Install** 120Ω termination resistor jumper on EBB board
4. **DO NOT** connect CAN cable yet

### Phase 2: Configure and Build Katapult

```bash
# Enter Katapult directory
cd ~/katapult/

# Open configuration menu
make menuconfig
```

**Katapult Configuration for EBB SB2209 (RP2040):**
```
[*] Enable extra low-level configuration options
Micro-controller Architecture (Raspberry Pi RP2040) --->
Build Katapult deployment application (Do not build) --->
Flash chip (GENERIC_03H with CLKDIV 4) --->
Communication interface (CAN bus) --->
(4) CAN RX gpio number
(5) CAN TX gpio number
(1000000) CAN bus speed
() GPIO pins to set at micro-controller startup
[*] Support bootloader entry on rapid double click of reset button
[ ] Enable bootloader entry on button (or gpio) state
[ ] Enable Status LED
```

Press `q` → `Yes` to save and exit.

```bash
# Build Katapult
make clean
make
```

### Phase 3: Configure and Build Klipper

```bash
# Enter Klipper directory
cd ~/klipper/

# Open configuration menu
make menuconfig
```

**Klipper Configuration for EBB SB2209:**
```
[*] Enable extra low-level configuration options
Micro-controller Architecture (Raspberry Pi RP2040) --->
Processor model (rp2040) --->
Bootloader offset (16KiB bootloader) --->
Flash chip (GENERIC_03H with CLKDIV 4) --->
Communication interface (CAN bus) --->
(4) CAN RX gpio number
(5) CAN TX gpio number
(1000000) CAN bus speed
() GPIO pins to set at micro-controller startup
```

Press `q` → `Yes` to save and exit.

```bash
# Build Klipper
make clean
make
```

### Phase 4: Hardware Preparation

1. **Locate BOOT and RESET buttons** on EBB board

### Phase 5: Enter DFU Mode

**DFU Mode Entry Process (same as Manta):**
1. **Hold** BOOT button on EBB
2. **Press and release** RESET button on EBB (while holding BOOT)
3. **Release** BOOT button

### Phase 6: Verify DFU Mode

```bash
# Check for EBB DFU device
lsusb | grep -i "2e8a:0003"
```

**Expected result:**
```
Bus 001 Device XXX: ID 2e8a:0003 Raspberry Pi RP2 Boot
```

❌ **If not found:** Repeat DFU mode entry process

### Phase 7: Flash Katapult

```bash
# Flash Katapult to EBB
make flash FLASH_DEVICE=2e8a:0003
```

### Phase 8: Re-enter DFU Mode

**Repeat DFU Mode Entry (same process):**
1. **Hold** BOOT button on EBB
2. **Press and release** RESET button on EBB (while holding BOOT)
3. **Release** BOOT button

### Phase 9: Flash Klipper

```bash
# Flash Klipper to EBB
make flash FLASH_DEVICE=2e8a:0003
```

### Phase 10: Verify EBB Success

```bash
# No USB verification needed for EBB - proceed to Phase 11
```

### Phase 11: Switch to CAN Communication

**Hardware Changes:**
1. **Remove** USB cable between Manta M8P and EBB
2. **Remove** USB_5V jumper from EBB board
3. **Connect** CAN cable (CAN_H and CAN_L only, leave power wires disconnected)
4. **Keep** 120Ω termination jumper on EBB board

### Phase 12: Test CAN Communication

```bash
# Query all CAN devices
python3 ~/katapult/scripts/flash_can.py -i can0 -q
```

**Expected result:**
```
Resetting all bootloader node IDs...
Checking for Katapult nodes...
Detected UUID: xxxxxxxxxxxxxxx, Application: Klipper  # Manta M8P
Detected UUID: yyyyyyyyyyyyyyy, Application: Klipper  # EBB board
Query Complete
```

📝 **Record both UUIDs** - you'll need them for printer configuration

---

## Final Configuration

### Printer Configuration

Add to your `printer.cfg`:

```ini
# Manta M8P (main controller)
[mcu]
canbus_uuid: xxxxxxxxxxxxxxx  # Your Manta M8P UUID
canbus_interface: can0

# EBB toolhead board
[mcu EBBCan]
canbus_uuid: yyyyyyyyyyyyyyy  # Your EBB UUID
canbus_interface: can0
```

## Success Verification Checklist

- [ ] Manta M8P shows as CAN adapter in `lsusb`
- [ ] Both devices detected in CAN query
- [ ] UUIDs recorded for printer configuration
- [ ] CAN cable properly connected (no power wires)
- [ ] Termination resistors installed on both boards

## Troubleshooting

### DFU Mode Not Working
- **Power**: Use wall adapter, not PC USB port
- **Cables**: Try different USB cables
- **Timing**: Hold BOOT before pressing RESET
- **Power cycle**: Disconnect and reconnect power

### CAN Communication Failed
- **Interface**: Verify `ip link show can0` shows UP state
- **Termination**: Check 120Ω resistors on both ends
- **Wiring**: Verify CAN_H to CAN_H, CAN_L to CAN_L
- **Bitrate**: Ensure all devices use same speed (1000000)

### Compilation Errors
- **Update sources**: `git pull` in both klipper and katapult directories
- **Clean build**: Always run `make clean` before `make`
- **Settings**: Double-check processor model and pins

### No Devices Detected
- **Hardware**: Check all connections and jumpers
- **Power**: Ensure EBB board is properly powered via CAN or external source
- **Reset**: Try power cycling both boards

## Future Firmware Updates

**Manta M8P**: Requires DFU mode entry and USB flashing (repeat Stage 1)

**EBB boards**: Can be updated via CAN:
```bash
python3 ~/katapult/scripts/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u <EBB_UUID>
```

---

**Critical Reminder:** This guide is specifically for Manta M8P V2.0. Do not use these settings for other versions.

*Last updated: August 2025*