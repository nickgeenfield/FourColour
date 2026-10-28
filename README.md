# FourColour

<img src="assets/icon.png" alt="FourColour icon: a white-bordered square with a red panel across the top, a blue panel at the bottom left and a yellow panel at the bottom right" width="128" height="128">

FourColour is Nick Greenfield's comic-book reader for the reMarkable Paper Pro (colour e-ink). It runs as an [AppLoad](https://github.com/asivery/rm-appload) app under [XOVI](https://github.com/asivery/rm-xovi-extensions). This repository is version 1.5.1. AppLoad shows the name **FourColour**. The app id, and the folder on the tablet, stay `rm-comics` (`/home/root/xovi/exthome/appload/rm-comics/`).

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

The library title bar and the reader bar show the on-screen version **v1.5**. The installer reports **1.5.1**. With either bar open, a tap on the page hides it.

Saved pages are a JSON map at `/home/root/.local/share/rm-comics/progress.json`.

## Requirements

- A reMarkable Paper Pro, with developer mode on.
- [XOVI](https://github.com/asivery/rm-xovi-extensions) and [AppLoad](https://github.com/asivery/rm-appload), already installed and working.
- A Windows 10 or Windows 11 PC on the same Wi-Fi network as the tablet. Over USB, the installer's default address `10.11.99.1` works instead.

## Installation

1. Download `FourColour_v1.5.1_installer.zip` from the [Releases](https://github.com/nickgeenfield/FourColour/releases) page and extract it. The program is `FourColour-Installer.exe`. A short `README.txt` sits beside it.
2. Windows SmartScreen may warn that it does not recognise the app. Choose **More info**, then **Run anyway**.
3. On the tablet, switch on Wi-Fi and unlock the device. Close FourColour if it is already open. With a USB cable you can leave the address at the installer's default, `10.11.99.1`.
4. Find the tablet's IP address under **Settings > General > Help > About**.
5. The SSH user is `root`. The password is under **Settings > General > Help > About > Copyrights and licences** (scroll down). Developer mode is required. The password is case-sensitive and can change after a software update.
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

An earlier manual procedure, copying files over USB and running `install.sh`, is written up in [docs/GUIDE-Windows.md](docs/GUIDE-Windows.md). That `install.sh` is not part of this repository. For 1.5.1, use the installer from Releases. The guide's notes on reading and deleting still match the app.

## Adding comics

Comics go in `/home/root/comics/` on the tablet. Sub-folders are kept, so a series can have its own folder. The library skips names that start with a dot.

From the PC (use the tablet's IP, or `10.11.99.1` over USB):

```sh
scp -r /path/to/Comics/* root@TABLET_IP:/home/root/comics/
```

`scp` asks for the tablet password. WinSCP (SFTP, user `root`) can drag the files across instead. [docs/GUIDE-Windows.md](docs/GUIDE-Windows.md) also notes that reManager's file browser can drop files into `/home/root/comics`.

`scripts/update_rm_comics.bat` updates the app over USB. It does not copy comics.

### Formats the reader opens

The library lists directories and files ending in `.cbz`, `.zip`, `.cbr` or `.rar`. Letter case does not matter. Opening then checks the header: `PK` is read as a zip, `Rar!` as a RAR. Any other header fails with "Unknown archive type (not zip or rar)". An empty library says "No .cbz or .cbr files in …"; `.zip` and `.rar` are still listed when they are present.

Pages inside the archive have to be `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp` or `.webp`. Other entries are skipped, including a path that contains `__macosx` and a file whose name starts with a dot. If nothing remains, opening fails with "No images found in this comic". Page files are sorted naturally by name.

Zip and CBZ need stored files or deflate compression. In `app/backend/Cargo.toml` the `zip` crate is built with default features off and `deflate` on, so bzip2, xz and zstd zips are outside what this build extracts.

If Qt on the tablet cannot decode a page, the reader shows "This page could not be shown (unsupported image type?)".

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

`scripts/update_rm_comics.bat` is the earlier USB updater. Close FourColour first and plug the tablet in. The script looks for `app\resources.rcc` and `app\backend\entry` next to itself, or in `C:\rm_comics\app`. It copies those two files to `root@10.11.99.1`, moves them into the AppLoad folder, marks `backend/entry` executable, and runs `--selftest`. It asks for the SSH password twice (once for `scp`, once for `ssh`); the password is not shown. It does not copy `manifest.json` or `icon.png`, and its on-screen text still says "Comics", which is the earlier name. When it says "Done", restart the UI with mods in reManager yourself.

The bars in this version still read **v1.5**. A finished 1.5.1 install is the installer's line "FourColour 1.5.1 is installed.", and `--selftest` printing `ok`.

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
| "The tablet rejected the password (or username)." | User `root`. Password from **Copyrights and licences**, typed with the original case. It can change after a software update. |
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
