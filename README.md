# KDE Plasma ⇄ Hyprland session switcher

Switch between a **KDE Plasma** session and a **Hyprland** session with one keypress, no password, no
login screen. Optionally plays a **zoom-out-and-fade outro** on every monitor while the switch happens.

Built for **Arch Linux + SDDM**.

- `Meta+Shift+Backspace` in Plasma → you land in Hyprland
- `Super+Shift+Backspace` in Hyprland → you land in Plasma
- both shortcuts are your choice (or skip them and bind the command yourself)

> **Tested on:** CachyOS · KDE Plasma 6 · Hyprland 0.55+ · SDDM 0.21.0

---

## Contents

1. [What it does](#what-it-does)
2. [Requirements](#requirements)
3. [Install / uninstall](#install--uninstall)
4. [Installation Options](#installation-options)
5. [Dependencies](#dependencies)
6. [Everything it creates](#everything-it-creates)
7. [What you can safely edit](#what-you-can-safely-edit)
8. [Troubleshooting](#troubleshooting)
9. [Security notes](#security-notes)
10. [Known limitations](#known-limitations)

---

## What it does

SDDM normally makes you log out, wait for the greeter, pick a session and type a password. This project
removes that loop:

1. You press the shortcut.
2. (Optional) a screenshot of each monitor is taken and shrinks/fades out full-screen.
3. The current session is closed, either instantly (**fast**) or politely (**normal**).
4. SDDM restarts and **auto-logs you straight into the other session**.

It also lets you choose which environment the login screen **pre-selects on every boot**, independent of
what you last used.

## Requirements

| Requirement | Notes |
|---|---|
| **SDDM** as your display manager | The installer aborts if `sddm` is not found |
| **KDE Plasma 6** Wayland session | Uses `kwriteconfig6`, `qdbus6`, `kbuildsycoca6`, `kpackagetool6` |
| **Hyprland** Wayland session | Written for the **Lua config** (Hyprland 0.55+, `hyprland.lua`). See [limitations](#known-limitations) |
| `systemd` + `sudo` | Helper runs through `sudo` and `systemd-run` |
| A normal user account | The installer refuses to run as root; it calls `sudo` itself |
| An interactive terminal | Run it as a file: `bash install.sh` (piping from `curl` will not work) |

Both a Plasma and a Hyprland `.desktop` file must exist in `/usr/share/wayland-sessions` (or
`/usr/local/share/wayland-sessions`). If you have several (e.g. `hyprland.desktop` and
`hyprland-uwsm.desktop`) the installer lets you pick.

## Install / uninstall

Repository: <https://github.com/DarknessIV4/Quick-Switching-Between-KDE-Plasma-and-Hyperland->

### Auto

Clone the repository and run the installer with `bash`:

```bash
git clone https://github.com/DarknessIV4/Quick-Switching-Between-KDE-Plasma-and-Hyperland-.git
cd Quick-Switching-Between-KDE-Plasma-and-Hyperland-
bash install.sh
```

To remove everything the installer created:

```bash
bash uninstall.sh
```

### Manual

Download the files yourself instead of using `git`:

1. Download `install.sh` and `uninstall.sh`.
2. Put both files in the same folder and open a terminal in that folder.
3. Run them with `bash`:

```bash
bash install.sh 
```

To remove everything the installer created:

```bash
bash uninstall.sh
```

Either way, log out and back in once afterwards so the KDE shortcut is loaded.

Re-running `install.sh` is safe: it replaces its own files and its own block in `hyprland.lua`.
**It will overwrite any edits you made to the generated files** (see [editing](#what-you-can-safely-edit)).

## Installation Options

| # | Question | Options |
|---|---|---|
| 1 | Which **Plasma** session | Auto-selected if only one exists |
| 2 | Which **Hyprland** session | Auto-selected if only one exists. Pick the one you normally log in with (the `uwsm` entry is a UWSM-managed session) |
| 3 | **Default environment after boot** | What SDDM pre-selects at every boot: Plasma or Hyprland |
| 4 | **Logout behaviour** | **Fast**: old session is cut at once, quickest, *unsaved work in it is lost*. **Normal**: on KDE apps are asked to close first; an app with unsaved work can hold the switch up until you answer |
| 5 | **Shortcuts** | **Auto**: creates the KDE shortcut and adds a block to your `hyprland.lua` (you choose the keys). **Manual**: nothing is touched; the exact lines are printed and saved to `~/session-switch-instructions.txt` |
| 6 | **Outro animation** | Install the zoom-out outro (extra packages), or switch instantly with no extra packages |

You then get a summary and a final "Ready to install?" prompt. Nothing is written before that.

---

## Dependencies

### Installed for you (only if you choose the outro, and only on Arch-based systems)

```
sudo pacman -S --needed --noconfirm mpv ffmpeg jq grim spectacle qt6-tools libkscreen
```

| Package | Used for |
|---|---|
| `mpv` | Plays the zoom-out/fade animation fullscreen on each monitor |
| `ffmpeg` (`ffprobe`) | Reads the size of the all-screens screenshot on KDE |
| `jq` | Parses `hyprctl` / `kscreen-doctor` JSON |
| `grim` | Per-monitor screenshots on Hyprland |
| `spectacle` | All-screens screenshot on KDE |
| `qt6-tools` | Provides `qdbus6` |
| `libkscreen` | Provides `kscreen-doctor` |

If `pacman` fails with a 404 / "target not found", your package database is stale: run
`sudo pacman -Syu` and re-run the installer. On non-Arch systems the installer does not install
anything; it prints what you need and verifies the commands exist.

Choosing **no outro** installs **no packages**.

### Must already be present

| Tool | Package (Arch) | Needed when |
|---|---|---|
| `sddm` | `sddm` | always |
| `sudo`, `visudo` | `sudo` | always |
| `systemctl`, `systemd-run`, `loginctl` | `systemd` | always |
| `flock` | `util-linux` | always |
| `pgrep`, `pkill` | `procps-ng` | always |
| `kwriteconfig6`, `kbuildsycoca6` | KDE Plasma 6 | auto-assigned KDE shortcut |
| `qdbus6` | `qt6-tools` | normal-logout mode (KDE side) |
| `hyprctl` | `hyprland` | normal-logout mode, and the outro |
| `uwsm` | `uwsm` | optional – used automatically if a UWSM session is active |
| `awk`, `sed`, `grep`, `install`, `mktemp` | base | always |

The installer checks every command it needs and lists **all** missing ones at once with the package name.

---

## Everything it creates

| Path | Owner | Purpose |
|---|---|---|
| `/usr/local/bin/switch-session` | root, 755 | The privileged helper |
| `/etc/sudoers.d/switch-session` | root, 440 | Lets **your user** run that one script without a password |
| `/etc/systemd/system/sddm-default-session.service` | root | Boot-default setter (enabled) |
| `/etc/sddm.conf.d/zz-switch-autologin.conf` | root | **Temporary** autologin rule, exists only during a switch |
| `/var/lib/sddm/state.conf` | sddm | **Modified** (`Session=` line only) |
| `/var/log/switch-session.log` | root | Helper log |
| `/run/switch-session.{token,before,lock}` | root | Runtime state (tmpfs, gone on reboot) |
| `~/.local/bin/switch-with-outro` **or** `switch-now` | you | Script the shortcuts call |
| `~/.local/bin/outro-logout.lua` | you | mpv animation script (outro only) |
| `~/.local/share/applications/switch-to-hyprland.desktop` | you | Hidden entry for the KDE shortcut |
| `~/.config/kglobalshortcutsrc` | you | **Modified**: one `_launch` key |
| `~/.config/hypr/hyprland.lua` | you | **Modified**: one fenced block appended (+ timestamped backup) |
| `~/session-switch-instructions.txt` | you | Only in manual-shortcut mode |
| `~/.cache/switch-outro.log` | you | Outro log (overwritten each run) |
| `$XDG_RUNTIME_DIR/switch-outro/`, `/tmp/switch-outro.lock` | you | Temporary files while the outro runs |

`uninstall.sh` removes all of the above (and removes only the fenced block from `hyprland.lua`). It leaves
the packages installed and leaves the backup files.

---

## What you can safely edit

> Everything below is **overwritten if you re-run `install.sh`**. Make a note of your tweaks, or edit
> `install.sh` itself instead (first table) so they survive reinstalls.

### Before installing (in `install.sh`)

| What | Where | Notes |
|---|---|---|
| Default shortcut text offered at the prompts | `KDE_KEY=` / `HYPR_KEY=` near the top of the questions section | KDE format `Meta+Shift+Backspace`; Hyprland Lua format `SUPER + SHIFT + BACKSPACE`. You can also just type different keys at the prompt (no `"` or `\`) |
| Path of your Hyprland config | `HYPR_CFG=` | If yours is not `~/.config/hypr/hyprland.lua` |
| Animation length / end size / fade | `local DUR, MINZ, FADE = …` inside the `LUA_EOF` block | See next table |
| Watchdog timeout, animation wait cap, mpv flags | `sleep 25`, `-gt 6000`, the `mpv …` line inside the `OUTRO_EOF` block | See next table |

### After installing (the generated files)

| What | File | How | Takes effect |
|---|---|---|---|
| Animation length | `~/.local/bin/outro-logout.lua` → `DUR` | seconds (default `1.2`) | next switch |
| Animation end size | same file → `MINZ` | scale at the end, between 0 and 1 (default `0.55`) | next switch |
| Fade-out length | same file → `FADE` | seconds, keep it ≤ `DUR` (default `0.45`) | next switch |
| Fast ⇄ normal logout | `~/.local/bin/switch-with-outro` (or `switch-now`) → `FAST=1` / `FAST=0` | `1` = cut the session at once (unsaved work lost), `0` = normal logout | next switch |
| Watchdog timeout | `switch-with-outro` → `sleep 25` | Seconds before leftover outro windows are removed. In normal mode keep it comfortably longer than you'd take to answer a "save your work?" prompt | next switch |
| **Boot default** environment | `/usr/local/bin/switch-session` → `DEFAULT_ENV=` | `plasma` or `hyprland` (edit with `sudo`) | next boot, or run `sudo /usr/local/bin/switch-session default` now |
| Which session file is used | `/usr/local/bin/switch-session` → `PLASMA_FILE=` / `HYPR_FILE=` | Full path to an existing `.desktop` in `wayland-sessions` (e.g. swap to `hyprland-uwsm.desktop`) | next switch |
| Hyprland shortcut | the block in `~/.config/hypr/hyprland.lua` | Change the key string in the `hl.bind(...)` line. Hyprland reloads when you save | immediately |
| KDE shortcut | `kglobalshortcutsrc` | `kwriteconfig6 --file kglobalshortcutsrc --group services --group switch-to-hyprland.desktop --key _launch "Meta+Alt+H"`, then log out and in. (Or re-run the installer) | after re-login |

After editing the helper, check it still parses: `sudo bash -n /usr/local/bin/switch-session`.
After editing the user scripts: `bash -n ~/.local/bin/switch-with-outro`.

**Taking over the Hyprland block yourself:** if you delete the `-- >>> session-switch` / `-- <<< session-switch`
marker lines, the installer and uninstaller will no longer manage those lines and you must remove them by hand.

**Switching between the outro and no-outro variants** is easiest by re-running the installer
(the shortcuts must point at the matching script).

---

## Troubleshooting

| Symptom | What to check |
|---|---|
| Shortcut does nothing in KDE | Log out and back in once after install (KDE loads shortcuts at login) |
| The login screen appears instead of auto-login | `sudo cat /var/log/switch-session.log`; confirm `/etc/sudoers.d/switch-session` exists; make sure no other SDDM config sorting after `zz-switch-autologin.conf` overrides `[Autologin]` |
| Frozen screenshot stays on screen | It clears itself after ~25 s. To clear it now: switch to a TTY (`Ctrl+Alt+F3`) and run `pkill -f outro-logout.lua` |
| Animation looks wrong on multi-monitor KDE | `cat ~/.cache/switch-outro.log` shows the detected monitors and crop rectangles |
| Test the animation without switching | `~/.local/bin/switch-with-outro preview` |
| A switch got stuck in *normal* mode | An app is probably waiting on a save prompt; answer it, or use fast mode |

Logs: `/var/log/switch-session.log` (helper), `~/.cache/switch-outro.log` (outro).

## Security notes

- The installer adds one sudoers line letting **your user** run **one root-owned script**,
  `/usr/local/bin/switch-session`, without a password. Any program running as you can therefore ask it to
  restart SDDM (which logs you out). That is the intended trade-off.
- The helper does not execute commands or file paths taken from its arguments. As far as I have reviewed
  it, all it does with root is: edit SDDM's state file, write/delete the autologin drop-in, write its log
  and runtime files, and run `systemctl restart sddm`. Audit it yourself before trusting it — it is short
  (`/usr/local/bin/switch-session`, ~120 lines).
- Keep the helper **root-owned and not user-writable**.
- *Fast logout* terminates the old session without asking applications first: unsaved work is lost.

## Known limitations

- Written for **Hyprland's Lua configuration** (0.55+). With an old hyprlang `.conf`, the installer prints a
  `bind = …` line for manual use, but the normal-logout command uses `hl.dsp.exit()` and fast mode is the
  reliable choice there.
- Wayland sessions only (it scans `wayland-sessions`).
- Targets the user who ran the installer (single-user sudoers rule).
- SDDM only.
- Package installation is automated for Arch-based systems only.
- Mixed-scale / rotated multi-monitor setups on KDE rely on a computed crop of one all-screens
  screenshot.
- Haven't been tested on other environments other than KDE and Hyperland. 

## License

Licensed under the **GNU General Public License v3.0** (GPL-3.0). See the [LICENSE](LICENSE) file.
