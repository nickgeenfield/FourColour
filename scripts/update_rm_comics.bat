@echo off
setlocal
title rm-comics updater
set "SRC=%~dp0app"
if not exist "%SRC%\resources.rcc" set "SRC=C:\rm_comics\app"
set "TAB=root@10.11.99.1"
set "APP=/home/root/xovi/exthome/appload/rm-comics"

echo rm-comics updater
echo -----------------
echo Using files from: %SRC%
echo Plug the tablet in by USB and close Comics first.
echo You'll be asked for the tablet's SSH password twice
echo (Settings ^> General ^> About on the tablet). It won't show as you type.
echo.
if not exist "%SRC%\resources.rcc" goto missing
if not exist "%SRC%\backend\entry" goto missing
pause

echo.
echo [1/2] Copying the new files to the tablet...
scp "%SRC%\resources.rcc" "%SRC%\backend\entry" %TAB%:/home/root/
if errorlevel 1 goto fail

echo.
echo [2/2] Installing the files and checking the helper...
ssh %TAB% "pkill -f rm-comics/backend/entry; mv -f /home/root/resources.rcc %APP%/resources.rcc && mv -f /home/root/entry %APP%/backend/entry && chmod 755 %APP%/backend/entry && %APP%/backend/entry --selftest && echo Files installed."
if errorlevel 1 goto fail

echo.
echo Done. Now restart the UI with mods in reManager, then open Comics
echo and check for the new version number.
pause
exit /b 0

:missing
echo Couldn't find app\resources.rcc and app\backend\entry.
echo Put this script in the extracted rm_comics folder, or extract the zip to C:\.
pause
exit /b 1

:fail
echo.
echo Something went wrong. Nothing else was changed. Copy the messages above and send them to HAL.
pause
exit /b 1
