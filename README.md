<p align="center"> <img src="img/logo.png"/>
</p>

# Small Sur
Small Sur is a theme that brings the visual aesthetics of macOS Big Sur to XFCE desktop environment. It is essentially a theme designed to give your Linux desktop a look and feel similar to that of macOS Big Sur. 

## Table of contents
- [Screenshots](#screenshots)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Credits](#credits)

## Screenshots
![](./img/sample1.png)
![](./img/sample2.png)
![](./img/sample3.png)

## Features
- Sleek and modern design inspired by macOS Big Sur.
- Unified and consistent appearance across various applications and system elements.
- Customizable dock and top bar.
- Collection of wallpapers which suitable for this theme.
- BigSur icons and cursors.

## Requirements
- Xubuntu 24.04 (or another Debian/Ubuntu-based distro with the XFCE desktop environment)

`install-xubuntu.sh` installs and configures everything else for you: plank
(dock), the appmenu panel plugin, mugshot, and the WhiteSur GTK/icon/cursor
themes.

## Installation
```bash
git clone https://github.com/t-tang-rfc/SmallSur
```
```bash
cd SmallSur
```
```bash
./install-xubuntu.sh
```
Note:
- run it as your normal user (not with `sudo`) from a terminal inside your Xfce session --- the script uses `sudo` internally only to install packages.
- By default, the wallpapers are installed in the Pictures folder in your home directory.

## Usage
Once the SmallSur theme is installed, you can customize your XFCE desktop environment to match the style. Here are some recommended configurations:
- Adjust the Plank settings to customize the dock appearance and behavior.
- Configure the XFCE panel to organize and manage the top bar elements.
- Set your preferred SmallSur wallpaper from the provided collection.

Feel free to explore and experiment with different configurations to personalize your desktop experience.

## Credits 

GTK Theme - https://github.com/vinceliuice/WhiteSur-gtk-theme

Icon - https://github.com/vinceliuice/WhiteSur-icon-theme 

Cursor - https://github.com/vinceliuice/WhiteSur-cursors

Plank Theme - https://www.gnome-look.org/p/1399398/
