import os
import secrets
from pathlib import Path
from flask import (
    Flask, render_template, request, redirect, url_for,
    flash, send_from_directory, abort
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
