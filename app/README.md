# Home Movies Web App

A Flask-based web application to browse, upload, and download your home movies collection.

## Features

- 🔐 **Login authentication** – password-protected access
- � **Windows drive browsing** – see all drives (C:\, D:\, E:\) and browse any folder
- �📁 **File browser** – navigate folders and see movie files
- ⬆️ **Upload** – drag & drop or click to upload movies (with progress bar)
- ⬇️ **Download** – download any file with one click
- 📂 **Create folders** – organize your movie collection
- 🗑️ **Delete** – remove files or entire folders
- 🎬 **6 Movie themes** – Cinema Night, Popcorn Party, Retro TV, Horror Night, Sci-Fi, Family Time
- 📱 **Responsive UI** – works on desktop and mobile

## Run on Windows (Recommended)

This is the best way to use the app — it runs on your Windows PC and lets you browse all your drives.

### Quick Start:
1. Install [Python](https://www.python.org/downloads/) (check "Add Python to PATH")
2. Clone or download this repo to your Windows PC
3. Edit `run_windows.bat` to set your username and password
4. Double-click `run_windows.bat`
5. Open `http://localhost:5000` in your browser

### Manual Start:
```bash
cd app
pip install -r requirements.txt
set APP_USERNAME=youruser
set APP_PASSWORD=yourpassword
python app.py
```

### Environment Variables:
| Variable | Description | Default |
|---|---|---|
| `APP_USERNAME` | Login username | `admin` |
| `APP_PASSWORD` | Login password | `changeme` |
| `SECRET_KEY` | Flask secret key | random |
| `BROWSE_MODE` | `drives` (Windows) or `folder` (Linux) | auto-detected |
| `ALLOWED_DRIVES` | Restrict drives shown (e.g., `C,D,E`) | all drives |
| `MOVIES_ROOT` | Root folder (folder mode only) | `./movies` |

## Access from Outside Your Network

To access your movies from the internet, you can use:
- **Cloudflare Tunnel** (free) – `cloudflared tunnel`
- **ngrok** (free) – `ngrok http 5000`
- **Port forwarding** on your router (port 5000)

## Deploy on Render (Cloud)

If you prefer cloud hosting (no Windows drive access):
1. Set **Root Directory**: `app`
2. **Build Command**: `pip install -r requirements.txt`
3. **Start Command**: `gunicorn app:app --bind 0.0.0.0:$PORT --timeout 600`
