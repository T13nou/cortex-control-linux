# Cortex Control on Linux

Runs **Cortex Control** (Neural DSP, Windows only) under Wine and connects it to the
**Quad Cortex mini** over USB: device detection, preset editing, full user interface.

Tested on CachyOS (KDE Plasma, Wayland) with Wine 11.20, DXVK 3.1.1 and Cortex Control 4.1.0.

> Independent project, not affiliated with Neural DSP. Cortex Control is not included: download
> the Windows installer from the Neural DSP website.

## How it works

The Quad Cortex mini (USB `152a:892f`) exposes three interfaces: audio (UAC2), MIDI and a
proprietary HID channel (input report 1, output report 2, 128 bytes each). Linux handles audio and
MIDI natively. Cortex Control drives the device through the HID channel, which Wine forwards to the
Windows application through its `hidraw` backend. The Neural DSP (Thesycon) Windows USB driver is
not needed.

Two obstacles, two fixes:

- **USB access**: by default, `/dev/hidrawN` is only accessible to root. The udev rule
  `udev/70-quad-cortex.rules` grants access to the logged-in user (`uaccess` tag) and nobody else.
- **Black window**: Cortex Control is a JUCE 8 application that renders with Direct2D. With Wine's
  own Direct3D 11, the window stays black. With [DXVK](https://github.com/doitsujin/dxvk) installed
  in the prefix, the interface renders correctly. Disabling Wine's `d2d1` does not work: the
  application no longer starts.

## Requirements

- A recent Wine (tested with 11.20) and winetricks
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
   sudo udevadm trigger --subsystem-match=hidraw --subsystem-match=usb
   ```

   Then unplug and replug the Quad Cortex mini.

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

The script's messages are in French.

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

- **Device not detected**: `cortex-control doctor` must report the HID channel as accessible
  ("Canal HID accessible"). Close any other application using the Quad Cortex over MIDI. To see what
  Wine does: `WINEDEBUG=+hid,+hidraw cortex-control run`, then look for `152a` in the log.
- **Black window**: `cortex-control dxvk`, then relaunch.
- **fish shell**: `~` is not expanded after `=` (`env WINEPREFIX=~/…` fails); use `$HOME`.
- **Last resort**: a Windows virtual machine (virt-manager) with the Quad Cortex passed through over USB.

## Known limitations

- Only the **Quad Cortex mini** (`152a:892f`) is covered. The full-size Quad Cortex should work the
  same way, but its USB ID is not in the udev rule yet: `lsusb | grep -i cortex` gives the ID to
  add. Contributions welcome.
- Not verified yet: firmware updates under Wine. To be safe, update from Windows or macOS: a USB
  disconnection during the write could leave the device in a bad state.
- Not verified either: signing in to the Neural DSP account and Cortex Cloud sync.

## Uninstall

```sh
./cortex-control uninstall
sudo rm /etc/udev/rules.d/70-quad-cortex.rules
sudo udevadm control --reload
```

## License

[MIT](LICENSE)
