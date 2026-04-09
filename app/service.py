"""
Home Movies - Windows Service
Runs Flask app + Cloudflare Tunnel for internet access.
The public URL is saved to internet_url.txt in the app folder.

Run as: python service.py install
        python service.py start
        python service.py stop
        python service.py remove
"""
import os
import sys
import re
import shutil
import subprocess
import time
import threading

try:
    import win32serviceutil
    import win32service
    import win32event
    import servicemanager
except ImportError:
    print("ERROR: pywin32 is not installed.")
    print("Run: pip install pywin32")
    print("Then: python -m pywin32_postinstall -install")
    sys.exit(1)


class HomeMoviesService(win32serviceutil.ServiceFramework):
    _svc_name_ = "HomeMoviesService"
    _svc_display_name_ = "Home Movies Web App"
    _svc_description_ = "Home Movies - browse and stream movies from anywhere via the internet"

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.stop_event = win32event.CreateEvent(None, 0, 0, None)
        self.flask_process = None
        self.tunnel_process = None

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.stop_event)
        # Kill tunnel first, then Flask
        for proc in [self.tunnel_process, self.flask_process]:
            if proc:
                try:
                    proc.terminate()
                    proc.wait(timeout=10)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass

    def SvcDoRun(self):
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_, "")
        )
        self.main()

    def log_info(self, msg):
        servicemanager.LogInfoMsg(f"[HomeMovies] {msg}")

    def log_error(self, msg):
        servicemanager.LogErrorMsg(f"[HomeMovies] {msg}")

    def capture_tunnel_url(self, app_dir):
        """Read tunnel stderr to find the public URL and save it to a file."""
        url_file = os.path.join(app_dir, "internet_url.txt")
        url_found = False
        try:
            for line in iter(self.tunnel_process.stderr.readline, b""):
                text = line.decode("utf-8", errors="replace").strip()
                # Cloudflare prints the URL like: https://xxx.trycloudflare.com
                match = re.search(r"(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)", text)
                if match and not url_found:
                    public_url = match.group(1)
                    url_found = True
                    self.log_info(f"Internet URL: {public_url}")
                    # Save URL to file
                    with open(url_file, "w") as f:
                        f.write(f"Your Home Movies internet URL:\n")
                        f.write(f"{public_url}\n\n")
                        f.write(f"Login: dov / yunis2026\n\n")
                        f.write(f"NOTE: This URL changes when the service restarts.\n")
                        f.write(f"Check this file again after a reboot.\n")
        except Exception:
            pass

    def main(self):
        # Get the directory where this script lives
        app_dir = os.path.dirname(os.path.abspath(__file__))
        app_py = os.path.join(app_dir, "app.py")
        venv_python = os.path.join(app_dir, "venv", "Scripts", "python.exe")

        # Use venv python if available, otherwise system python
        python_exe = venv_python if os.path.exists(venv_python) else sys.executable

        # Set environment variables
        env = os.environ.copy()
        env["APP_USERNAME"] = env.get("APP_USERNAME", "dov")
        env["APP_PASSWORD"] = env.get("APP_PASSWORD", "yunis2026")
        env["SECRET_KEY"] = env.get("SECRET_KEY", "home-movies-service-key-2026")
        env["PORT"] = env.get("PORT", "5000")

        # --- Step 1: Start Flask app ---
        self.log_info("Starting Flask server...")
        self.flask_process = subprocess.Popen(
            [python_exe, app_py],
            cwd=app_dir,
            env=env,
        )

        # --- Step 2: Start Cloudflare Tunnel ---
        cloudflared_exe = shutil.which("cloudflared")
        if cloudflared_exe:
            # Wait for Flask to be ready
            time.sleep(8)
            self.log_info("Starting Cloudflare tunnel...")
            self.tunnel_process = subprocess.Popen(
                [cloudflared_exe, "tunnel", "--url", "http://localhost:5000"],
                cwd=app_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            # Read tunnel output in a thread to capture the URL
            url_thread = threading.Thread(
                target=self.capture_tunnel_url, args=(app_dir,), daemon=True
            )
            url_thread.start()
        else:
            self.log_error(
                "cloudflared not found! Install it with: winget install Cloudflare.cloudflared  "
                "The app will only be available on localhost:5000"
            )
            # Write a message to the URL file
            url_file = os.path.join(app_dir, "internet_url.txt")
            with open(url_file, "w") as f:
                f.write("Cloudflared is NOT installed.\n\n")
                f.write("Install it with:\n")
                f.write("  winget install Cloudflare.cloudflared\n\n")
                f.write("Then restart the service:\n")
                f.write("  Restart-Service HomeMoviesService\n")

        # Wait for stop signal
        win32event.WaitForSingleObject(self.stop_event, win32event.INFINITE)

        # Stop everything
        for proc in [self.tunnel_process, self.flask_process]:
            if proc:
                try:
                    proc.terminate()
                    proc.wait(timeout=10)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass


if __name__ == "__main__":
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(HomeMoviesService)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(HomeMoviesService)
