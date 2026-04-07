# Home Movies Web App

A Flask-based web application to browse, upload, and download your home movies collection.

## Features

- 🔐 **Login authentication** – password-protected access
- 📁 **File browser** – navigate folders and see movie files
- ⬆️ **Upload** – drag & drop or click to upload movies (with progress bar)
- ⬇️ **Download** – download any file with one click
- 📂 **Create folders** – organize your movie collection
- 🗑️ **Delete** – remove files or entire folders
- 🎬 **Movie-aware** – recognizes video, subtitle, and image files with appropriate icons
- 📱 **Responsive UI** – works on desktop and mobile (Bootstrap 5 dark theme)

## Deploy on Render

1. Push this repo to GitHub
2. On [Render](https://render.com), create a **Web Service**
3. Set:
   - **Root Directory**: `app`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app --bind 0.0.0.0:$PORT --timeout 600`
4. Add **Environment Variables**:
   | Variable | Description | Example |
   |---|---|---|
   | `APP_USERNAME` | Login username | `dov` |
   | `APP_PASSWORD` | Login password | `your-secure-password` |
   | `SECRET_KEY` | Flask secret key | (any random string) |
   | `MOVIES_ROOT` | Path to movie storage | `/var/data/movies` |
   | `MAX_UPLOAD_GB` | Max upload size in GB | `10` |

## Run Locally

```bash
cd app
pip install -r requirements.txt
python app.py
```

Then open http://localhost:5000. Default login: `admin` / `changeme`
