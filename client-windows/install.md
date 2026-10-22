# Target machine: Windows 10/11 (OpenSSH Server, python 3.10+)

The same `serve 22` as on Linux, but autostart is a scheduled task instead
of systemd. The NodeId is stable as long as
`%USERPROFILE%\.config\iroh-ssh\secret.key` survives.

## Installation

```powershell
# 0. sshd: OpenSSH Server installed and running
#    (Settings -> Apps -> Optional features; the sshd service = Running).
#    iroh-ssh proxies into 127.0.0.1:22 -- nothing to change there.

# 1. files into %LOCALAPPDATA%\iroh-ssh\:
#    irohssh.py (repository root), serve_launcher.py, setup-elevated.ps1
python -m venv "$env:LOCALAPPDATA\iroh-ssh\venv"
& "$env:LOCALAPPDATA\iroh-ssh\venv\Scripts\pip.exe" install iroh==1.1.0

# 2. config: the relay token (the access.shared_token value from the relay
#    config)
mkdir ~\.config\iroh-ssh
'<relay-token>' | Set-Content ~\.config\iroh-ssh\token
# secret.key is created on first run; do not lose it -- the NodeId is tied
# to it.

# 3. autostart registration (and, optionally, ssh keys) -- from an ELEVATED
#    PowerShell; put your keys into $keys inside the script first:
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\iroh-ssh\setup-elevated.ps1" -WithKeys
```

## Why it is built this way, not just "a boot task"

- The task runs as the current user (S4U, no stored password), NOT as
  SYSTEM: secret.key lives in the user profile, and a different profile
  would mint a new key and silently change the NodeId. That is exactly why
  `serve_launcher.py` pins `USERPROFILE` from its own path.
- `pythonw` gives the process no console -> `serve_launcher.py` redirects
  stdout/stderr into `serve.log` (rotated at 1 MB -> `serve.log.1`).
- Login keys: for a user in the Administrators group, Win-sshd ignores
  `~\.ssh\authorized_keys` and reads
  `C:\ProgramData\ssh\administrators_authorized_keys`; the script writes it
  as UTF-8 without a BOM and sets the ACL to SYSTEM+Administrators only (by
  SID -- localized group names do not work).

## Verification

```powershell
Get-ScheduledTask -TaskName "iroh-ssh serve" | Get-ScheduledTaskInfo
Get-Content "$env:LOCALAPPDATA\iroh-ssh\serve.log" -Tail 5
```

The `endpoint id` from the log is the machine's NodeId: clients put it into
their ProxyCommand. After a reboot the id must be the same.

## Moving to other hardware keeping the same NodeId

Copy `%USERPROFILE%\.config\iroh-ssh\{secret.key,token}` before the first
run of the task -- the endpoint id then stays the same.
