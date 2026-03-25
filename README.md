# 📺 YouTube to Jellyfin Auto-Downloader

Automatically downloads the latest video from a list of YouTube channels and uploads them to your Jellyfin media server via SFTP (WinSCP). After uploading, the local files are deleted and the recycle bin is emptied. The script runs in a loop and checks for new videos every 30 minutes.

---

## ✅ Requirements

- Windows 10 or 11
- [Python 3.x](https://www.python.org/downloads/) (make sure to check **"Add Python to PATH"** during install)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [FFmpeg](https://ffmpeg.org/download.html)
- [WinSCP](https://winscp.net/eng/download.php) (installed to `C:\Program Files (x86)\WinSCP\`)
- A running [Jellyfin](https://jellyfin.org/) server accessible on your local network

---

## 🔧 Installation

### 1. Install Python
Download and install Python from https://www.python.org/downloads/  
During installation, check ✅ **"Add Python to PATH"**

### 2. Install yt-dlp
Open Command Prompt and run:
```
pip install yt-dlp
```

### 3. Install FFmpeg
1. Download FFmpeg from https://ffmpeg.org/download.html
2. Extract the zip and copy the `bin` folder contents (ffmpeg.exe, ffprobe.exe, ffplay.exe) to a folder like `C:\ffmpeg\bin\`
3. Add `C:\ffmpeg\bin` to your system PATH:
   - Search **"Environment Variables"** in the Start menu
   - Click **"Environment Variables"**
   - Under **System variables**, select **Path** → **Edit**
   - Click **New** and add `C:\ffmpeg\bin`
   - Click OK

### 4. Install WinSCP
Download and install WinSCP from https://winscp.net/eng/download.php  
Make sure it installs to the default path: `C:\Program Files (x86)\WinSCP\`

### 5. Set up Jellyfin
- Make sure your Jellyfin server is running and reachable on your local network
- In Jellyfin, create a media library pointed to your `/Youtube/` folder on the server
- Get your Jellyfin API key: **Dashboard → API Keys → + (New Key)**

---

## ⚙️ Configuration

Open the script in Notepad and change the following values at the top:

| Variable | Description | Example |
|---|---|---|
| `LOCAL` | Local folder where videos are temporarily saved | `C:\Users\<yourname>\Videos\JellyFin` |
| `SERVER_USER` | SFTP username on your server | `YourUserName` |
| `SERVER_PASS` | SFTP password on your server | `yourpassword` |
| `SERVER_HOST` | IP address of your server | `192.168.x.x` |
| `REMOTE_BASE` | Remote folder path on the server | `/Youtube/` |
| `JF_HOST` | Jellyfin URL with port | `http://192.168.x.x:8096` |
| `JF_API_KEY` | Your Jellyfin API key | `abc123...` |
| `CHANNELS` | Space-separated YouTube handles (without @) | `YourYoutubeChannels` |

---

## ▶️ Usage

1. Save the script as `youtube_to_jellyfin.bat`
2. Double-click to run it, or run it from Command Prompt
3. It will check for new videos every 30 minutes automatically
4. To stop the script, press `CTRL + C` in the Command Prompt window

---

## 📁 How It Works

1. For each channel in the list, yt-dlp downloads the latest video (if not already downloaded before) into your local `JellyFin` folder
2. All `.mp4` files in that folder are uploaded to `/Youtube/` on your server via WinSCP SFTP
3. After a successful upload, all local `.mp4` and `.webm` files are deleted
4. The Windows Recycle Bin is emptied
5. A Jellyfin library scan is triggered so new videos appear immediately
6. The script waits 30 minutes and repeats

---

## 📝 The Script

```batch
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
```

---

## ⚠️ Notes

- The `archive.txt` file keeps track of already downloaded videos so they are never downloaded twice
- If a channel has no videos tab (e.g. it only has Shorts), yt-dlp will show an error — this is normal and the script continues
- Videos shorter than 60 seconds are skipped (to avoid downloading Shorts)
- The script only downloads the **most recent** video per channel per check

---

## 📄 License

MIT License — free to use and modify.
