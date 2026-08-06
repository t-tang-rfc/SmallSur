# PROGRESS — Fixing SmallSur on Xubuntu 24.04

Date: 2026-08-06
Test machine: `cassandra` VM (Xubuntu 24.04.4 LTS, Xfce 4.18, user `t-tang-rfc`, display `:0.0`)

## Result

`install-debian.sh` now completes end-to-end on a stock Xubuntu 24.04 and the
theme is visibly applied (verified by `xfconf-query` and a screenshot of the
session): WhiteSur-Dark GTK theme + window decorations, WhiteSur-dark icons,
WhiteSur cursors, global-menu top panel with the SmallSur layout, SmallSur
wallpaper, plank themes installed.

## Root causes found (why it consistently failed on 24.04)

1. **README said to run the script with `sudo`.** That is fatal in several
   ways: `~` becomes `/root` so everything lands in root's home;
   `xfconf-query` cannot reach the user's session bus so no setting is ever
   applied; and WhiteSur's own installer *refuses to run* its `-l`
   (libadwaita) option as root — it errors out with "Do not run '--libadwaita'
   option with sudo!". This alone makes the documented install path fail
   every time.

2. **`xfce4-statusnotifier-plugin` no longer exists on Ubuntu ≥ 21.04**
   (the systray was merged into xfce4-panel 4.16+). Because all plugins were
   installed in a single `apt install` line, the missing package made the
   whole line fail, so *none* of the panel plugins got installed.

3. **WhiteSur-gtk-theme build dependencies were missing** (`sassc`,
   `libglib2.0-dev-bin`, `libxml2-utils`, `dialog` — none ship with Xubuntu).
   The theme's installer tries to auto-install them, but first runs an
   internet check that connects to iana.org; on this VM that check fails
   (restricted network), so the installer aborts with a misleading
   "internet connection issue" error — and still exits 0 in some paths,
   hiding the failure. `dialog` is required unconditionally by
   `show_needed_dialogs()` even for non-interactive runs.

4. **The cursor theme never applied.** The script copied the cursors to
   `~/.local/share/icons/dist/` (keeping the upstream `dist` directory name)
   but set `/Gtk/CursorThemeName` to "WhiteSur Cursors". Xfce matches cursor
   themes by *directory name*, so neither the copy location nor the setting
   was right.

5. **Wrong GTK theme name (case).** The WhiteSur fork installs the theme as
   `WhiteSur-Dark` (capital D) but the script set `WhiteSur-dark`. Theme
   lookup is case-sensitive, so GTK silently fell back to the default theme.
   (The *icon* theme really is lowercase `WhiteSur-dark`, which hides the
   mismatch.)

6. **The panel layout was overwritten again on logout.** The script copied
   `xfce4-panel.xml` while `xfconfd` was still running; xfconfd writes its
   in-memory state back on exit, discarding the copied file.

7. **The bundled `xfce4-panel.xml` was a raw dump of the author's machine.**
   It referenced `xfce4-sensors-plugin` (not installed on stock Xubuntu) and
   contained the author's personal systray history (Wi-Fi SSID names,
   Discord/Steam/AnyDesk entries, etc.).

8. Minor: `git clone` into the repo directory made re-runs fail ("directory
   already exists"), and running via sudo left root-owned clones behind.
   The window-manager (xfwm4) theme and wallpaper were never set at all.

## Changes made

### `install-debian.sh` (rewritten)
- Refuses to run as root; `sudo` is used internally only for `apt-get install`.
- Package list fixed for 24.04: installs `xfce4-appmenu-plugin`,
  `appmenu-gtk2-module`, `appmenu-gtk3-module`, `plank`, plus WhiteSur build
  deps (`sassc`, `libglib2.0-dev-bin`, `libxml2-utils`, `dialog`).
  Dropped `xfce4-statusnotifier-plugin` (gone), `xfce4-power-manager`,
  `xfce4-pulseaudio-plugin`, `xfce4-notifyd`, `xfce4-indicator-plugin`
  (all ship with Xubuntu already / not appearance-related).
- Upstream repos are cloned into `~/.cache/smallsur-build` and reused on
  re-runs (idempotent, keeps the repo clean).
- Cursors installed as `~/.local/share/icons/WhiteSur-cursors` and
  `/Gtk/CursorThemeName` set to `WhiteSur-cursors` (directory name).
- GTK + xfwm4 theme set to `WhiteSur-Dark` (correct case); xfwm4 window
  decorations and wallpaper (all monitors/workspaces) are now set too.
- Panel layout applied safely: `xfce4-panel --quit` → kill `xfconfd` → copy
  xml → restart panel.
- Gracefully skips the "apply settings" phase with a warning when run outside
  an Xfce session; exports a `TERM` fallback (WhiteSur's installer calls
  `setterm`, which dies without it, e.g. over ssh).
- Fails loudly (`exit 1` + message) when a sub-installer fails instead of
  printing "SmallSur installed" regardless.

### `xfce4-panel/xfce4-panel.xml`
- Removed `xfce4-sensors-plugin` (plugin-7) — not available on stock Xubuntu.
- Removed the author's personal systray data (Wi-Fi SSIDs, known/hidden app
  lists). Validated with `xmllint`.

### `README.md`
- Debian/Ubuntu instructions no longer use `sudo`; added a note to run the
  script as the normal user from inside the Xfce session.

## Test log (on cassandra)

1. Reproduced the failure: fresh clone of WhiteSur-gtk-theme,
   `./install.sh -c dark -c light` → "DEPS: 'dialog' is required…" →
   "DEPS ERROR: You have an internet connection issue" (exit hidden).
2. Installed packages (with user-provided sudo):
   `xfce4-appmenu-plugin appmenu-gtk2-module appmenu-gtk3-module plank sassc
   libglib2.0-dev-bin libxml2-utils dialog` — all from noble repos, OK.
3. Ran the rewritten `install-debian.sh` as the normal user → exit 0.
   Fixed two more issues found during this run (TERM/setterm abort, theme
   name case) and re-verified.
4. Verified via `xfconf-query`: ThemeName=`WhiteSur-Dark`,
   xfwm4 theme=`WhiteSur-Dark`, IconThemeName=`WhiteSur-dark`,
   CursorThemeName=`WhiteSur-cursors`, wallpaper=`~/Pictures/smallsur.png`,
   panel plugin-16=`appmenu`, 13 panel items loaded, panel running.
5. Screenshot of `:0.0` confirms the Big Sur look (dark theme, global menu,
   mac-style window buttons, WhiteSur icons, SmallSur wallpaper).
6. Cleaned up: removed stale root-owned `WhiteSur-*` clones from the repo
   directory (left over from earlier sudo runs) and test helpers on the VM.

## Step 2 (2026-08-06, second commit): plank dock by default

- `install-debian.sh` now configures and starts the dock:
  - pins exactly two default launchers, Firefox and Xfce Terminal, via
    `~/.config/plank/dock1/launchers/*.dockitem` + the `dock-items` gsetting
  - `hide-mode = auto` (dock stays hidden, reveals when the cursor reaches
    the bottom screen edge)
  - theme `mcOS-BS-iMacM1-Black` (the one bundled in this repo)
  - autostarts on login via `~/.config/autostart/plank.desktop`
  - the script (re)starts plank at the end of the run
- Verified on cassandra: gsettings show
  `items=['firefox.dockitem', 'xfce4-terminal.dockitem'] hide='auto'`,
  screenshots confirm the dock shows only Firefox + Terminal and is hidden
  when `auto` is active.
- Note for headless/ssh testing: plank refuses to start unless
  `XDG_SESSION_TYPE=x11` and `XDG_CURRENT_DESKTOP=XFCE` are exported
  (normal desktop logins always have these).

## Step 3 (2026-08-06, third commit): IBM Plex Mono system-wide

- Added `fonts-ibm-plex` (Ubuntu 24.04 package, v6.1.1) to the apt install
  list.
- The script now sets the font everywhere via xfconf:
  - UI font: `/Gtk/FontName` = "IBM Plex Mono 10"
  - Monospace font: `/Gtk/MonospaceFontName` = "IBM Plex Mono 10"
  - Window titles: xfwm4 `/general/title_font` = "IBM Plex Mono Bold 9"
- Verified on cassandra with `xfconf-query` and screenshots: panel, global
  menu, desktop labels, window titlebar and terminal all render in
  IBM Plex Mono.

## Step 4 (2026-08-06, fourth & fifth commits): logo menu + auto-hide menu bar

- Added the built-in `applicationsmenu` plugin (plugin-17) at the far left
  of the top panel, macOS style. It uses the Xubuntu logo
  (`/usr/share/pixmaps/xubuntu-logo-menu.png`, referenced by absolute path so
  it works regardless of the active icon theme) as a placeholder until the
  project has its own logo; no button title is shown.
- Set the top panel to auto-hide (`autohide-behavior = 2`, i.e. always hide;
  it reveals when the cursor reaches the top screen edge, and stays visible
  while one of its menus is open).
- Both verified on cassandra: screenshots show the logo at the top-left and
  the applications menu opening from it.

## Step 5 (2026-08-06, sixth commit): remove the desktop's folder menus

- The "Desktop, Files, Documents, Music, Pictures, Video" entries shown in
  the menu bar when the desktop is focused come from the appmenu (global
  menu) plugin itself: vala-panel-appmenu's `DesktopHelper` builds them from
  a GtkBuilder file compiled into the plugin as the GResource
  `/org/vala-panel/appmenu/desktop-menus.ui`. There is no setting to turn
  them off (verified against the 0.7.6 source and the Debian package).
- Fix: override that resource with GLib's documented `G_RESOURCE_OVERLAYS`
  mechanism. The repo now ships `appmenu/desktop-menus.ui` (menubar emptied),
  the installer copies it to `~/.local/share/smallsur/` and appends the
  export line to `~/.xsessionrc` so it applies to the panel on every login.
- The five folder menus are gone. The single bold "Desktop" word remains:
  its label is hardcoded in the plugin's compiled code (confirmed by a
  marker experiment — menu content follows the overridden resource, the
  label does not). Removing it would require dropping the global-menu plugin
  or rebuilding a patched one; per user's decision it stays, and its
  dropdown still offers Desktop Settings / System Settings.
- Dead ends tried and discarded: blacklisting xfdesktop in
  org.appmenu.gtk-module (the menus don't come from xfdesktop's export) and
  omitting the menu ids from the override (the label still renders).

## Not done / notes
- `install-arch.sh` / `install-fedora.sh` still have the same class of bugs
  (sudo usage, cursor dir name, theme-name case, xfconfd overwrite); only the
  Debian script was in scope here.
- Nothing was committed, per request. Modified files:
  `install-debian.sh`, `xfce4-panel/xfce4-panel.xml`, `README.md`,
  new `PROGRESS.md`.
