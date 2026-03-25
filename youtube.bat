@echo off
setlocal enabledelayedexpansion
:: -----------------------------
:: ✅ Settings
:: -----------------------------
set LOCAL=C:\Users\<yourname>\Videos\JellyFin
set ARCHIVE=%LOCAL%\archive.txt
set WINSCP="C:\Program Files (x86)\WinSCP\WinSCP.com"
set REMOTE_BASE=/Youtube/
set SERVER_USER=<your_server_username>
set SERVER_PASS=<your_server_password>
set SERVER_HOST=<your_server_ip>
:: Jellyfin settings
set JF_HOST=http://<your_server_ip>:8096
set JF_API_KEY=<your_jellyfin_api_key>
:: -----------------------------
:: ✅ List of channels (YouTube handle without @)
:: -----------------------------
set CHANNELS=CheapPickle GoofyGang Wallibear jordanmatter tinymacdude

if not exist "%LOCAL%" mkdir "%LOCAL%"

:loop
echo ==============================
echo Checking for new videos...
echo ==============================

:: -----------------------------
:: ✅ Download latest video per channel (all into one folder)
:: -----------------------------
for %%C in (%CHANNELS%) do (
    echo Processing %%C...
    python -m yt_dlp -o "%LOCAL%\%%(title)s.%%(ext)s" -f "bestvideo+bestaudio/best" --merge-output-format mp4 --playlist-end 1 --download-archive "%ARCHIVE%" --match-filter "duration > 60" --ignore-errors "https://www.youtube.com/@%%C/videos"
)

:: -----------------------------
:: ✅ Upload all mp4s to server and delete locally after upload
:: -----------------------------
echo Checking for mp4 files to upload...

set HAS_FILES=0
for %%F in ("%LOCAL%\*.mp4") do set HAS_FILES=1

if !HAS_FILES!==1 (
    echo Uploading all mp4 files...

    set WINSCP_SCRIPT=%TEMP%\winscp_upload.txt

    (
        echo open sftp://%SERVER_USER%:%SERVER_PASS%@%SERVER_HOST%
        echo option batch continue
        echo option confirm off
        echo put "%LOCAL%\*.mp4" %REMOTE_BASE%
        echo exit
    ) > "!WINSCP_SCRIPT!"

    %WINSCP% /script="!WINSCP_SCRIPT!"
    del "!WINSCP_SCRIPT!"

    :: Delete local mp4 files after upload
    for %%F in ("%LOCAL%\*.mp4") do (
        del /f /q "%%F"
        echo Deleted: %%F
    )
) else (
    echo No mp4 files found to upload.
)

:: -----------------------------
:: ✅ Delete leftover webm files
:: -----------------------------
del /q "%LOCAL%\*.webm" 2>nul

:: -----------------------------
:: ✅ Empty recycle bin
:: -----------------------------
echo Emptying recycle bin...
powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"

:: -----------------------------
:: ✅ Trigger Jellyfin library scan
:: -----------------------------
echo Triggering Jellyfin library scan...
curl -X POST "%JF_HOST%/Library/Refresh?api_key=%JF_API_KEY%"

echo ==============================
echo Waiting 30 minutes...
echo ==============================
timeout /t 1800
goto loop
