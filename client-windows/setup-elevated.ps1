<#
    iroh-ssh: the two steps that need Administrator rights.

    Run from an ELEVATED PowerShell:

        powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\iroh-ssh\setup-elevated.ps1" -WithKeys

    Before running: put YOUR public ssh keys into the $keys array below.

    Step 1 (always)            registers the autostart task.
    Step 2 (only with -WithKeys) installs the public keys for passwordless login.
    Without -WithKeys nothing touches authentication; password login stays as it is.
#>
param([switch]$WithKeys)

$ErrorActionPreference = 'Stop'

$principalNow = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principalNow.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Not elevated. Reopen PowerShell with "Run as administrator".'
}

$base = Join-Path $env:LOCALAPPDATA 'iroh-ssh'
$py   = Join-Path $base 'venv\Scripts\pythonw.exe'
$scr  = Join-Path $base 'serve_launcher.py'
foreach ($p in @($py, $scr)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "missing file: $p" }
}

# ---- 1. autostart -------------------------------------------------------
# Runs as the current user, NOT as SYSTEM: secret.key lives in the user
# profile, and a different profile would mint a new key and silently change
# the endpoint id. LogonType S4U = "run whether the user is logged on or not",
# with no stored password. serve_launcher.py pins USERPROFILE from its own
# path, so the sparse S4U environment cannot make expanduser("~") drift.
$me = "$env:USERDOMAIN\$env:USERNAME"

$settingsArgs = @{
    AllowStartIfOnBatteries    = $true
    DontStopIfGoingOnBatteries = $true
    StartWhenAvailable         = $true
    MultipleInstances          = 'IgnoreNew'   # logon trigger cannot double-start it
    RestartCount               = 999
    RestartInterval            = (New-TimeSpan -Minutes 1)
    ExecutionTimeLimit         = (New-TimeSpan -Seconds 0)   # 0 = no time limit
}

$taskArgs = @{
    TaskName    = 'iroh-ssh serve'
    Description = 'SSH over a self-hosted iroh relay: proxies iroh streams into 127.0.0.1:22'
    Action      = New-ScheduledTaskAction -Execute $py -Argument ('"' + $scr + '"') -WorkingDirectory $base
    Trigger     = @((New-ScheduledTaskTrigger -AtStartup),
                    (New-ScheduledTaskTrigger -AtLogOn -User $me))
    Settings    = New-ScheduledTaskSettingsSet @settingsArgs
    Principal   = New-ScheduledTaskPrincipal -UserId $me -LogonType S4U -RunLevel Limited
    Force       = $true
}

Register-ScheduledTask @taskArgs | Out-Null
Write-Host '[ok] task "iroh-ssh serve" registered (AtStartup + AtLogOn, S4U, restarts on failure)'

# ---- 2. public keys -----------------------------------------------------
if ($WithKeys) {
    # One 'type blob comment' string per key, straight from the client's
    # ~/.ssh/id_*.pub.
    $keys = @(
        # 'ssh-ed25519 AAAA... user@client'
    )

    if (-not $keys.Count) {
        Write-Host '[--] $keys is empty - nothing to install; edit setup-elevated.ps1 first'
    } else {
        # If the user is in the Administrators group, Win-sshd ignores
        # ~\.ssh\authorized_keys and reads this file instead -- the
        # "Match Group administrators" block at the end of %ProgramData%\ssh\sshd_config.
        $akf = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'

        function Get-KeyBlob([string]$line) {
            $parts = @($line -split '\s+' | Where-Object { $_ })
            if ($parts.Count -ge 2) { $parts[1] } else { '' }
        }

        $lines = @()
        if (Test-Path -LiteralPath $akf) {
            $lines = @(Get-Content -LiteralPath $akf | Where-Object { $_.Trim() -ne '' })
            Copy-Item -LiteralPath $akf -Destination "$akf.bak" -Force
            Write-Host "[ok] backed up existing file -> $akf.bak"
        }

        # Match on the key blob, not the trailing comment, so re-running is a no-op
        # and the same key under a different comment is not added twice.
        $have  = @($lines | ForEach-Object { Get-KeyBlob $_ })
        $added = 0
        foreach ($k in $keys) {
            if ($have -notcontains (Get-KeyBlob $k)) { $lines += $k; $added++ }
        }

        # ASCII / UTF-8 without BOM. Set-Content defaults to UTF-16LE on PS 5.1 and
        # sshd then reads the file as garbage without logging anything useful.
        $enc = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($akf, (($lines -join "`n") + "`n"), $enc)
        Write-Host "[ok] $akf : $added key(s) added, $($lines.Count) total"

        # Grant by SID, not by name: localized Windows renames the group
        # ("Administrators" is not stable across locales), the S-1-5-32-544 SID is.
        # sshd ignores the file unless it is SYSTEM + Administrators only, inheritance off.
        & icacls $akf /inheritance:r /grant '*S-1-5-18:F' /grant '*S-1-5-32-544:F' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "icacls failed with exit code $LASTEXITCODE" }
        Write-Host '[ok] ACL reset to SYSTEM + Administrators, inheritance disabled'

        Restart-Service sshd
        Write-Host '[ok] sshd restarted'

        Write-Host ''
        Write-Host '--- verification ---'
        # must start with 73 73 68 ("ssh"), never FF FE (UTF-16 BOM)
        Format-Hex -Path $akf | Select-Object -First 1
        & icacls $akf
    }
} else {
    Write-Host '[--] keys skipped (pass -WithKeys to install them)'
}

Write-Host ''
Write-Host 'After a reboot the endpoint id must be UNCHANGED (see serve.log):'
Write-Host '  Get-Content "$env:LOCALAPPDATA\iroh-ssh\serve.log" -Tail 5'
