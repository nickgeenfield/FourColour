# FourColour on Windows

This is the Windows guide for FourColour 1.5.2, a comic-book reader for the reMarkable Paper Pro. Install it with `FourColour-Installer.exe` from the [Releases](https://github.com/nickgeenfield/FourColour/releases) page. The app runs under XOVI, inside AppLoad, under the name **FourColour**. On the tablet the folder is still `rm-comics` (`/home/root/xovi/exthome/appload/rm-comics/`).

## What you need

- A reMarkable Paper Pro, with developer mode on.
- [XOVI](https://github.com/asivery/rm-xovi-extensions) and [AppLoad](https://github.com/asivery/rm-appload), already installed and working.
- A Windows 10 or Windows 11 PC on the same Wi-Fi network as the tablet. Over USB the address is `10.11.99.1`, which is what the installer suggests.

## Install or update

1. Download `FourColour_v1.5.2_installer.zip` from [Releases](https://github.com/nickgeenfield/FourColour/releases) and extract it. The program is `FourColour-Installer.exe`. A short `README.txt` sits beside it.
2. Windows SmartScreen may warn that it does not recognise the app. Choose **More info**, then **Run anyway**. The executable is unsigned.
3. On the tablet, switch on Wi-Fi and unlock the device. Close FourColour if it is already open. A USB cable works as well.
4. Find the tablet's IP address under **Settings > General > Help > About**.
5. The SSH user is `root`. The password is under **Settings > General > Help > About > Copyrights and licenses** (scroll down). The menu item is labelled "Copyrights and licenses" on the device. Developer mode is required. The password is case-sensitive and can change after a software update.
6. Run `FourColour-Installer.exe`. Enter the IP address (or press Enter to keep `10.11.99.1`), the user `root`, and the password. The password is not shown as you type.
7. Choose **1** to install or update. **2** uninstalls. **3** (or `q`) quits and changes nothing.
8. When the installer reports success, it stops. Restart the UI with mods, for example with reManager, or open AppLoad and tap **Reload**. The installer does not restart the UI itself.
9. Open AppLoad and tap **FourColour**. The library title bar shows **v1.5.2** in small grey text.

Install and update copy `manifest.json`, `resources.rcc`, `icon.png` and `backend/entry` into `/home/root/xovi/exthome/appload/rm-comics/`. They create `/home/root/comics` if it is missing, and they run `backend/entry --selftest`, which prints `ok`. Comics and saved pages stay where they are.

The installer accepts the tablet's current SSH host key on each run, because that key changes when the tablet's software is updated. Run it on a network you trust.

## Adding comics

Comics go in `/home/root/comics/` on the tablet. Sub-folders are kept, so a series can have its own folder. From the PC:

```bat
scp -r C:\Comics\* root@TABLET_IP:/home/root/comics/
```

Use the IP from **Settings > General > Help > About**, or `10.11.99.1` over USB. `scp` asks for the tablet password. WinSCP (SFTP, user `root`) can drag the files across instead.

The library lists `.cbz`, `.zip`, `.cbr` and `.rar`. Pages inside the archive are JPEG, PNG, GIF, BMP or WebP. Names that start with a dot are skipped. How to turn pages, jump with the slider, and delete a comic is in the [README](../README.md).

## The update script

`scripts/update_rm_comics.bat` copies an already built app onto the tablet over USB. It does not copy comics into `/home/root/comics/`.

Close FourColour and plug the tablet in. The script looks for `app\resources.rcc` and `app\backend\entry` in the folder it sits in, or in `C:\rm_comics\app`. It copies those two files to `root@10.11.99.1`, moves them into `/home/root/xovi/exthome/appload/rm-comics/`, marks `backend\entry` executable, and runs `--selftest`. It asks for the SSH password twice. The password is not shown. It does not copy `manifest.json` or `icon.png`, and it does not restart the UI. Its window still says "Comics", the earlier name.

When it says "Done", restart the UI with mods in reManager, or reload AppLoad, then check the library bar for **v1.5.2**.

The usual update is the installer, option **1**. That also copies `manifest.json` and `icon.png`.

## Uninstalling

Run the installer and choose **2**. It asks before it removes the app. Comics in `/home/root/comics` are kept. A second question asks whether to delete saved page positions and the cache. The default for both questions is no. Then restart the UI with mods, or reload AppLoad, so the icon disappears.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| SmartScreen blocks the installer | **More info**, then **Run anyway**. |
| "Couldn't reach the tablet" | Same Wi-Fi, or a USB cable. Tablet on and unlocked. IP from **Settings > General > Help > About**. Over USB the address is `10.11.99.1`. On Wi-Fi, SSH over Wi-Fi has to be switched on. |
| "The tablet rejected the password (or username)." | User `root`. Password from the screen labelled "Copyrights and licenses", typed with the original case. It can change after a software update. |
| "XOVI isn't installed" or "AppLoad isn't" | Install XOVI and AppLoad first. The installer leaves the tablet unchanged in that case. |
| FourColour does not appear, or the UI looks old | AppLoad → **Reload**, or restart the UI with mods (for example via reManager). Closing and reopening the app is not enough after an update. |
| "The reader's helper did not start" | Close the app and open it again. On the tablet, `/home/root/xovi/exthome/appload/rm-comics/backend/entry --selftest` should print `ok`. |
| "Could not open: …" | The text after the colon is the reason. Examples from the reader: an archive that is not zip or RAR, a comic with no images, or a password-protected RAR. |
| "Not deleted: …" | The file is still there. Only one comic file inside `/home/root/comics` can be removed. Folders are refused. |
| Pages look black and white, or ghosted | The app draws the page image. It does not select a separate colour-refresh mode. |
