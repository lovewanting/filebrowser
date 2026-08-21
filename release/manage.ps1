<#============================================================================
  File Browser Management Script (PowerShell)
  Usage: .\manage.ps1 [command]
============================================================================#>

param(
  [string]$command = ""
)

#region Configuration
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppName     = "File Browser"
$ExePath     = Join-Path $ScriptDir "filebrowser.exe"
$DbPath      = Join-Path $ScriptDir "filebrowser.db"
$LogPath     = Join-Path $ScriptDir "filebrowser.log"
$LogMaxLines = 10000

# Editable settings
$Port    = 6066
$Address = "0.0.0.0"
$Root    = $env:USERPROFILE
#endregion

#region Helpers
function Get-AppProcess {
  Get-Process -Name "filebrowser" -ErrorAction SilentlyContinue
}

function Write-Info  ($msg) { Write-Host " $msg" -ForegroundColor Cyan }
function Write-Ok    ($msg) { Write-Host " $msg" -ForegroundColor Green }
function Write-Err   ($msg) { Write-Host " $msg" -ForegroundColor Red }
function Write-Line  ($msg) { Write-Host " $msg" }

function Test-Exe {
  if (-not (Test-Path $ExePath)) {
    Write-Err "Error: filebrowser.exe not found in $ScriptDir"
    Write-Line "       Place manage.bat and manage.ps1 in the same directory as filebrowser.exe"
    exit 1
  }
}

function Get-Args {
  @("--address", $Address, "--port", "$Port", "--root", $Root, "--database", $DbPath)
}

function Get-Timestamp {
  Get-Date -Format "HH:mm:ss"
}
#endregion

#region Commands
function Show-Usage {
  Write-Line ""
  Write-Line " $AppName Management Script"
  Write-Line ""
  Write-Line " Usage: manage.bat [command]"
  Write-Line ""
  Write-Line " Commands:"
  Write-Line "   start     Start server (background)"
  Write-Line "   stop      Stop server"
  Write-Line "   restart   Restart server"
  Write-Line "   status    Check server status"
  Write-Line "   console   Run in foreground (Ctrl+C to stop)"
  Write-Line "   help      Show this help"
  Write-Line ""
  Write-Line " Examples:"
  Write-Line "   manage.bat start"
  Write-Line "   manage.bat status"
  Write-Line ""
}

function Start-Service {
  param([switch]$Quiet)
  Test-Exe

  $proc = Get-AppProcess
  if ($proc) {
    Write-Err "Error: $AppName is already running (PID $($proc.Id))"
    Write-Line "       Use 'manage.bat stop' first, or 'manage.bat restart'"
    if (-not $Quiet) { pause }
    exit 1
  }

  if (-not $Quiet) {
    Write-Info "[$(Get-Timestamp)] Starting $AppName ..."
    Write-Line "  Address: http://$Address`:$Port"
    Write-Line "  Root:    $Root"
    Write-Line "  DB:      $DbPath"
    Write-Line "  Log:     $LogPath"
    Write-Line ""
  }

  $args = Get-Args
  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $ExePath
  $pinfo.Arguments = ($args -join " ")
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError = $true
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow = $true
  $pinfo.WorkingDirectory = $ScriptDir

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $pinfo
  $null = $proc.Start()

  # Write stdout/stderr to log file
  $logStream = [System.IO.StreamWriter]::new($LogPath, $true)
  $null = $proc.OutputDataReceived.Add({
    param($s, $e)
    if ($e.Data) { $logStream.WriteLine($e.Data); $logStream.Flush() }
  })
  $null = $proc.ErrorDataReceived.Add({
    param($s, $e)
    if ($e.Data) { $logStream.WriteLine($e.Data); $logStream.Flush() }
  })
  $proc.BeginOutputReadLine()
  $proc.BeginErrorReadLine()

  # Trim log if too large
  if ((Get-Item $LogPath -ErrorAction SilentlyContinue).Length -gt 1MB) {
    $content = Get-Content $LogPath -Tail $LogMaxLines
    $content | Set-Content $LogPath
  }

  Start-Sleep -Seconds 2
  $proc2 = Get-AppProcess
  if ($proc2) {
    Write-Ok "OK: $AppName started successfully"
    Write-Line "    http://$Address`:$Port"
  } else {
    Write-Err "Error: Failed to start, check log: $LogPath"
    if (Test-Path $LogPath) { Get-Content $LogPath -Tail 10 }
    if (-not $Quiet) { pause }
    exit 1
  }
}

function Stop-Service {
  Write-Info "[$(Get-Timestamp)] Stopping $AppName ..."

  $proc = Get-AppProcess
  if (-not $proc) {
    Write-Ok "OK: $AppName is not running"
    return
  }

  # Try graceful stop first
  $proc.CloseMainWindow() | Out-Null
  $proc | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue | Out-Null

  # Force kill if still running
  $proc2 = Get-AppProcess
  if ($proc2) {
    $proc2 | Stop-Process -Force
    $proc2 | Wait-Process -Timeout 3 -ErrorAction SilentlyContinue | Out-Null
  }

  Write-Ok "OK: $AppName stopped"
}

function Show-Status {
  Write-Line ""
  Write-Line ("=" * 35)
  Write-Line " $AppName Status"
  Write-Line ("=" * 35)
  Write-Line ""

  $proc = Get-AppProcess
  if ($proc) {
    Write-Ok "  Status: Running"
    Write-Line "  PID:    $($proc.Id)"

    # Check port
    $conn = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq "Listen" } |
            Select-Object -First 1
    if ($conn) {
      Write-Line "  Port:   $Address`:$Port"
    }

    Write-Line ""
    Write-Line "  URL: http://$Address`:$Port"
  } else {
    Write-Err "  Status: Not running"
  }

  Write-Line ""
  Write-Line "  Executable: $ExePath"
  Write-Line "  Database:   $DbPath"
  Write-Line "  Log file:   $LogPath"
  if (Test-Path $LogPath) {
    $size = (Get-Item $LogPath).Length
    if ($size -gt 1MB) {
      Write-Line "  Log size:   $('{0:N1}' -f ($size / 1MB)) MB"
    } else {
      Write-Line "  Log size:   $('{0:N1}' -f ($size / 1KB)) KB"
    }
    Write-Line ""
    Write-Line "  Last 5 lines of log:"
    Write-Line "  " + ("-" * 35)
    Get-Content $LogPath -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Line "  $_" }
    Write-Line "  " + ("-" * 35)
  }
  Write-Line ""
}

function Start-Console {
  Test-Exe
  $proc = Get-AppProcess
  if ($proc) {
    Write-Err "Error: $AppName is already running in background (PID $($proc.Id))"
    Write-Line "       Use 'manage.bat stop' first"
    exit 1
  }
  Write-Info "[$(Get-Timestamp)] Starting $AppName in foreground (Ctrl+C to stop)"
  Write-Line ""

  $args = Get-Args
  & $ExePath $args
}
#endregion

#region Main
switch ($command) {
  ""        { Show-Usage }
  "start"   { Start-Service }
  "stop"    { Stop-Service }
  "restart" { Stop-Service; Start-Sleep 1; Start-Service }
  "status"  { Show-Status }
  "console" { Start-Console }
  "help"    { Show-Usage }
  default   {
    Write-Err "Unknown command: $command"
    Show-Usage
    exit 1
  }
}
#endregion