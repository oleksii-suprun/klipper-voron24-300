# Archived BTT Manta M8P V2.0 CAN / EBB Configuration Guide

This guide is retained as historical reference for the previous BigTreeTech EBB SB2209 CAN toolhead setup. It is **not** the active hardware configuration for this repository anymore.

## Current Repository Hardware

The current printer configuration uses:

- **Mainboard:** BigTreeTech Manta M8P V2.0 connected to Klipper by USB serial
- **Toolhead:** LDO Nitehawk-SB connected to Klipper by USB serial
- **Active toolhead config:** `nitehawk-sb.cfg` with `[mcu nhk]`
- **Not used anymore:** BigTreeTech EBB SB2209 CAN toolhead board

Do **not** follow this guide to configure the current printer unless you intentionally replace the Nitehawk-SB with a CAN toolhead and rebuild the printer around CAN communication again.

For the current setup, the relevant MCU sections are expected to look like:

```ini
# Manta M8P main controller over USB serial
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32h723xx_...

# LDO Nitehawk-SB toolboard over USB serial
[mcu nhk]
serial: /dev/serial/by-id/usb-Klipper_rp2040_...
restart_method: command
```

The CAN/EBB instructions below are archived for troubleshooting, rollback, or future hardware changes only.

## Archived Guide Scope

This archived procedure configures BigTreeTech Manta M8P V2.0 as a CAN bridge and flashes EBB toolhead boards for CAN communication.

## Archived Prerequisites

These prerequisites apply only if you intentionally restore the old CAN/EBB topology:

- BTT Manta M8P V2.0 with CB1 or CM4
- SSH access to CB1/CM4
- EBB SB2209 CAN or similar CAN toolhead board
- CAN cable with proper wiring
- USB cable for initial flashing

## Important Archived Setup Notes

- This guide is **specifically for Manta M8P V2.0** only
- This guide does **not** describe the current Nitehawk-SB USB configuration
- Ensure you have the CAN0 interface configured (see CAN0 setup guide) before restoring CAN hardware
- All CAN devices must use the same CAN bitrate (1000000 recommended)
- **CRITICAL**: Start with EBB toolhead board **DISCONNECTED**

## Archived Overview

The old CAN configuration process involved two main stages, each following an identical workflow to minimize errors:

### What This Archived Guide Builds
1. **Manta M8P as CAN Bridge** - Acts as USB-to-CAN converter between CB1 and CAN bus
2. **EBB Toolhead on CAN** - Communicates over CAN bus for reduced wiring

This is **not** what the active repository config currently uses.

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

## Archived Hardware Preparation

Only use this section if intentionally restoring the old EBB CAN hardware. For the current Nitehawk-SB USB setup, leave `nitehawk-sb.cfg` active and do not convert the Manta to USB-to-CAN bridge mode.

### Initial Hardware State
- EBB board unplugged from everything
- Only Manta M8P V2.0 powered on
- SSH connection to CB1/CM4 established
- CAN0 interface verified working

## Archived Stage 1: Manta M8P V2.0 CAN Bridge Configuration

### Phase 1: Get Katapult

Katapult is a bootloader that enables firmware updates over CAN bus. Without it, you'd need to
physically connect via USB and enter DFU mode for every firmware update. With Katapult, you can
update your EBB toolhead remotely over CAN.

Repository: https://github.com/Arksine/katapult

```bash
# Navigate to home directory
cd ~

# Clone Katapult (formerly CanBoot)
git clone https://github.com/Arksine/katapult.git
```

### Phase 2: Configure and Build Katapult

Configure the Katapult bootloader for the Manta M8P's STM32H723 processor. The 128KiB offset
reserves space at the beginning of flash memory for the bootloader, with the main Klipper
firmware installed after it.

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

Build the main Klipper firmware configured as a "USB to CAN bus bridge". This makes the Manta
M8P translate USB communication from the Raspberry Pi CM4 into CAN bus signals for connected
devices. The bootloader offset must match the Katapult configuration (128KiB).

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

Write the Katapult bootloader to the start of flash memory (address 0x08000000). This must be
installed first to reserve memory space for the bootloader.

**Note:** The device ID `0483:df11` should match the ID from `lsusb | grep -i dfu` in Phase 6.
Use your actual ID if different.

```bash
# Flash Katapult bootloader (use your device ID from Phase 6)
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

## Archived Stage 2: EBB Toolhead Board Configuration

Configure the EBB SB2209 to communicate over CAN bus. Unlike the Manta M8P (which acts as a
USB-to-CAN bridge), the EBB board will be a pure CAN device handling all toolhead functions
(extruder, hotend, fans, probe) with communication through the CAN bus instead of a thick
cable bundle.

### Phase 1: Hardware Preparation

**Setup EBB board:**
1. **Connect** USB cable from Manta M8P to EBB board USB-C port
2. **Install** USB_5V jumper on EBB board
3. **Install** 120Ω termination resistor jumper on EBB board
4. **DO NOT** connect CAN cable yet

### Phase 2: Configure and Build Katapult

Configure Katapult for the EBB SB2209's RP2040 processor. The RP2040 uses a smaller 16KiB
bootloader (vs 128KiB on STM32) and requires specific flash chip settings. CAN GPIO pins 4
and 5 are specific to the EBB board's hardware design.

```bash
# Enter Katapult directory
cd ~/katapult/

# Open configuration menu
make menuconfig
```

**Katapult Configuration for EBB SB2209 (RP2040):**
```
Micro-controller Architecture (Raspberry Pi RP2040/RP235x) --->
Processor model (rp2040) --->
Flash chip (GENERIC_03H with CLKDIV 4) --->
Build Katapult deployment application (16KiB bootloader) --->
Communication Interface (CAN bus) --->
(4) CAN RX gpio number
(5) CAN TX gpio number
(1000000) CAN bus speed
() GPIO pins to set on bootloader entry
[*] Support bootloader entry on rapid double click of reset button
[ ] Enable bootloader entry on button (or gpio) state
[*] Enable Status LED
    (gpio26) Status LED GPIO Pin
```

Press `q` → `Yes` to save and exit.

```bash
# Build Katapult
make clean
make
```

### Phase 3: Configure and Build Klipper

Build Klipper firmware for the EBB board. Configuration must match Katapult settings
(processor, CAN pins, and 16KiB bootloader offset). This firmware handles all toolhead
operations once connected via CAN.

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
lsusb | grep -i boot
```

**Expected result:**
```
Bus 001 Device XXX: ID 2e8a:0003 Raspberry Pi RP2 Boot
```

**Note:** The device ID (2e8a:0003 shown above) may be different on your system. Record the
actual ID from your output - you'll need it in the next steps.

❌ **If not found:** Repeat DFU mode entry process

### Phase 7: Flash Katapult

```bash
# Flash Katapult to EBB (replace 2e8a:0003 with your device ID from Phase 6)
cd ~/katapult
make flash FLASH_DEVICE=2e8a:0003
```

### Phase 8: Re-enter DFU Mode

**Hardware Changes:**
1. **Remove** USB cable between Manta M8P and EBB
2. **Remove** USB_5V jumper from EBB board
3. **Connect** CAN cable (CAN_H and CAN_L only, leave power wires disconnected)
4. **Keep** 120Ω termination jumper on EBB board

### Phase 9: Flash Klipper

```bash
# Run the following command to find CAN uuid
cd ~/katapult/scripts
python3 flash_can.py -i can0 -q
```

Use command following to flash Klipper via Katapult

```bash
python3 flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u be69315a613c
```

**Note:** The be69315a613c is replaced with the actual UUID.


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

## Archived Final CAN Configuration

The following configuration is for the old EBB CAN setup only. It should **not** be applied to the current Nitehawk-SB USB setup.

### Old CAN Printer Configuration

If restoring the EBB CAN setup, add to your `printer.cfg`:

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

## Archived CAN Success Verification Checklist

Only applicable when restoring the old CAN setup:

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

## Archived Future CAN Firmware Updates

Only applicable when the EBB CAN setup is restored. The current Nitehawk-SB USB setup uses the Nitehawk firmware/update process instead.

**Manta M8P**: Requires DFU mode entry and USB flashing (repeat Stage 1)

**EBB boards**: Can be updated via CAN:
```bash
python3 ~/katapult/scripts/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u <EBB_UUID>
```

---

## Additional Resources

**Official Documentation:**
- [BTT EBB 2209 CAN RP2040 Wiki](https://bttwiki.com/EBB%202209%20CAN%20RP2040.html)

**Community Guides:**
- [Esoterical's CAN Bus Guide - Manta M8P V2.0](https://canbus.esoterical.online/mainboard_flashing/common_hardware/BigTreeTech%20Manta%20M8P%20v2.0/README.html)
- [Esoterical's CAN Bus Guide - SB2209 RP2040](https://canbus.esoterical.online/toolhead_flashing/common_hardware/BigTreeTech%20SB2209%20(RP2040)/README.html)
- [Voron Forum: Manta M8P + BTT EBB SB22xx Setup](https://forum.vorondesign.com/threads/manta-m8p-btt-ebb-sb22xx-setup.1697/)

---

**Critical Reminder:** This guide is archived for the old Manta M8P + EBB SB2209 CAN setup. The current repository uses Manta M8P USB serial plus LDO Nitehawk-SB USB serial. Do not use these CAN settings for the current printer unless you intentionally revert to CAN hardware.

*Last updated for current repo status: June 2026*
*Original CAN guide: August 2025*
