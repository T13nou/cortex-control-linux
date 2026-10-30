# Cortex Control on Linux

[![shellcheck](https://github.com/T13nou/cortex-control-linux/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/T13nou/cortex-control-linux/actions/workflows/shellcheck.yml)

Runs **Cortex Control** (Neural DSP, Windows only) under Wine and connects it to the
**Quad Cortex** and **Quad Cortex mini** over USB: device detection, preset editing, full user
interface.

Tested with a Quad Cortex mini on CachyOS (KDE Plasma, Wayland) with Wine 11.20, DXVK 3.1.1 and
Cortex Control 4.1.0.

> Independent project, not affiliated with Neural DSP. Cortex Control is not included: download
> the Windows installer from the Neural DSP website.

> [!TIP]
> **Back up your presets** before you start: this is an unofficial setup, provided as is.

## How it works

The Quad Cortex (USB `152a:880a`) and Quad Cortex mini (`152a:892f`) expose three interfaces: audio (UAC2), MIDI and a
proprietary HID channel (input report 1, output report 2, 128 bytes each). Linux handles audio and
MIDI natively. Cortex Control drives the device through the HID channel, which Wine forwards to the
Windows application through its `hidraw` backend. The Neural DSP (Thesycon) Windows USB driver is
not needed.

Two obstacles, two fixes:

- **USB access**: by default, `/dev/hidrawN` is only accessible to root. The udev rule
  `udev/70-quad-cortex.rules` grants access to the logged-in user (`uaccess` tag) and nobody else,
  for the HID channel of Neural DSP devices only (vendor `152a` is shared with other audio brands,
  so the rule also checks the manufacturer string).
- **Black window**: Cortex Control is a JUCE 8 application that renders with Direct2D. With Wine's
  own Direct3D 11, the window stays black. With [DXVK](https://github.com/doitsujin/dxvk) installed
  in the prefix, the interface renders correctly. Disabling Wine's `d2d1` does not work: the
  application no longer starts.

## Requirements

- **Wine 11** or later (tested with 11.20) and winetricks. With Wine 10.0, Cortex Control does not
  detect the device: Wine lacks the `cfgmgr32` functions it uses to find HID devices. If you are
  stuck on Wine 10, use [0xteo/cortex-control-linux](https://github.com/0xteo/cortex-control-linux),
  which ships a replacement `cfgmgr32.dll` for that case.
- A Vulkan-capable graphics driver (for DXVK)
- Optional: `7z` and ImageMagick (`magick`), to extract the application icon

| Distribution    | Command                                                      |
|-----------------|--------------------------------------------------------------|
| Arch, CachyOS   | `sudo pacman -S wine winetricks 7zip imagemagick`            |
| Fedora          | `sudo dnf install wine winetricks p7zip-plugins ImageMagick` |
| Debian, Ubuntu  | `sudo apt install wine winetricks 7zip imagemagick`          |

On CachyOS, `wine-cachyos` works too. On Debian and Ubuntu, a recent Wine is available from the
[WineHQ repository](https://gitlab.winehq.org/wine/wine/-/wikis/Download).

## Installation

### One line

Plug in the Quad Cortex, then:

```sh
curl -fsSL https://raw.githubusercontent.com/T13nou/cortex-control-linux/main/install.sh | bash
```

The script asks before each step that changes your system:

1. installs the missing packages (`wine`, `winetricks`, `7zip`, `imagemagick`) with `pacman`, `dnf`
   or `apt` (sudo), and warns if your Wine is older than 11;
2. puts the scripts in `~/.local/share/cortex-control-linux` and a `cortex-control` command in
   `~/.local/bin`;
3. installs the udev rule (sudo);
4. downloads the official Cortex Control v4.1.0 installer from Neural DSP's servers and checks its
   SHA-256 (this project does not host it);
5. sets everything up under Wine: the Windows setup wizard opens, keep the default options.

Already have the installer? Pass its path:
`curl -fsSL …/install.sh | bash -s -- ~/Downloads/"Cortex Control v4.1.0.exe"`.
Running the one-liner again updates the scripts and keeps your existing installation; see
[Updating](#updating) for Cortex Control itself.

### Manual

```sh
git clone https://github.com/T13nou/cortex-control-linux.git
cd cortex-control-linux
```

1. udev rule (the only step that needs root):

   ```sh
   sudo install -m 644 udev/70-quad-cortex.rules /etc/udev/rules.d/
   sudo udevadm control --reload
   sudo udevadm trigger --subsystem-match=hidraw
   ```

   Then unplug and replug the Quad Cortex.

2. Install Cortex Control in a dedicated Wine prefix
   (`~/.local/share/wineprefixes/cortex-control`, override with the `CORTEX_PREFIX` variable):

   ```sh
   ./cortex-control install
   ```

   Without an argument, it downloads the tested installer from Neural DSP and checks its SHA-256;
   you can also pass one: `./cortex-control install ~/Downloads/"Cortex Control v4.1.0.exe"`.
   The script creates the prefix (Windows 10), installs DXVK, runs the installer and adds a
   "Cortex Control" entry to the application menu, with the original icon. If the installer offers
   the Neural DSP / Thesycon USB driver, skip it.

3. Check the setup:

   ```sh
   ./cortex-control doctor
   ```

4. Launch it from the menu, or with `./cortex-control run`.

## Updating

```sh
cortex-control update
```

1. **The scripts** are updated first: `git pull` for a clone, otherwise a fresh copy from GitHub.
   If the udev rule changed, it offers to install the new one (sudo).
2. **Cortex Control** is checked against the newest installer listed on
   [Neural DSP's downloads page](https://neuraldsp.com/downloads). If a newer version exists, it asks,
   downloads it and installs it over the current one: your settings and sign-in stay in the prefix.

Versions newer than the tested one (v4.1.0) cannot be checksum-verified (Neural DSP publishes no
checksums) and have not been tested here: if something breaks, please
[open a test report](https://github.com/T13nou/cortex-control-linux/issues/new?template=test-report.yml).
To install a specific installer instead: `cortex-control update --app ~/Downloads/"Cortex Control vX.Y.Z.exe"`.

Prefer this command to an update offered inside Cortex Control: the in-app updater has not been
tested under Wine. A new Cortex Control may also offer a firmware update; see the firmware notes in
[Known limitations](#known-limitations).

## Commands

| Command                         | Purpose                                                    |
|---------------------------------|------------------------------------------------------------|
| `cortex-control doctor`         | Checks Wine, USB access, audio, the prefix and DXVK        |
| `cortex-control install [exe]`  | Creates the prefix, installs DXVK, then Cortex Control (downloaded if no exe is given) |
| `cortex-control update`         | Updates the scripts, then Cortex Control if a newer version exists |
| `cortex-control run`            | Launches Cortex Control                                    |
| `cortex-control stop`           | Kills every Wine process in the prefix                     |
| `cortex-control dxvk`           | Adds DXVK to an existing prefix (black window)             |
| `cortex-control desktop`        | Recreates the menu entry and its icon                      |
| `cortex-control uninstall`      | Removes the prefix, the menu entry and the icon            |

The Wine log is written to `~/.local/state/cortex-control.log`.

## Troubleshooting

- **Device not detected**: give it a few seconds first, Wine brings USB devices up shortly after it
  starts. Then check that `cortex-control doctor` reports "HID channel accessible", and close any
  other application using the Quad Cortex over MIDI. To see what Wine does:
  `WINEDEBUG=+hid,+hidraw cortex-control run`, then look for `152a` in the log.
- **`hidraw … Broken pipe` errors in the log**: harmless, the device rejects one optional message
  and everything else works.
- **Window partly off-screen**: double-click the title bar to maximize it (or resize it), then
  close the app; it remembers its size.
- **Keep Wine's default X11 driver** (XWayland on a Wayland desktop). Wine's Wayland driver is
  reported to give the window a Windows-style frame and to break resizing.
- **A phantom "Quad Cortex" with a warning sign** in the device picker: after the device reboots
  (e.g. a firmware update), Wine keeps a stale entry for it. `cortex-control run` clears these
  entries when Cortex Control is not already running; close the app and launch it again.
- **Black window**: `cortex-control dxvk`, then relaunch.
- **fish shell**: `~` is not expanded after `=` (`env WINEPREFIX=~/…` fails); use `$HOME`.
- **Last resort**: a Windows virtual machine (virt-manager) with the Quad Cortex passed through over USB.

## Audio

None of this is needed for audio: the Quad Cortex is a standard USB audio interface, picked up
directly by PipeWire.

- Switch it to the **Pro Audio** profile (e.g. in `pavucontrol` or your desktop's sound settings)
  to get plain `AUX` channels instead of a fake surround layout.
- For a DAW, install `pipewire-jack` (Arch: `pipewire-jack`, Fedora: `pipewire-jack-audio-connection-kit`,
  Debian/Ubuntu: `pipewire-jack`).

## Known limitations

- Only the **Quad Cortex mini** has been tested. The full-size Quad Cortex (`152a:880a`) exposes
  the same HID channel and is covered by the udev rule and the script, but nobody has confirmed it
  works yet: feedback welcome.
- Firmware updates and device reboot from Cortex Control work under Wine (tested once on a
  Quad Cortex mini). A firmware update remains the riskiest operation: a USB disconnection or a
  Wine crash during the write could leave the device in a bad state. Use a direct USB port (no
  hub), close other applications using the device, and keep a Windows or macOS machine at hand
  as a fallback.
- The Neural DSP account session works and persists across restarts. Not verified yet: Cortex
  Cloud downloads and uploads.

## Feedback welcome

This setup has only been tested on one machine so far. If you try it, please
[open a test report](https://github.com/T13nou/cortex-control-linux/issues/new?template=test-report.yml), whether it works or not,
with:

- your device (Quad Cortex or Quad Cortex mini) and Cortex Control version
- your distribution, desktop environment (and X11 or Wayland), Wine and DXVK versions
- what works and what does not (detection, preset editing, firmware update, Cortex Cloud…)
- the output of `cortex-control doctor`

Reports from full-size Quad Cortex owners are especially useful.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/T13nou/cortex-control-linux/main/uninstall.sh | bash
```

It removes the Wine prefix (Cortex Control and its settings), the menu entry, shortcuts and icons,
the scripts, the cached installer and the log, then asks before removing the udev rule (sudo).
Packages such as Wine are kept.

Manual install: `./cortex-control uninstall`, then
`sudo rm /etc/udev/rules.d/70-quad-cortex.rules && sudo udevadm control --reload`.

## See also

[0xteo/cortex-control-linux](https://github.com/0xteo/cortex-control-linux) solves the same
problem independently, with a more automated installer (Ubuntu), a `cfgmgr32` shim for Wine 10
and fixes for the setup wizard. Its udev rule inspired the manufacturer match used here.

## License

[MIT](LICENSE)
