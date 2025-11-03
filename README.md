# Voron 2.4 300mm - Klipper Configuration

A comprehensive Klipper configuration for a Voron 2.4 300mm 3D printer using BigTreeTech Manta M8P V2.0 controller board with Raspberry Pi CM4 compute module and EBB SB2209 CAN toolhead board.

## 📋 Hardware Configuration

### Main Controller Board
- **BigTreeTech Manta M8P V2.0** with Raspberry Pi CM4 Compute Module
- STM32H723 microcontroller
- CAN bus communication via USB-to-CAN bridge mode
- UUID: `8c2968dbfb37`

### Toolhead Board
- **BigTreeTech EBB SB2209 CAN V1.0**
- RP2040 microcontroller
- CAN bus communication
- Includes extruder, hotend fan, part cooling fan, and probe

### Motion System
- **CoreXY kinematics** with 300x300x250mm build volume
- **X/Y Motors**: TMC2209 drivers at 0.8A current
- **Z Motors**: 4x independent Z steppers (quad gantry leveling)
- **Extruder**: Located on toolhead board via CAN

### Heated Bed
- **SSR controlled** via PA1 pin (HE1)
- **Generic 3950 thermistor**
- **PID controlled** heating

### Fans & Temperature Control
- **Host cooling fan** (temperature-controlled)
- **Controller fan** for MCU cooling
- **Chamber exhaust fan** with temperature sensor
- **Nevermore filter** (manually controlled)

## 🚀 Features

- **CAN Bus Communication**: Reduced wiring with robust communication protocol
- **Automatic Bed Meshing**: Adaptive bed mesh based on print area
- **Quad Gantry Leveling**: Automated Z-axis leveling system
- **Input Shaper**: Pre-configured resonance compensation
- **Status LEDs**: Visual feedback during operations
- **Multiple Fan Controls**: Chamber, host, controller, and nevermore fans
- **Shake&Tune Integration**: Advanced vibration analysis and tuning
- **Spoolman Integration**: Filament management system

## 📁 File Structure

```
├── printer.cfg                               # Main printer configuration
├── mainsail.cfg                              # Mainsail web interface config
├── moonraker.conf                            # Moonraker API server config
├── KlipperScreen.conf                        # KlipperScreen display config
├── bigtreetech-ebb-sb-rp2040-canbus-v1.0.cfg # Toolhead board config
├── stealthburner_leds.cfg                    # LED control configuration
├── autocommit.sh                             # Automatic configuration backup script
├── macro/                                    # Custom G-code macros
│   ├── adaptive_bed_mesh.cfg                 # Smart bed meshing
│   ├── config_backup.cfg                     # Configuration backup macros
│   ├── ext.cfg                               # Extruder-related macros
│   └── print_start_end.cfg                   # Print start/end sequences
└── doc/                                      # Setup and configuration guides
    ├── can0_setup_guide.md                   # CAN interface setup
    └── manta_m8p_can_setup_guide.md          # CAN hardware setup
```

## 🔧 Setup & Configuration

### Prerequisites

Before setting up this configuration, ensure you have:

1. **Raspberry Pi CM4** with a compatible Linux OS installed (Raspberry Pi OS, Armbian, etc.)
2. **Klipper, Moonraker, and Mainsail** installed via KIAUH
3. **Klipper Gcode Shell Command Extension** installed for backup functionality
4. **CAN interface** properly configured (see setup guides)
5. **Hardware** properly wired according to Voron 2.4 specifications

#### KIAUH Installation
Install Klipper and related components using KIAUH (Klipper Installation And Update Helper):

```bash
# Install KIAUH
cd ~ && git clone https://github.com/dw-0/kiauh.git
cd kiauh && ./kiauh.sh

# From KIAUH menu, install in order:
# 1. Klipper
# 2. Moonraker  
# 3. Mainsail (or Fluidd)
# 4. KlipperScreen (optional, for touchscreen)
```

#### Shell Command Extension
The backup functionality requires the shell command extension. Install it after Klipper:

```bash
cd ~/klipper
wget -O klipper/extras/gcode_shell_command.py https://raw.githubusercontent.com/dw-0/kiauh/master/resources/gcode_shell_command.py
sudo systemctl restart klipper
```

This extension enables the `BACKUP_CFG` macro to automatically commit configuration changes to GitHub.

### Initial Setup Steps

1. **Clone this repository** to your printer's configuration directory:
   ```bash
   cd ~/printer_data/config
   git clone https://github.com/yourusername/klipper-voron24-300.git .
   ```

2. **Follow the setup guides** in the `doc/` folder in order:

   - **[CAN0 Interface Setup](doc/can0_setup_guide.md)** - Configures the CAN bus interface with proper queue length (1024) to prevent "Timer too close" errors that cause print failures.

   - **[Manta M8P CAN Setup](doc/manta_m8p_can_setup_guide.md)** - Flashes firmware to both controller and toolhead boards, enabling CAN communication between components.

3. **Update MCU UUIDs** in `printer.cfg`:
   ```ini
   [mcu]
   canbus_uuid: YOUR_MANTA_UUID_HERE
   
   [mcu EBBCan]  
   canbus_uuid: YOUR_EBB_UUID_HERE
   ```

4. **Restart Klipper** and verify all components are detected

## 🎯 Custom Macros

This configuration includes several custom macros that enhance the printing experience:

### Motion & Homing Macros (`macro/ext.cfg`)

- **`G28`** - Enhanced homing command with LED status indicators
  - Shows `STATUS_HOMING` during homing, `STATUS_READY` when complete
  - Replaces default G28 with visual feedback

- **`CG28`** - Conditional homing (only homes if not already homed)
  - Checks if axes are homed before executing G28
  - Prevents unnecessary homing operations

- **`G32`** - Complete printer preparation sequence
  - Executes: conditional home → quad gantry level → final home
  - Shows appropriate LED status throughout the process
  - Essential for print preparation

- **`M141`** - Chamber temperature control
  - Sets target temperature for chamber exhaust fan
  - Usage: `M141 S60` sets chamber target to 60°C

### Print Management Macros (`macro/print_start_end.cfg`)

- **`PRINT_START`** - Comprehensive print start sequence
  - Accepts parameters: `BED_TEMP`, `EXTRUDER_TEMP`, `SIZE` (for adaptive mesh)
  - Sequence: heat bed → conditional home → QGL → adaptive mesh → heat nozzle → prime line
  - Includes LED status updates throughout the process

- **`PRINT_END`** - Safe print completion sequence
  - Automatic toolhead parking and safe positioning
  - Retracts filament and turns off heaters
  - Parks nozzle at rear of build plate
  - Returns LEDs to ready status

- **`_PRIME_LINE`** - Nozzle priming routine (internal macro)
  - Draws two parallel lines at front of bed
  - Ensures consistent extrusion before print starts

### Adaptive Bed Mesh (`macro/adaptive_bed_mesh.cfg`)

- **`ADAPTIVE_BED_MESH`** - Smart bed meshing system
  - Only probes the area where parts will be printed
  - Extracts print area from slicer or exclude_object tags
  - Automatically adjusts probe count and algorithm
  - Supports `SIZE`, `MARGIN`, and `FORCE_MESH` parameters

- **`COMPUTE_MESH_PARAMETERS`** - Calculates optimal mesh settings
  - Computes probe points based on print area
  - Switches between bicubic and lagrange algorithms as needed
  - Ensures minimum 3x3 probe pattern for accuracy

### Configuration Backup (`macro/config_backup.cfg`)

- **`BACKUP_CFG`** - Manual configuration backup
  - Commits current configuration to GitHub repository
  - Requires shell command extension and proper GitHub setup
  - Usage: Run from console when you want to save changes

### LED Status System (`stealthburner_leds.cfg`)

The configuration includes comprehensive LED status macros for visual feedback:

- **`STATUS_READY`** - Printer ready (default state)
- **`STATUS_HOMING`** - During homing operations  
- **`STATUS_LEVELING`** - During quad gantry leveling
- **`STATUS_MESHING`** - During bed mesh calibration
- **`STATUS_HEATING`** - While heating bed/nozzle
- **`STATUS_PRINTING`** - During active printing
- **`STATUS_BUSY`** - General busy state
- **`STATUS_OFF`** - LEDs off

These macros are automatically called by other macros to provide visual feedback during printer operations.

### Usage Examples

```gcode
# Manual bed leveling with status LEDs
G32

# Start print with parameters
PRINT_START BED_TEMP=60 EXTRUDER_TEMP=210 SIZE=50_50_200_200

# Conditional homing (only if needed)
CG28

# Set chamber temperature  
M141 S50

# Backup configuration
BACKUP_CFG
```

## 🔄 Backup & Version Control

This configuration includes automatic backup functionality:

- **autocommit.sh**: Automatically commits configuration changes to git
- **config_backup.cfg**: Klipper macros for manual backup operations
- **Version tracking**: All changes are tracked with timestamps

### Setting Up Automatic Backup

The `autocommit.sh` script requires a configuration file at `~/.voron-backup-config`. Example configuration:

```bash
# Required settings
GITHUB_TOKEN=your_personal_access_token_here
GITHUB_REPO=yourusername/klipper-voron24-300

# Optional settings (defaults shown)
CONFIG_FOLDER=~/printer_data/config
KLIPPER_FOLDER=~/klipper
MOONRAKER_FOLDER=~/moonraker
MAINSAIL_FOLDER=~/mainsail
FLUIDD_FOLDER=~/fluidd
DATABASE_FILE=~/printer_data/database/moonraker-sql.db
GITHUB_BRANCH=main
GIT_USER_NAME=Voron-Backup-Bot
GIT_USER_EMAIL=voron-backup-bot@noreply.github.com
BACKUP_DATABASE=true
VERBOSE_OUTPUT=false
```

The script automatically commits configuration changes with timestamps, includes version information from installed components, and pushes to your GitHub repository. Use the `BACKUP_CFG` macro to trigger manual backups.

**Note**: This solution is based on the [Voron Design backup guide](https://docs.vorondesign.com/community/howto/EricZimmerman/BackupConfigToGithub.html), but the script was modified with several enhancements:

- **Security improvement**: Uses external configuration file instead of hardcoding GitHub token
- **Error handling**: Comprehensive error checking and graceful failure handling
- **Lock file protection**: Prevents simultaneous backup runs that could cause conflicts
- **Version tracking**: Automatically captures and includes version info from Klipper, Moonraker, Mainsail, and Fluidd
- **Database backup**: Optional automatic backup of Moonraker's SQLite database
- **Verbose logging**: Configurable output verbosity for debugging
- **Flexible configuration**: Customizable paths, branch names, and git settings
- **Merge conflict detection**: Automatically handles and reports git merge issues

## 🛠️ Maintenance

### Regular Checks
1. **Verify CAN communication**: `python3 ~/katapult/scripts/flash_can.py -i can0 -q`
2. **Check interface status**: `ip link show can0` (should show `qlen 1024`)
3. **Monitor temperatures**: Ensure all temperature sensors are responding
4. **Test bed leveling**: Run `QUAD_GANTRY_LEVEL` regularly

### Updating Firmware
- **Manta M8P**: Requires DFU mode and USB flashing (see setup guide)
- **EBB boards**: Can be updated via CAN bus:
  ```bash
  python3 ~/katapult/scripts/flash_can.py -i can0 -f ~/klipper/out/klipper.bin -u <EBB_UUID>
  ```

## 🚨 Troubleshooting

### Common Issues

**"Timer too close" errors**:
- Verify CAN queue length: `ip link show can0 | grep qlen` should show `1024`
- Restart CAN service: `sudo systemctl restart can0-setup.service`

**CAN communication failures**:
- Check interface status: `ip link show can0`
- Verify termination resistors are installed
- Test with: `python3 ~/katapult/scripts/flash_can.py -i can0 -q`

**WiFi connection issues**:
- Check NetworkManager status: `systemctl status NetworkManager`
- Rescan networks: `sudo nmcli dev wifi rescan`
- View logs: `journalctl -u NetworkManager -f`

**Boot delays**:
- Verify systemd-networkd is masked: `systemctl is-masked systemd-networkd.service`
- Check for failed services: `systemctl list-units --failed`

## 🔗 Useful Links

- [Voron Design](https://vorondesign.com/) - Official Voron documentation
- [Klipper Documentation](https://www.klipper3d.org/) - Klipper firmware docs
- [BigTreeTech GitHub](https://github.com/bigtreetech) - Hardware documentation
- [Mainsail](https://mainsail.xyz/) - Web interface
- [KlipperScreen](https://klipperscreen.readthedocs.io/) - Touchscreen interface

## ⚠️ Important Notes

- This configuration is **specifically for Manta M8P V2.0** - do not use with other versions
- **CAN bitrate must be 1000000** for all devices on the bus
- **Termination resistors** must be installed on both ends of the CAN bus
- **Always backup** your configuration before making changes
- **Test thoroughly** after any configuration changes

## 📝 License

This configuration is provided as-is for educational and personal use. Modify according to your specific hardware setup and requirements.

---

**Last Updated**: November 2025
**Tested On**: Raspberry Pi CM4 with Manta M8P V2.0 and EBB SB2209 CAN boards