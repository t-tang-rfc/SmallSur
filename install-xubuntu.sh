#!/bin/bash

# @brief: SmallSur installer for Debian/Ubuntu (tested on Xubuntu 24.04)
#
# @usage: Run this as your normal desktop user, from inside your Xfce session:
#   ./install-xubuntu.sh
#
# @note: 
# - Do NOT run the whole script with sudo --- the themes are installed per-user and the settings are applied to your desktop session.
# - The script calls sudo internally only for installing packages.

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: do not run this script as root/with sudo."
  echo "Run it as your normal user: ./install-xubuntu.sh"
  echo "(it will use sudo internally only for 'apt-get install')"
  exit 1
fi

# Run from the repo directory so relative paths (wallpaper/, plank/, ...) work
cd "$(dirname "$0")" || exit 1

# WhiteSur's installer uses setterm, which aborts when TERM is unset
# (e.g. when this script is run over ssh or from a launcher)
export TERM="${TERM:-xterm}"

# Where the WhiteSur upstream repos are cloned (kept so re-runs are fast)
workdir="${XDG_CACHE_HOME:-$HOME/.cache}/smallsur-build"
mkdir -p "$workdir"

# --- Function definitions

# @brief: Set an xfconf property, creating it as a string when it does not exist yet
xfconf_set() {
  xfconf-query -c "$1" -p "$2" -s "$3" 2>/dev/null || \
    xfconf-query -c "$1" -p "$2" --create -t string -s "$3"
}

# --- Install Packages

# @details:
# - xfce4-appmenu-plugin + appmenu-gtk*-module: Global Menu in the top panel (Menu Bar)
# - plank-reloaded (successor of plank): the Dock
# - mugshot: user account editor
# - sassc, libglib2.0-dev-bin, libxml2-utils, dialog: needed by WhiteSur-gtk-theme's installer
# @note: 
# - xfce4-notifyd, xfce4-power-manager and xfce4-pulseaudio-plugin already ship with Xubuntu 24.04
# - plank-reloaded need to be installed through the PPA

# Add the PPA for plank-reloaded (zquestz)
wget -q -O - https://zquestz.github.io/ppa/ubuntu/KEY.gpg | sudo gpg --dearmor -o /usr/share/keyrings/zquestz-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/zquestz-archive-keyring.gpg] https://zquestz.github.io/ppa/ubuntu ./" | sudo tee /etc/apt/sources.list.d/zquestz.list

sudo apt-get update

packages="xfce4-appmenu-plugin appmenu-gtk2-module appmenu-gtk3-module plank-reloaded mugshot sassc libglib2.0-dev-bin libxml2-utils dialog"
missing=""
for pkg in $packages; do
  case "$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null)" in
    *"install ok installed"*) ;;
    *) missing="$missing $pkg" ;;
  esac
done
# Only reach for sudo when something is actually missing, so re-runs (e.g. to
# re-apply the sizing after a DPI change) don't ask for a password
if [ -n "$missing" ]; then
  sudo apt-get install -y $missing || {
    echo "ERROR: package installation failed"; exit 1;
  }
fi

#GTK theme
[ -d "$workdir/WhiteSur-gtk-theme" ] || \
  git clone https://github.com/jothi-prasath/WhiteSur-gtk-theme.git --depth=1 "$workdir/WhiteSur-gtk-theme"
"$workdir/WhiteSur-gtk-theme/install.sh" -l -c dark -c light || {
  echo "ERROR: WhiteSur GTK theme installation failed"; exit 1;
}

#Icons
[ -d "$workdir/WhiteSur-icon-theme" ] || \
  git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1 "$workdir/WhiteSur-icon-theme"
"$workdir/WhiteSur-icon-theme/install.sh" || {
  echo "ERROR: WhiteSur icon theme installation failed"; exit 1;
}

#Cursors
# The cursor theme directory name is what Xfce refers to, so it must be
# installed as "WhiteSur-cursors" (not "dist")
[ -d "$workdir/WhiteSur-cursors" ] || \
  git clone https://github.com/vinceliuice/WhiteSur-cursors.git --depth=1 "$workdir/WhiteSur-cursors"
mkdir -p ~/.local/share/icons/
rm -rf ~/.local/share/icons/WhiteSur-cursors
cp -r "$workdir/WhiteSur-cursors/dist" ~/.local/share/icons/WhiteSur-cursors

#Wallpapers
mkdir -p ~/Pictures/
cp -r wallpaper/* ~/Pictures/

# --- Configuration

# Start the Dock automatically on login
mkdir -p ~/.config/autostart/
cat > ~/.config/autostart/plank.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Plank
Comment=macOS-like dock
Exec=plank
OnlyShowIn=XFCE;
EOF

# @note: Everything below changes the current desktop session, so it needs a running Xfce session (xfconfd). Skip it gracefully when run outside one.
if ! xfconf-query -c xsettings -l >/dev/null 2>&1; then
  echo "WARNING: no Xfce session found (xfconf not reachable)."
  echo "Themes and panel layout were installed but not applied."
  echo "Log into Xfce and pick them in Settings > Appearance / Window Manager,"
  echo "or re-run this script from a terminal inside the session."
  exit 0
fi

#Xfce4-panel
# The panel layout has to be copied while xfconfd is not running, otherwise
# xfconfd overwrites it again with the old layout on logout
xfce4-panel --quit 2>/dev/null
pkill -x xfconfd
sleep 1
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/
cp -p xfce4-panel/xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

#Applying theme (the GTK theme installs as "WhiteSur-Dark", capital D,
#while the icon theme installs as "WhiteSur-dark" -- both are case-sensitive)
xfconf_set xsettings /Net/ThemeName "WhiteSur-Dark"
#Window manager theme
xfconf_set xfwm4 /general/theme "WhiteSur-Dark"
#Icon theme
xfconf_set xsettings /Net/IconThemeName "WhiteSur-dark"
#Cursor theme
xfconf_set xsettings /Gtk/CursorThemeName "WhiteSur-cursors"

# OS wide font setting
if fc-list | grep -qi "IBM Plex Sans JP"; then
  xfconf_set xsettings /Gtk/FontName "IBM Plex Sans JP 10"
else
  echo "WARNING: font 'IBM Plex Sans JP' not found, skipping /Gtk/FontName"
fi

if fc-list | grep -qi "IBM Plex Mono"; then
  xfconf_set xsettings /Gtk/MonospaceFontName "IBM Plex Mono 10"
else
  echo "WARNING: font 'IBM Plex Mono' not found, skipping /Gtk/MonospaceFontName"
fi

if fc-list | grep -qi "IBM Plex Sans JP SmBld"; then
  xfconf_set xfwm4 /general/title_font "IBM Plex Sans JP SemiBold 10"
else
  echo "WARNING: font 'IBM Plex Sans JP SemiBold' not found, skipping /general/title_font"
fi

# Wallpaper setting
for prop in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
  xfconf_set xfce4-desktop "$prop" "$HOME/Pictures/smallsur.png"
done

# Restart the panel with the new layout
nohup xfce4-panel >/dev/null 2>&1 &

# (Re)start the dock
pkill -x plank 2>/dev/null
sleep 1
nohup plank >/dev/null 2>&1 &

echo "SmallSur installed"
echo "Re-login to make the theme take effect"
