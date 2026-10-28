# Installing the Comics reader (v1.5) from Windows 11

You need: the tablet connected by USB cable and switched on, and your SSH password from the tablet's
**Settings > General > About** (the same one you used for XOVI). When you type the password nothing appears
on screen – that is normal. Press Enter when you have typed it.

## 1. Unzip
Right-click `rm_comics_v1.5.zip` > **Extract All…** and extract it to `C:\`. You should then have `C:\rm_comics\install.sh`.

## 2. Copy it to the tablet
Open **PowerShell** from the Start menu and type:
```
scp -r C:\rm_comics root@10.11.99.1:/home/root/
```

## 3. Install it
```
ssh root@10.11.99.1 "sh /home/root/rm_comics/install.sh"
```
It should finish with "Installed to /home/root/xovi/exthome/appload/rm-comics". If it says ERROR, nothing has
been changed.

## 4. Copy comics to the tablet
To try the two test comics first:
```
scp C:\rm_comics\sample\* root@10.11.99.1:/home/root/comics/
```
For your own comics, put them in a folder on your PC, for example `C:\Comics`, then:
```
scp -r C:\Comics\* root@10.11.99.1:/home/root/comics/
```
Sub-folders are kept, so you can organise them by series. File names with spaces are fine.
(reManager's file browser can also drag files into `/home/root/comics` if you prefer.)

## 5. Open it
Open the AppLoad menu on the tablet and tap **Comics**. If it is not there yet:
- in **reManager**, use the option to **rebuild/restart** XOVI (the same "Restart xochitl with XOVI" step you
  used after installing other mods), **or**
- in PowerShell: `ssh root@10.11.99.1 "/home/root/xovi/start"`

The screen goes blank for up to a minute while it restarts. No hashtab rebuild is needed – this app does not
change any of the tablet's own screens.

## Using it
- Tap a comic to open it. Right third of the page = next page, left third = previous page. Swiping left or right
  turns the page anywhere on the screen. Tapping the middle of the page does nothing (changed in v1.5).
- Tap the **top strip** of the page (roughly the top eighth) for **Library**, the page number, the version (v1.5)
  and **Exit**. This used to be a tap in the middle; it moved to the top in v1.5 so it is not confused with swipes.
- Tap the bottom strip of the page for the page slider. Drag to preview the page number; release to jump there.
- While either bar is showing, tap anywhere else on the page to hide it.
- Drag up or down in the library to scroll the list.
- **Deleting a comic** – two ways, both in the library:
  - **Delete button (added in v1.4):** tap the **Delete** button at the right-hand end of a comic's row.
  - **Long press:** press and hold a comic's name for about a second. From v1.4 a slight wobble of your finger or
    pen no longer cancels it; only lifting off, or moving more than a small distance (which scrolls instead), does.
  A large box asks "Delete <name>?". Tap **Delete** to remove it, or **Cancel** (or anywhere outside the box) to keep it.
  The comic's saved page is forgotten too and the list refreshes. This cannot be undone. Folders have no Delete
  button and holding a folder does nothing; delete folders with WinSCP.

## Updating from an earlier version (e.g. v1.4 to v1.5)
### The easy way: update_rm_comics.bat
1. Extract `rm_comics_v1.5.zip` to `C:\` (overwrite the old files), so the script is at `C:\rm_comics\update_rm_comics.bat`.
2. Close Comics on the tablet and plug the tablet in by USB.
3. Double-click `update_rm_comics.bat`. It asks for the tablet's SSH password twice. It copies the two app files
   (`resources.rcc` and `backend\entry`) to the tablet, installs them, and checks that the helper prints `ok`.
4. The script does **not** restart anything. When it says "Done", **restart the UI with mods in reManager** yourself
   (closing and reopening the app is not enough). No hashtable rebuild is needed.
5. Open Comics and look for "v1.5" in small grey text in the library title bar.

### By hand, if you prefer
1. Close Comics, then stop its helper: `ssh root@10.11.99.1 "pkill -f rm-comics/backend/entry; true"`
2. In WinSCP, drag `C:\rm_comics\app\resources.rcc` into `/home/root/xovi/exthome/appload/rm-comics/` and overwrite.
3. Drag `C:\rm_comics\app\backend\entry` into `/home/root/xovi/exthome/appload/rm-comics/backend/` and overwrite.
4. `ssh root@10.11.99.1 "chmod 755 /home/root/xovi/exthome/appload/rm-comics/backend/entry && /home/root/xovi/exthome/appload/rm-comics/backend/entry --selftest"` – it should print `ok`.
5. Restart the UI with mods in reManager, then check for "v1.5".

## Removing it
```
ssh root@10.11.99.1 "sh /home/root/rm_comics/uninstall.sh"
```
This removes only the Comics app. Your comics and your other mods are not touched. Add ` --all` before the
closing quote to forget saved page positions as well. Then restart with `/home/root/xovi/start` if the icon
is still shown.

## If something goes wrong
- "The reader's helper did not start": close the app and open it again; if it keeps happening, run
  `ssh root@10.11.99.1 "/home/root/xovi/exthome/appload/rm-comics/backend/entry --selftest"` – it should print `ok`.
- "Could not open: …": the message explains why (for example a password-protected RAR).
- "Not deleted: …": the comic could not be deleted; the message explains why.
- Pages appear in black and white or ghosted: tell me, as colour refresh inside AppLoad apps is the one thing
  that could not be checked without the tablet.
