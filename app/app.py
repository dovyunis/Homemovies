import os
import secrets
from pathlib import Path
from flask import (
    Flask, render_template, request, redirect, url_for,
    flash, send_from_directory, abort, session, make_response
)
from flask_login import (
    LoginManager, UserMixin, login_user, logout_user,
    login_required, current_user
)
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", secrets.token_hex(32))

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# MOVIES_ROOT is the base directory where movie files are stored.
# On Render (Linux) this will be something like /var/data/movies
# On your Windows machine you could set it to "D:/Movies" etc.
MOVIES_ROOT = os.environ.get("MOVIES_ROOT", os.path.join(os.getcwd(), "movies"))
Path(MOVIES_ROOT).mkdir(parents=True, exist_ok=True)

ALLOWED_EXTENSIONS = {
    "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm",
    "m4v", "mpg", "mpeg", "ts", "vob", "3gp",
    "srt", "sub", "ass", "jpg", "jpeg", "png", "nfo"
}

MAX_CONTENT_LENGTH = int(os.environ.get("MAX_UPLOAD_GB", 10)) * 1024 * 1024 * 1024  # default 10 GB
app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH

# ---------------------------------------------------------------------------
# Themes
# ---------------------------------------------------------------------------
THEMES = {
    "cinema": {
        "name": "🎬 Cinema Night",
        "description": "Classic dark cinema experience",
        "navbar_bg": "linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)",
        "body_bg": "#0f0f1a",
        "card_bg": "rgba(22, 33, 62, 0.9)",
        "accent": "#e94560",
        "accent_hover": "#ff6b81",
        "text": "#eee",
        "icon": "bi-camera-reels-fill",
        "bg_image": "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=1920&q=80",
    },
    "popcorn": {
        "name": "🍿 Popcorn Party",
        "description": "Fun and warm movie night vibes",
        "navbar_bg": "linear-gradient(135deg, #2d1b00 0%, #4a2c00 100%)",
        "body_bg": "#1a1000",
        "card_bg": "rgba(74, 44, 0, 0.85)",
        "accent": "#f5c518",
        "accent_hover": "#ffd740",
        "text": "#fff",
        "icon": "bi-film",
        "bg_image": "https://images.unsplash.com/photo-1585647347483-22b66260dfff?w=1920&q=80",
    },
    "retro": {
        "name": "📺 Retro TV",
        "description": "Vintage television nostalgia",
        "navbar_bg": "linear-gradient(135deg, #1b2838 0%, #2a3f54 100%)",
        "body_bg": "#0d1b2a",
        "card_bg": "rgba(27, 40, 56, 0.9)",
        "accent": "#00d4aa",
        "accent_hover": "#00ffcc",
        "text": "#c0d0e0",
        "icon": "bi-tv-fill",
        "bg_image": "https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=1920&q=80",
    },
    "horror": {
        "name": "🧛 Horror Night",
        "description": "Spooky dark atmosphere",
        "navbar_bg": "linear-gradient(135deg, #1a0000 0%, #330000 100%)",
        "body_bg": "#0a0000",
        "card_bg": "rgba(51, 0, 0, 0.85)",
        "accent": "#ff0033",
        "accent_hover": "#ff3355",
        "text": "#ccaaaa",
        "icon": "bi-lightning-fill",
        "bg_image": "https://images.unsplash.com/photo-1509248961406-689250585460?w=1920&q=80",
    },
    "scifi": {
        "name": "🚀 Sci-Fi",
        "description": "Futuristic space adventure",
        "navbar_bg": "linear-gradient(135deg, #0a0a2a 0%, #1a0a3a 100%)",
        "body_bg": "#05051a",
        "card_bg": "rgba(26, 10, 58, 0.85)",
        "accent": "#7b2ff7",
        "accent_hover": "#9d5cff",
        "text": "#d0c0ff",
        "icon": "bi-stars",
        "bg_image": "https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=1920&q=80",
    },
    "family": {
        "name": "👨‍👩‍👧‍👦 Family Time",
        "description": "Warm and cozy for family movies",
        "navbar_bg": "linear-gradient(135deg, #1a3c34 0%, #2d5a47 100%)",
        "body_bg": "#0f2318",
        "card_bg": "rgba(45, 90, 71, 0.85)",
        "accent": "#4caf50",
        "accent_hover": "#69c56d",
        "text": "#d0ecd0",
        "icon": "bi-house-heart-fill",
        "bg_image": "https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1920&q=80",
    },
}
DEFAULT_THEME = "cinema"


def get_current_theme():
    theme_id = request.cookies.get("theme", DEFAULT_THEME)
    if theme_id not in THEMES:
        theme_id = DEFAULT_THEME
    return theme_id, THEMES[theme_id]


@app.context_processor
def inject_theme():
    theme_id, theme = get_current_theme()
    return {"current_theme_id": theme_id, "current_theme": theme, "all_themes": THEMES}

# ---------------------------------------------------------------------------
# Authentication – simple user store via env vars
# ---------------------------------------------------------------------------
# Set these env vars on Render:
#   APP_USERNAME=youruser
#   APP_PASSWORD=yourpassword
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = "login"
login_manager.login_message_category = "warning"

APP_USERNAME = os.environ.get("APP_USERNAME", "admin")
# On first run, if no password hash exists, we hash the plaintext password
_raw_pw = os.environ.get("APP_PASSWORD", "changeme")
APP_PASSWORD_HASH = generate_password_hash(_raw_pw)


class User(UserMixin):
    def __init__(self, id):
        self.id = id


@login_manager.user_loader
def load_user(user_id):
    if user_id == APP_USERNAME:
        return User(user_id)
    return None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def safe_join_path(base, *parts):
    """Join path parts and ensure result is under base directory."""
    target = Path(base).resolve()
    for p in parts:
        target = (target / p).resolve()
    if not str(target).startswith(str(Path(base).resolve())):
        abort(403)
    return target


def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def get_human_size(size_bytes):
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size_bytes < 1024:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f} PB"


def scan_directory(path):
    """Return sorted lists of (folders, files) in the given path."""
    folders = []
    files = []
    try:
        for entry in sorted(Path(path).iterdir(), key=lambda e: e.name.lower()):
            if entry.name.startswith("."):
                continue
            if entry.is_dir():
                folders.append({
                    "name": entry.name,
                })
            elif entry.is_file():
                files.append({
                    "name": entry.name,
                    "size": get_human_size(entry.stat().st_size),
                    "size_bytes": entry.stat().st_size,
                })
    except PermissionError:
        pass
    return folders, files


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("browse"))
    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        if username == APP_USERNAME and check_password_hash(APP_PASSWORD_HASH, password):
            login_user(User(username), remember=True)
            next_page = request.args.get("next")
            return redirect(next_page or url_for("browse"))
        flash("Invalid username or password.", "danger")
    return render_template("login.html")


@app.route("/logout")
@login_required
def logout():
    logout_user()
    flash("You have been logged out.", "info")
    return redirect(url_for("login"))


@app.route("/set-theme/<theme_id>")
@login_required
def set_theme(theme_id):
    if theme_id not in THEMES:
        theme_id = DEFAULT_THEME
    resp = make_response(redirect(request.referrer or url_for("browse")))
    resp.set_cookie("theme", theme_id, max_age=60 * 60 * 24 * 365)
    return resp


@app.route("/")
@app.route("/browse")
@app.route("/browse/<path:subpath>")
@login_required
def browse(subpath=""):
    full_path = safe_join_path(MOVIES_ROOT, subpath)
    if not full_path.exists():
        abort(404)
    if full_path.is_file():
        return send_from_directory(full_path.parent, full_path.name, as_attachment=True)

    folders, files = scan_directory(full_path)

    # Build breadcrumb
    breadcrumbs = [{"name": "Home", "path": ""}]
    if subpath:
        parts = subpath.split("/")
        for i, part in enumerate(parts):
            breadcrumbs.append({
                "name": part,
                "path": "/".join(parts[: i + 1])
            })

    return render_template(
        "browse.html",
        folders=folders,
        files=files,
        subpath=subpath,
        breadcrumbs=breadcrumbs,
    )


@app.route("/upload", methods=["POST"])
@login_required
def upload():
    subpath = request.form.get("subpath", "")
    target_dir = safe_join_path(MOVIES_ROOT, subpath)
    target_dir.mkdir(parents=True, exist_ok=True)

    uploaded_files = request.files.getlist("files")
    count = 0
    for f in uploaded_files:
        if f and f.filename and allowed_file(f.filename):
            filename = secure_filename(f.filename)
            f.save(str(target_dir / filename))
            count += 1

    if count:
        flash(f"Successfully uploaded {count} file(s).", "success")
    else:
        flash("No valid files uploaded.", "warning")

    return redirect(url_for("browse", subpath=subpath))


@app.route("/create-folder", methods=["POST"])
@login_required
def create_folder():
    subpath = request.form.get("subpath", "")
    folder_name = request.form.get("folder_name", "").strip()
    if not folder_name:
        flash("Folder name cannot be empty.", "warning")
        return redirect(url_for("browse", subpath=subpath))

    folder_name = secure_filename(folder_name)
    target = safe_join_path(MOVIES_ROOT, subpath, folder_name)
    target.mkdir(parents=True, exist_ok=True)
    flash(f"Folder '{folder_name}' created.", "success")
    return redirect(url_for("browse", subpath=subpath))


@app.route("/download/<path:subpath>")
@login_required
def download(subpath):
    full_path = safe_join_path(MOVIES_ROOT, subpath)
    if not full_path.is_file():
        abort(404)
    return send_from_directory(full_path.parent, full_path.name, as_attachment=True)


@app.route("/delete", methods=["POST"])
@login_required
def delete():
    subpath = request.form.get("subpath", "")
    filename = request.form.get("filename", "")
    if not filename:
        abort(400)

    full_path = safe_join_path(MOVIES_ROOT, subpath, filename)
    if full_path.is_file():
        full_path.unlink()
        flash(f"Deleted '{filename}'.", "success")
    elif full_path.is_dir():
        import shutil
        shutil.rmtree(full_path)
        flash(f"Deleted folder '{filename}'.", "success")
    else:
        flash("File not found.", "warning")

    return redirect(url_for("browse", subpath=subpath))


# ---------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
