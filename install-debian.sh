#!/bin/bash

# SmallSur installer for Debian/Ubuntu (tested on Xubuntu 24.04)
#
# Run this as your normal desktop user, from inside your Xfce session:
#   ./install-debian.sh
# Do NOT run the whole script with sudo: the themes are installed per-user
# and the settings are applied to your desktop session. The script calls
# sudo internally only for installing packages.

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: do not run this script as root/with sudo."
  echo "Run it as your normal user: ./install-debian.sh"
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

# Packages:
# - xfce4-appmenu-plugin + appmenu-gtk*-module: global menu in the top panel
# - plank: the macOS-like dock
# - fonts-ibm-plex: IBM Plex Mono, used as the system-wide font
# - sassc, libglib2.0-dev-bin, libxml2-utils, dialog: needed by WhiteSur-gtk-theme's installer
# Note: xfce4-notifyd, xfce4-power-manager and xfce4-pulseaudio-plugin already
# ship with Xubuntu, and xfce4-statusnotifier-plugin no longer exists on
# Ubuntu >= 21.04 (the systray is built into xfce4-panel), so none of them are
# installed here.
packages="xfce4-appmenu-plugin appmenu-gtk2-module appmenu-gtk3-module plank fonts-ibm-plex sassc libglib2.0-dev-bin libxml2-utils dialog"
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

#Plank themes
mkdir -p ~/.local/share/plank/themes/
cp -rp "$workdir/WhiteSur-gtk-theme/src/other/plank/"* ~/.local/share/plank/themes/
cp -rp plank/mcOS-BS-iMacM1-Black/ ~/.local/share/plank/themes/

#Plank dock: pin Firefox and Terminal as the default launchers
mkdir -p ~/.config/plank/dock1/launchers/
cat > ~/.config/plank/dock1/launchers/firefox.dockitem <<EOF
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/firefox.desktop
EOF
cat > ~/.config/plank/dock1/launchers/xfce4-terminal.dockitem <<EOF
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/xfce4-terminal.desktop
EOF

#Start the dock automatically on login
mkdir -p ~/.config/autostart/
cat > ~/.config/autostart/plank.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Plank
Comment=macOS-like dock
Exec=plank
OnlyShowIn=XFCE;
EOF

# Everything below changes the current desktop session, so it needs a running
# Xfce session (xfconfd). Skip it gracefully when run outside one.
if ! xfconf-query -c xsettings -l >/dev/null 2>&1; then
  echo "WARNING: no Xfce session found (xfconf not reachable)."
  echo "Themes and panel layout were installed but not applied."
  echo "Log into Xfce and pick them in Settings > Appearance / Window Manager,"
  echo "or re-run this script from a terminal inside the session."
  exit 0
fi

#Global menu: hide the Files/Documents/Music/Pictures/Video menus the appmenu
#plugin shows when the desktop is focused. The menu is compiled into the
#plugin, so it is replaced through GLib's resource-overlay mechanism; the
#override has to be exported before the panel starts, on every login (done
#via ~/.xsessionrc, which Ubuntu's Xsession sources for all X sessions).
mkdir -p ~/.local/share/smallsur/
cp -p appmenu/desktop-menus.ui ~/.local/share/smallsur/
overlay_line='export G_RESOURCE_OVERLAYS="/org/vala-panel/appmenu/desktop-menus.ui=$HOME/.local/share/smallsur/desktop-menus.ui${G_RESOURCE_OVERLAYS:+:$G_RESOURCE_OVERLAYS}"'
if ! grep -qs "smallsur/desktop-menus.ui" ~/.xsessionrc; then
  echo "$overlay_line" >> ~/.xsessionrc
fi
# also make it effective for the panel restarted below
export G_RESOURCE_OVERLAYS="/org/vala-panel/appmenu/desktop-menus.ui=$HOME/.local/share/smallsur/desktop-menus.ui${G_RESOURCE_OVERLAYS:+:$G_RESOURCE_OVERLAYS}"

#Xfce4-panel
# The panel layout has to be copied while xfconfd is not running, otherwise
# xfconfd overwrites it again with the old layout on logout
xfce4-panel --quit 2>/dev/null
pkill -x xfconfd
sleep 1
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/
cp -p xfce4-panel/xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

# set an xfconf property, creating it as a string when it does not exist yet
xfconf_set() {
  xfconf-query -c "$1" -p "$2" -s "$3" 2>/dev/null || \
    xfconf-query -c "$1" -p "$2" --create -t string -s "$3"
}

#Applying theme (the GTK theme installs as "WhiteSur-Dark", capital D,
#while the icon theme installs as "WhiteSur-dark" -- both are case-sensitive)
xfconf_set xsettings /Net/ThemeName "WhiteSur-Dark"
#Window manager theme
xfconf_set xfwm4 /general/theme "WhiteSur-Dark"
#Icon theme
xfconf_set xsettings /Net/IconThemeName "WhiteSur-dark"
#Cursor theme
xfconf_set xsettings /Gtk/CursorThemeName "WhiteSur-cursors"
#Fonts: IBM Plex Mono everywhere (UI, monospace, window titles)
xfconf_set xsettings /Gtk/FontName "IBM Plex Mono 10"
xfconf_set xsettings /Gtk/MonospaceFontName "IBM Plex Mono 10"
xfconf_set xfwm4 /general/title_font "IBM Plex Mono Bold 9"
#Wallpaper (all monitors/workspaces)
for prop in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
  xfconf_set xfce4-desktop "$prop" "$HOME/Pictures/smallsur.png"
done

# Restart the panel with the new layout
nohup xfce4-panel >/dev/null 2>&1 &


#Plank dock settings: Big Sur theme, auto-hide (reveals when the cursor
#reaches the screen edge), only the pinned launchers above
plank_dock="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"
gsettings set "$plank_dock" theme "mcOS-BS-iMacM1-Black"
gsettings set "$plank_dock" hide-mode "auto"
gsettings set "$plank_dock" dock-items "['firefox.dockitem', 'xfce4-terminal.dockitem']"

# (Re)start the dock
pkill -x plank 2>/dev/null
sleep 1
nohup plank >/dev/null 2>&1 &

echo "SmallSur installed"
echo "Reboot your system"
