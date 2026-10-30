# Cortex Control on Linux

Runs **Cortex Control** (Neural DSP, Windows only) under Wine and connects it to the
**Quad Cortex** and **Quad Cortex mini** over USB: device detection, preset editing, full user
interface.

Tested with a Quad Cortex mini on CachyOS (KDE Plasma, Wayland) with Wine 11.20, DXVK 3.1.1 and
Cortex Control 4.1.0.

> Independent project, not affiliated with Neural DSP. Cortex Control is not included: download
> the Windows installer from the Neural DSP website.

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
   ./cortex-control install ~/Downloads/"Cortex Control v4.1.0.exe"
   ```

   The script creates the prefix (Windows 10), installs DXVK, runs the installer and adds a
   "Cortex Control" entry to the application menu, with the original icon. If the installer offers
   the Neural DSP / Thesycon USB driver, skip it.

3. Check the setup:

   ```sh
   ./cortex-control doctor
   ```

4. Launch it from the menu, or with `./cortex-control run`.

## Commands

| Command                         | Purpose                                                    |
|---------------------------------|------------------------------------------------------------|
| `cortex-control doctor`         | Checks Wine, USB access, audio, the prefix and DXVK        |
| `cortex-control install <exe>`  | Creates the prefix, installs DXVK, then Cortex Control     |
| `cortex-control run`            | Launches Cortex Control                                    |
| `cortex-control stop`           | Kills every Wine process in the prefix                     |
| `cortex-control dxvk`           | Adds DXVK to an existing prefix (black window)             |
| `cortex-control desktop`        | Recreates the menu entry and its icon                      |
| `cortex-control uninstall`      | Removes the prefix, the menu entry and the icon            |

The Wine log is written to `~/.local/state/cortex-control.log`.

## Troubleshooting

- **Device not detected**: `cortex-control doctor` must report "HID channel accessible". Close any other application using the Quad Cortex over MIDI. To see what
  Wine does: `WINEDEBUG=+hid,+hidraw cortex-control run`, then look for `152a` in the log.
- **A phantom "Quad Cortex" with a warning sign** in the device picker: after the device reboots
  (e.g. a firmware update), Wine keeps a stale entry for it. `cortex-control run` clears these
  entries when Cortex Control is not already running; close the app and launch it again.
- **Black window**: `cortex-control dxvk`, then relaunch.
- **fish shell**: `~` is not expanded after `=` (`env WINEPREFIX=~/…` fails); use `$HOME`.
- **Last resort**: a Windows virtual machine (virt-manager) with the Quad Cortex passed through over USB.

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
./cortex-control uninstall
sudo rm /etc/udev/rules.d/70-quad-cortex.rules
sudo udevadm control --reload
```

## See also

[0xteo/cortex-control-linux](https://github.com/0xteo/cortex-control-linux) solves the same
problem independently, with a more automated installer (Ubuntu), a `cfgmgr32` shim for Wine 10
and fixes for the setup wizard. Its udev rule inspired the manufacturer match used here.

## License

[MIT](LICENSE)
