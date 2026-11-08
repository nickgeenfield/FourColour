# FourColour

<img src="assets/icon.png" alt="FourColour icon: a white-bordered square with a red panel across the top, a blue panel at the bottom left and a yellow panel at the bottom right" width="128" height="128">

FourColour is Nick Greenfield's comic-book reader for the reMarkable Paper Pro (colour e-ink). It runs as an [AppLoad](https://github.com/asivery/rm-appload) app under [XOVI](https://github.com/asivery/rm-xovi-extensions). This repository is version 1.5.2. AppLoad shows the name **FourColour**. The app id, and the folder on the tablet, stay `rm-comics` (`/home/root/xovi/exthome/appload/rm-comics/`). See [CHANGELOG.md](CHANGELOG.md).

Comics live in `/home/root/comics/` on the tablet and are copied from a PC with `scp`. The screen is QML (`app/ui/main.qml`), packed into `resources.rcc` from `app/application.qrc`. A Rust program (`app/backend`) is installed as the static binary `backend/entry`: it lists the library, opens the archives and stores the page you were on. The Windows installer in `installer/` asks for the tablet's IP address and the `root` password. The password is masked as you type. The installer uploads the app over SSH, using SFTP when the tablet offers it. The executable is unsigned, so SmartScreen shows **More info**, then **Run anyway**. The installer leaves the UI restart to you: reload AppLoad, or restart the UI with mods (for example with reManager).

## Features

| | Feature | What you get |
| --- | --- | --- |
| ☑ | Library | Comics under `/home/root/comics`, including sub-folders. Folders come first, then files, in natural order (`2` before `10`). **Up** leaves a sub-folder. **Exit** closes the app. |
| ☑ | CBZ, ZIP, CBR and RAR | The library lists `.cbz`, `.zip`, `.cbr` and `.rar`, in any letter case. Opening follows the file header, so a `.cbr` that is really a zip still opens. |
| ☑ | Page images | JPEG, PNG, GIF, BMP and WebP. Hidden files and `__MACOSX` entries inside the archive are skipped. Each page is fitted to the screen, keeping its shape, on a black background. |
| ☑ | Turning pages | The right-hand third goes forward, the left-hand third goes back, and the middle third does nothing. A sideways swipe also turns the page. |
| ☑ | Top bar and page slider | A tap in the top strip (the top 12%) shows **Library**, the page count, the on-screen version and **Exit**. A tap in the bottom strip (the bottom 12%) shows the slider. Dragging updates the page number only; the page loads when you let go. A tap on the track jumps straight there. |
| ☑ | Remembers your page | The page is saved per comic and restored the next time you open it. The library shows it as `p. N`, counting from 1. |
| ☑ | Delete | A **Delete** button on the row, or a press of about 0.8 seconds on the comic. A confirmation asks before the file is removed from the tablet. Folders have no delete. |
| ☑ | One comic cached | Extracted pages sit in `/home/root/.cache/rm-comics`. Only the comic you opened last is kept. |

The library title bar and the reader bar show **v1.5.2**. With either bar open, a tap on the page hides it.

Saved pages are a JSON map at `/home/root/.local/share/rm-comics/progress.json`.

## Requirements

- A reMarkable Paper Pro, with developer mode on.
- [XOVI](https://github.com/asivery/rm-xovi-extensions) and [AppLoad](https://github.com/asivery/rm-appload), already installed and working.
- A Windows 10 or Windows 11 PC on the same Wi-Fi network as the tablet. Over USB, the installer's default address `10.11.99.1` works instead.

## Installation

1. Download `FourColour_v1.5.2_installer.zip` from the [Releases](https://github.com/nickgeenfield/FourColour/releases) page and extract it. The program is `FourColour-Installer.exe`. A short `README.txt` sits beside it.
2. Windows SmartScreen may warn that it does not recognise the app. Choose **More info**, then **Run anyway**.
3. On the tablet, switch on Wi-Fi and unlock the device. Close FourColour if it is already open. With a USB cable you can leave the address at the installer's default, `10.11.99.1`.
4. Find the tablet's IP address under **Settings > General > Help > About**.
5. The SSH user is `root`. The password is under **Settings > General > Help > About > Copyrights and licenses** (scroll down). The menu item is labelled "Copyrights and licenses" on the device. Developer mode is required. The password is case-sensitive and can change after a software update.
6. Run `FourColour-Installer.exe`. Enter the IP address, the user `root`, and the password. The password is not shown as you type.
7. When the menu appears, choose:
   - **1** — Install or update FourColour
   - **2** — Uninstall FourColour
   - **3** — Quit
8. After install or update, open AppLoad on the tablet and tap **Reload**. If FourColour still does not appear, restart the UI with mods, for example via reManager. The installer does not restart the UI itself.
9. Open the AppLoad menu and tap **FourColour**.

Install and update copy `manifest.json`, `resources.rcc`, `icon.png` and `backend/entry` into `/home/root/xovi/exthome/appload/rm-comics/`. They create `/home/root/comics` if it is missing, and they run `backend/entry --selftest`, which has to succeed (the program prints `ok`). Saved pages are left in place.

The installer accepts the tablet's current SSH host key on each run, because that key changes when the tablet's software is updated. Run it on a network you trust.

Option **3** (or `q`) changes nothing.

The same steps, including the USB copy script, are written up in [docs/GUIDE-Windows.md](docs/GUIDE-Windows.md).

## Adding comics

Comics go in `/home/root/comics/` on the tablet. Sub-folders are kept, so a series can have its own folder. The library skips names that start with a dot.

From the PC (use the tablet's IP, or `10.11.99.1` over USB):

```sh
scp -r /path/to/Comics/* root@TABLET_IP:/home/root/comics/
```

`scp` asks for the tablet password. WinSCP (SFTP, user `root`) can drag the files across instead. [docs/GUIDE-Windows.md](docs/GUIDE-Windows.md) has the Windows commands.

`scripts/update_rm_comics.bat` copies a built `resources.rcc` and `backend\entry` to the tablet over USB. It does not copy comics.

### Formats the reader opens

The library lists directories and files ending in `.cbz`, `.zip`, `.cbr` or `.rar`. Letter case does not matter. Opening then checks the header: `PK` is read as a zip, `Rar!` as a RAR. Any other header fails with "Unknown archive type (not zip or rar)". An empty library says "No .cbz or .cbr files in …"; `.zip` and `.rar` are still listed when they are present.

Pages inside the archive have to be `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp` or `.webp`. Other entries are skipped, including a path that contains `__macosx` and a file whose name starts with a dot. If nothing remains, opening fails with "No images found in this comic". Page files are sorted naturally by name.

Zip and CBZ need stored files or deflate compression. In `app/backend/Cargo.toml` the `zip` crate is built with default features off and `deflate` on, so bzip2, xz and zstd zips are outside what this build extracts.

If Qt on the tablet cannot decode a page, the reader shows "This page could not be shown (unsupported image type?)".

## Wi-Fi uploads with Dropz

[Dropz](https://github.com/nickgeenfield/FourColour/releases) 1.1 is a small companion for FourColour. It runs a tiny HTTP server on the tablet (port **8080**) so you can send comics over Wi-Fi from a browser on a PC or phone, without SCP or a USB cable for day-to-day use. SSH is only needed to install or uninstall it.

Author: Nick Greenfield. Dropz is MIT licensed, the same as FourColour. It has been tested on a reMarkable Paper Pro with firmware **3.28.0.172**, with XOVI managed through reManager, and AppLoad.

Dropz 1.0 installed `/etc/systemd/system/dropz.service`. On this firmware the `/etc` overlay is temporary, so a reboot removed the unit and Dropz stopped, while `/home/root/dropz` and the comics could still be there. Dropz 1.1 installs no systemd unit and does not remount the root filesystem or `/etc`. The server, the scripts and an optional XOVI post-start hook live under `/home/root`. An idempotent `/home/root/dropz/start.sh` starts the server. A background hook at `/home/root/xovi/scripts/post-start/90-dropz.sh` runs that helper whenever XOVI starts. The installer starts Dropz immediately and does not restart the reMarkable UI.

### What Dropz does

1. Listens on port **8080**. `/home/root/dropz/start.sh` starts one server and leaves an existing listener on that port alone. When XOVI starts, `/home/root/xovi/scripts/post-start/90-dropz.sh` runs the helper in the background and returns at once, so Dropz comes back with XOVI. That is automatic start after XOVI, which is separate from an unattended boot service.
2. On a device on the same Wi-Fi, open `http://<tablet-ip>:8080/`.
3. Drag in one or more `.cbz`, `.cbr`, `.zip` or `.rar` files — or a zip that itself contains several comics.
4. Uploads are queued and sent one at a time, each with a progress bar. A failed file is retried up to three times without stopping the rest.
5. Files are saved into `/home/root/comics`. Existing names are **never overwritten**; a suffix such as ` (1)` is added instead. The new file is created exclusively, so a name that appears at the same moment is not overwritten either.
6. The page also lists the comics already on the tablet.

PDF is rejected, because FourColour does not open PDF comics. An optional PIN can be set at install time. Only a salted hash is kept, at `/home/root/dropz/pin.hash`. An update keeps the hash that is already there.

### Install Dropz (Windows)

Leave Dropz 1.0 installed and update it in place. Stop any upload that is in progress, and leave the tablet switched on and unlocked.

1. Download `Dropz-1.1-Setup.zip` from the [Releases](https://github.com/nickgeenfield/FourColour/releases) page and extract it into a new folder. The program is `Dropz-1.1-Setup.exe`.
2. Windows SmartScreen may warn that it does not recognise the app. Choose **More info**, then **Run anyway**.
3. Enter the tablet's address. Over USB, press Enter to accept `10.11.99.1`. Over Wi-Fi, enter the address shown under **Settings > General > Help > About**. Press Enter to accept the user `root`, then type the SSH password. The password is masked and is **never stored**. It is under **Settings > General > Help > About > Copyrights and licenses**. The menu item is labelled "Copyrights and licenses" on the device.
4. Choose **1** to install or update Dropz 1.1, or **2** to uninstall.
5. At **Start Dropz automatically after XOVI starts in reManager?**, press Enter for **Yes**.
6. At **Set an optional PIN?**, choose **No** to keep an existing PIN unchanged. Choose **Yes** only to set or replace it.
7. Wait until the installer reports **Dropz 1.1 health check passed**. It prints the URL and offers to open Dropz in your default browser. It does **not** restart the reMarkable UI. There is no need to rebuild hashtab: this update changes no QML mods.

The installer backs up first. Before it changes an existing install, the tablet script creates a private `/home/root/dropz-backup-<date>-<random>/`. If that backup fails, the update stops. Comics in `/home/root/comics` stay out of the backup. An existing PIN hash is kept. A leftover ComicDrop directory is preserved, and its PIN hash is copied only when Dropz has none. A Dropz or ComicDrop unit file is stopped, disabled and removed only when that file is still present. No new unit is written.

An existing Dropz-owned **Dropz.url** shortcut on the Desktop is updated in place to the new address. A shortcut Dropz already owns is not saved again as `Dropz (1).url`. An unrelated file of that name is left as it is, and a numbered name is used for the new shortcut. The previous Dropz shortcut is backed up in the local user cache under `Dropz/shortcut-backups`. If an older `Dropz (1).url` is still on the Desktop, check that it is the old link and delete it by hand. The installer never deletes older Desktop shortcuts.

### Manual install

`Dropz-1.1-Setup.zip` includes a `manual` folder with the same payload as the Windows installer: `dropz`, `install.sh`, `uninstall.sh`, `start.sh`, `stop.sh`, `dropz-post-start.sh` and `README.md`. From the folder you unzipped, copy `manual` to a **new** staging directory under `/home/root`. The script then copies the payload into `/home/root/dropz`. Run `install.sh` from the staging directory.

```sh
scp -r manual root@TABLET_IP:/home/root/dropz-1.1-src
ssh root@TABLET_IP
sh /home/root/dropz-1.1-src/install.sh
```

`DROPZ_ENABLE=0` omits the XOVI hook. When `DROPZ_PIN` is unset, an existing PIN is kept. Leave the staging directory in place until the install has succeeded.

### After install

Open:

```
http://<tablet-wifi-ip>:8080/
```

Find the tablet's Wi-Fi address under **Settings > General > Help > About**, or use the address the installer printed. The page is plain HTTP on a trusted local network. If new comics do not appear in FourColour straight away, close the app and open it again.

### After a reboot or an OS update

Dropz 1.0's recovery was to run `install.sh` again and answer yes to automatic boot startup. That wrote `/etc/systemd/system/dropz.service` once more and enabled it for `multi-user.target`. The Paper Pro wipes that system folder on reboot, so the unit disappeared again and Dropz stopped. `/home/root/dropz` and the comics in `/home/root/comics` could remain. Dropz 1.1 does not restore that unit.

The files that have to persist stay under `/home/root`. `/home/root/dropz/start.sh` is safe to run again: if anything is already listening on port **8080**, it starts nothing further. The hook `/home/root/xovi/scripts/post-start/90-dropz.sh` backgrounds `start.sh`, returns success immediately, and uses a 15-second timeout when `timeout` is available. Without `timeout`, `start.sh` still uses a short run of retries and one-second HTTP checks. Nothing in the hook creates a systemd service.

This is automatic start after XOVI starts. After a reboot, start XOVI with reManager in the usual way. If that XOVI runs its post-start scripts, Dropz starts then. The installer also starts Dropz straight away, without restarting the UI. A UI restart — AppLoad **Reload**, or restarting the UI with mods — restarts the on-screen interface only. It is not what brings Dropz back. [XOVI's start script](https://github.com/asivery/rm-xovi-extensions/blob/master/xovi-setup/start) runs each `post-start` script after it restarts XOVI's services. The [XOVI README](https://github.com/asivery/rm-xovi-extensions/blob/master/README.MD) warns against unattended XOVI boot autostart on an encrypted tablet. A finished install does not by itself prove that one reManager build invokes the hook after a reboot.

If the page does not open a few seconds after XOVI has started, the fallback is one command. SSH to the tablet as `root` and run:

```sh
/home/root/dropz/start.sh
```

To see whether the hook directory is present:

```sh
ls /home/root/xovi/scripts
```

Look for `post-start`. To see whether the installed XOVI start script mentions that directory:

```sh
grep -n post-start /home/root/xovi/start
```

The directory can be present when reManager still does not run it. The check that matters is a reboot, starting XOVI as usual, then opening Dropz. If the hook is not honoured, use `/home/root/dropz/start.sh`. Leave XOVI's startup files and the system mounts as they are.

From a PC or phone on the same Wi-Fi, open port **8080** on the tablet's current Wi-Fi address:

```
http://<tablet-wifi-ip>:8080/
```

Read the address under **Settings > General > Help > About**. After the tablet rejoins Wi-Fi, read the address again and use the one it has now.

An update still goes through `install.sh`, kept on the tablet at `/home/root/dropz/install.sh`. Root's home is `/home/root`, so that directory is `~/dropz`. The script backs up first to `/home/root/dropz-backup-<date>-<random>/`. When `/home/root/dropz` is already present, that directory is archived inside the backup. Comics stay in `/home/root/comics`. The script creates that folder only when it is missing. An existing `/home/root/dropz/pin.hash` stays in place unless a new PIN is supplied.

### Turn Dropz off or on

Stop Dropz for this session. The next XOVI post-start still runs:

```sh
ssh root@TABLET_IP "/home/root/dropz/stop.sh"
```

Start it again. Repeating the command is safe:

```sh
ssh root@TABLET_IP "/home/root/dropz/start.sh"
```

`stop.sh` stops only a process whose executable is `/home/root/dropz/dropz`. To turn the hook off, run setup option **1** again and answer **No** to automatic start after XOVI. The server still starts for that session. To confirm the running server is Dropz 1.1, run `/home/root/dropz/dropz -check`. Recent output is `/home/root/dropz/dropz.log`. The helper's usual flags are `-listen :8080 -comics /home/root/comics -pin-file /home/root/dropz/pin.hash`.

### Uninstall Dropz

Use option **2** in the Windows installer, or:

```sh
sh /home/root/dropz/uninstall.sh
```

A fresh backup is made before anything is removed. Dropz is stopped. Its named program files, `start.sh`, `stop.sh` and an unmodified hook that Dropz owns are removed. Comics, the PIN hash, logs, unknown files and backups are kept. A hook that has been edited is backed up and left in place, with a warning. Without `start.sh` that hook cannot launch Dropz. The UI is not restarted.

You can still copy comics with `scp` or WinSCP as before; Dropz is optional.

## Usage

| To… | Do this |
| --- | --- |
| Open a folder | Tap its row. The title becomes the path under `comics`. **Up** goes back one level. |
| Open a comic | Tap its row. The library shows "Opening comic…" until the pages are ready. |
| See where you left off | Read `p. N` at the right of the row (the first page is `p. 1`). |
| Next page | Tap the right-hand third, or swipe left. |
| Previous page | Tap the left-hand third, or swipe right. |
| Stay on the page | Tap the middle third. A small sideways movement (under about 120 px) does not turn. |
| Library, page count, Exit | Tap the top strip of the page (the top 12%). **Library** saves the page and returns to the list. **Exit** saves the page and closes the app. |
| Jump to a page | Tap the bottom strip (the bottom 12%). Drag until the number is right, then let go. The page loads on release and the slider closes. A single-page comic says "Single-page comic" and has no handle. |
| Hide a bar | With the top bar or the slider open, tap the page. |
| Scroll the library | Move more than about 40 px up or down. A smaller movement does not scroll, so a long press can finish. |
| Delete a comic | Tap **Delete** on the row, or press and hold the row for about 0.8 seconds. Confirm with **Delete**, or **Cancel**, or tap outside the box. The file, its saved page and its cache entry are removed. The notice "Deleted" stays for about four seconds. |
| Leave the app | **Exit** in the library bar, or **Exit** in the reader bar. Closing also saves the open page. |

The confirmation reads "Delete &lt;name&gt;?" and "The file is removed from the tablet. This cannot be undone." Folders have no **Delete** button, and holding a folder does nothing. The backend only removes one comic file inside the comics folder: an absolute path, no `.` or `..` segments, a name ending in `.cbz`, `.zip`, `.cbr` or `.rar`, and not a directory. A symlink is removed only when it points at a comic file that is also inside that folder; the link goes, and a target outside the folder is refused.

If the helper is slow to start, the library asks again about every 1.5 seconds and then shows "The reader's helper did not start. Close and reopen the app."

## Updating

Run the installer again and choose **1**. That replaces `manifest.json`, `resources.rcc`, `icon.png` and `backend/entry` under `/home/root/xovi/exthome/appload/rm-comics/`. Comics in `/home/root/comics` and saved pages in `/home/root/.local/share/rm-comics` are left alone. Then reload AppLoad, or restart the UI with mods. The installer does not do that restart.

`scripts/update_rm_comics.bat` is the USB copy script. Close FourColour first and plug the tablet in. The script looks for `app\resources.rcc` and `app\backend\entry` next to itself, or in `C:\rm_comics\app`. It copies those two files to `root@10.11.99.1`, moves them into the AppLoad folder, marks `backend/entry` executable, and runs `--selftest`. It asks for the SSH password twice (once for `scp`, once for `ssh`); the password is not shown. It does not copy `manifest.json` or `icon.png`, and its on-screen text still says "Comics", which is the earlier name. When it says "Done", restart the UI with mods in reManager, or reload AppLoad.

A finished install prints "FourColour 1.5.2 is installed." The library bar shows **v1.5.2**. `--selftest` prints `ok`.

## Uninstalling

Run the installer and choose **2**.

1. "Remove the FourColour app from this tablet? Your comics in /home/root/comics will be kept." The default is **no**. **No** stops here and changes nothing.
2. "Also delete saved page positions and the cache?" The default is **no**.

**Yes** to the first question removes `/home/root/xovi/exthome/appload/rm-comics` (and the installer's temporary upload directory). Comics in `/home/root/comics` stay either way.

- Leaving the second answer as **no** keeps `/home/root/.local/share/rm-comics` (saved pages) and deletes only `install-manifest.txt` inside it.
- **Yes** to the second question also deletes `/home/root/.local/share/rm-comics` and `/home/root/.cache/rm-comics`.

Restart the UI with mods (for example with reManager) so AppLoad drops the icon.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| SmartScreen blocks the installer | **More info**, then **Run anyway**. The executable is unsigned. |
| "Couldn't reach the tablet" | Same Wi-Fi, or a USB cable. Tablet on and unlocked. IP from **Settings > General > Help > About**. Over USB the address is `10.11.99.1`. On Wi-Fi, SSH over Wi-Fi has to be switched on. The message includes the technical detail. |
| "The tablet rejected the password (or username)." | User `root`. Password from the menu item labelled "Copyrights and licenses", typed with the original case. It can change after a software update. |
| "XOVI isn't installed" or "AppLoad isn't" | Install XOVI and the AppLoad extension first. The installer does not change the tablet in that case. |
| FourColour does not appear, or the UI looks old | Close the app, AppLoad → **Reload**, then open it again. If it is still missing, restart the UI with mods (for example via reManager). |
| "The reader's helper did not start" | Close the app and open it again. On the tablet, `/home/root/xovi/exthome/appload/rm-comics/backend/entry --selftest` should print `ok`. |
| "Could not open: …" | The text after the colon is the backend's reason (unknown archive, no images, or a read error). The Windows guide gives a password-protected RAR as one example. |
| "This page could not be shown (unsupported image type?)" | That page's file is not a type Qt on the tablet decoded. The backend had already extracted it. |
| "Not deleted: …" | The file is still there. It has to be one comic file inside `/home/root/comics`. Folders are refused with "Folders cannot be deleted from the app". |
| Empty library | The folder has nothing the library lists: no sub-folder and no comic file. The empty text names `.cbz` and `.cbr` only; `.zip` and `.rar` are listed when the files are there. A leading dot hides a name. |
| Pages look black and white, or ghosted | The app draws the page image. It does not select a separate colour-refresh mode. [docs/GUIDE-Windows.md](docs/GUIDE-Windows.md) notes that colour refresh inside AppLoad was not confirmed on a tablet. |

## Building from source

The release executable is the supported way to install. To build it yourself, produce `resources.rcc` and `backend/entry` first. Those steps are in [installer/payload/README.md](installer/payload/README.md): Qt 6 `rcc --binary` for the QML, and `cargo zigbuild --release --target aarch64-unknown-linux-musl` for the Rust backend. `manifest.json` and `icon.png` are already in `installer/payload/`.

`go.mod` is inside `installer/` and asks for Go 1.27.3. From the repository root, after the payload is in place (placeholders are enough to compile), build the Windows installer with:

```sh
cd installer
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags '-s -w' -o FourColour-Installer.exe .
```

`CGO_ENABLED=0` keeps the executable free of a C toolchain. The result is `installer/FourColour-Installer.exe`. Executables and zip archives are gitignored.

Check the installer package with:

```sh
cd installer
go vet ./...
go test ./...
```

`//go:embed payload` needs `manifest.json`, `icon.png`, `resources.rcc` and `backend/entry` on disk, or the package does not compile. This tree has no `*_test.go` files. `go test` compiles the installer and `installer/testserver`.

`installer/testserver` is a small SSH server for trying the installer without a tablet. Arguments: listen address, password, and optional `nosftp`. It accepts user `root` with the password you passed on its command line. With SFTP it takes the upload; with `nosftp`, the installer falls back to `cat` over the SSH session. It treats `backend/entry --selftest` as success only when that file is an executable aarch64 ELF, because the stand-in does not run the tablet binary.

On a PC, check the Rust sources with:

```sh
cd app/backend
CXX=g++ cargo check --locked
```

That is a host check. The binary you install is the `aarch64-unknown-linux-musl` build in the payload README. The `unrar` crate compiles C++ during that build. If `c++` is Clang without libc++ headers, `unrar_sys` asks for `-stdlib=libc++` and stops because `<new>` is missing. `CXX=g++` selects libstdc++. `libc++-dev` is the other fix.

Two environment variables override paths when the backend is not running on the tablet. `RMCOMICS_HOME` defaults to `/home/root`. `RMCOMICS_COMICS` defaults to `$RMCOMICS_HOME/comics`. Saved pages go to `$RMCOMICS_HOME/.local/share/rm-comics/progress.json`. The extract cache is `$RMCOMICS_HOME/.cache/rm-comics`.

## Credits

- **FourColour** is by Nick Greenfield.
- **[AppLoad](https://github.com/asivery/rm-appload)** by asivery, which loads the app on the tablet.
- **[XOVI](https://github.com/asivery/rm-xovi-extensions)** by asivery, which AppLoad runs on.

## Licence

MIT. Copyright © 2026 Nick Greenfield. See [LICENSE](LICENSE).
