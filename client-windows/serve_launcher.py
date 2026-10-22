"""Windowless entry point for the scheduled task.

pythonw.exe gives the process no console, so sys.stderr is None and irohssh's
log() would write into the void. Point both streams at a file first, then hand
off to irohssh.py unmodified.

Paths are derived from this file's own location and USERPROFILE is pinned
explicitly. Under a Task Scheduler S4U logon the environment is sparse; if
expanduser("~") drifted (e.g. to the systemprofile), irohssh would not find
secret.key, would mint a fresh one, and the endpoint id would silently change.
"""
import os, pathlib, runpy, sys

BASE = pathlib.Path(__file__).resolve().parent   # ...\AppData\Local\iroh-ssh
os.environ["USERPROFILE"] = str(BASE.parents[2])  # ...\Users\<user>

LOG = BASE / "serve.log"
if LOG.exists() and LOG.stat().st_size > 1_000_000:
    LOG.replace(BASE / "serve.log.1")

sys.stdout = sys.stderr = open(LOG, "a", buffering=1, encoding="utf-8", errors="replace")

sys.argv = ["irohssh.py", "serve", "22"]
runpy.run_path(str(BASE / "irohssh.py"), run_name="__main__")
