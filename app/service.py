"""
Home Movies - Windows Service
Run as: python service.py install
        python service.py start
        python service.py stop
        python service.py remove
"""
import os
import sys
import subprocess

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
    _svc_description_ = "Home Movies - browse, upload, and download movies via web browser"

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.stop_event = win32event.CreateEvent(None, 0, 0, None)
        self.process = None

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.stop_event)
        if self.process:
            self.process.terminate()

    def SvcDoRun(self):
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_, "")
        )
        self.main()

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

        # Start Flask app
        self.process = subprocess.Popen(
            [python_exe, app_py],
            cwd=app_dir,
            env=env,
        )

        # Wait for stop signal
        win32event.WaitForSingleObject(self.stop_event, win32event.INFINITE)

        # Stop Flask
        if self.process:
            self.process.terminate()
            self.process.wait(timeout=10)


if __name__ == "__main__":
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(HomeMoviesService)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(HomeMoviesService)
