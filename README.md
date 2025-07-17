# M17 Hotspot Setup Script for Raspberry Pi with CC1200 HAT

This repository contains a Bash script to convert a Raspberry Pi (with a CC1200 hat) into a fully functional **M17 digital voice hotspot**. The script automates the entire installation and setup process, including compiling the necessary software, configuring UART, setting up the web dashboard, and flashing the firmware to the CC1200 HAT (optional).

---

## Features

- Verifies root and OS requirements
- Ensures it's run on a **fresh install** of Raspberry Pi OS Bookworm (64-bit)
- Prompts for required reboots after critical system changes
- Configures UART for proper HAT communication
- Installs all necessary system packages
- Creates a dedicated `m17` user for running services
- Clones and compiles the following M17 Project repositories:
  - `libm17`
  - `rpi-interface`
  - `CC1200_HAT-fw` (firmware flashing optional)
  - `rpi-dashboard` (web interface)
- Configures NGINX and PHP-FPM to serve the dashboard
- Provides clear next steps for user customization

---

## Tested Hardware and OS

This script was tested on:

- **Raspberry Pi Zero 2 W**
- **Raspberry Pi OS Lite (64-bit), Bookworm (Debian 12-based)**

Other Pi models or OS versions may work but are **not officially supported**.

---

## Prerequisites

- Fresh install of Raspberry Pi OS Bookworm **Lite (64-bit)**
- Raspberry Pi with internet access
- CC1200 HAT connected
- Run the script as **root**

---

## Manual Configuration (After Setup)

After the script completes, **you must configure**:

- `/opt/m17/etc/rpi-interface.cfg`
  - Set your **call sign**, **frequency**, and **transmit settings**
  - Update the log path:
    ```ini
    log_file=/opt/m17/rpi-dashboard/files/log.txt
    ```

---

## File Summary

- `/opt/m17/` - Main working directory for M17-related repositories
- `/opt/m17/rpi-dashboard/` - Web interface root (served by NGINX)
- `/opt/m17/etc/rpi-interface.cfg` - Main configuration file
- `/boot/firmware/config.txt` - UART settings applied here

---

## Disclaimer

This script makes **system-wide changes** and should **only be run on a clean install**. Do **not** use on a production system or one with existing services unless you know what you're doing.

---

## Support

For questions or issues, please contact [M17 Project](https://m17project.org/) or open a GitHub issue in the relevant repository.

---

## License

This script is provided as-is, under the MIT License. Contributions welcome.

