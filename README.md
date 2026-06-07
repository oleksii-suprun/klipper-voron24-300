# Voron 2.4 300mm - Klipper Configuration

Klipper configuration for a Voron 2.4 300mm using a BigTreeTech Manta M8P V2.0 main controller and an LDO Nitehawk-SB USB toolboard.

## Current Hardware

### Main Controller

- BigTreeTech Manta M8P V2.0 with Raspberry Pi CM4
- STM32H723 MCU
- Connected to Klipper by USB serial
- Active config section: `[mcu]` in `printer.cfg`

### Toolhead

- LDO Nitehawk-SB
- RP2040 MCU
- Connected to Klipper by USB serial
- Active config section: `[mcu nhk]` in `nitehawk-sb.cfg`
- Handles X endstop, extruder, hotend, part cooling, probe, LEDs, and ADXL345

### Removed / Archived Hardware

- BigTreeTech EBB SB2209 CAN is no longer used.
- The old CAN setup guides are retained only as archived reference for rollback or future hardware changes.

## Features

- CoreXY motion for a 300x300x250 Voron 2.4
- Quad gantry leveling
- Native Klipper adaptive bed mesh with `BED_MESH_CALIBRATE ADAPTIVE=1`
- KAMP line purge and smart park
- StealthBurner status LEDs
- Nitehawk-SB ADXL345 resonance testing
- Host, controller, chamber, part cooling, hotend, and Nevermore fan control
- Moonraker/Mainsail integration
- Optional config backup macro using Klipper's `gcode_shell_command` extension

## Active Files

```text
printer.cfg                  Main Klipper configuration
nitehawk-sb.cfg              LDO Nitehawk-SB toolboard configuration
stealthburner_leds.cfg       StealthBurner LED macros
KAMP_Settings.cfg            KAMP feature/settings file
macro/ext.cfg                Homing, QGL, and chamber helper macros
macro/print_start_end.cfg    PRINT_START / PRINT_END
macro/config_backup.cfg      BACKUP_CFG macro
moonraker.conf               Moonraker configuration
KlipperScreen.conf           KlipperScreen generated settings
doc/                         Archived setup guides and notes
```

`KAMP` and `mainsail.cfg` are symlinks expected to resolve on the printer host:

```text
KAMP -> /home/oleksii/Klipper-Adaptive-Meshing-Purging/Configuration
mainsail.cfg -> /home/oleksii/mainsail-config/client.cfg
```

## Required Host-Side Components

- Klipper
- Moonraker
- Mainsail
- LDO Nitehawk-SB firmware installed and reachable by `/dev/serial/by-id/...`
- KAMP installed at `~/Klipper-Adaptive-Meshing-Purging`
- Moonraker object processing enabled
- Slicer object labeling enabled
- Optional: Klipper `gcode_shell_command` extension for `BACKUP_CFG`

## KAMP / Adaptive Mesh Setup

The active config uses native Klipper adaptive bed mesh plus KAMP purge/park helpers:

```ini
[exclude_object]
```

```ini
[file_manager]
enable_object_processing: True
```

```ini
[include KAMP_Settings.cfg]
```

Enabled KAMP features:

- `KAMP/Line_Purge.cfg`
- `KAMP/Smart_Park.cfg`

The current `PRINT_START` sequence is:

```gcode
BED_MESH_CLEAR
M104 S150
M190 S{params.BED_TEMP}
M109 S150
G32
G90
BED_MESH_CALIBRATE ADAPTIVE=1
SMART_PARK
M109 S{params.EXTRUDER_TEMP}
G92 E0
LINE_PURGE
```

Recommended OrcaSlicer start gcode:

```gcode
M104 S0 ; Stops OrcaSlicer from sending temp waits separately
M140 S0
M117
PRINT_START EXTRUDER_TEMP=[first_layer_temperature] BED_TEMP=[first_layer_bed_temperature]
```

`M117` is useful with KAMP/Moonraker object processing because it can force object definitions to be inserted before `PRINT_START`.

## Useful Macros

- `PRINT_START BED_TEMP=<temp> EXTRUDER_TEMP=<temp>`
- `PRINT_END`
- `G32` - conditional home, quad gantry level, final home
- `CG28` - home only if not already homed
- `M141 S<temp>` - set chamber fan target
- `BACKUP_CFG` - run config backup script if shell command extension is installed

## Firmware Notes

This repository currently expects USB serial MCU connections:

```ini
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32h723xx_...

[mcu nhk]
serial: /dev/serial/by-id/usb-Klipper_rp2040_...
restart_method: command
```

Do not configure the Manta as a USB-to-CAN bridge for this current Nitehawk-SB setup.

## Archived Guides

- `doc/manta_m8p_can_setup_guide.md` - archived Manta + EBB SB2209 CAN setup
- `doc/can0_setup_guide.md` - archived CAN interface setup

These guides are not part of the current printer configuration.

## Backup Notes

`BACKUP_CFG` depends on:

- Klipper `gcode_shell_command` extension
- `~/.voron-backup-config`
- GitHub credentials in that external config

Moonraker's SQLite database is runtime/history state, not configuration. It is ignored by git and is not backed up by default. Set `BACKUP_DATABASE=true` in `~/.voron-backup-config` only if you intentionally want to copy it into the config repo.

## Current Status

Last updated: June 2026

Tested/current hardware: Raspberry Pi CM4 with Manta M8P V2.0 and LDO Nitehawk-SB USB toolboard.
