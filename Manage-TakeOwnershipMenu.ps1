#Requires -Version 5.0
<#
.SYNOPSIS
    Adds or removes the "Take Ownership" right-click context menu entry in Windows Explorer.

.DESCRIPTION
    Recreates the registry changes from the well-known TenForums "Add Take Ownership to
    Context Menu" tutorial by Shawn Brink, but as a single reusable script instead of two
    separate .reg files.

    Adds/removes context menu entries for:
      - Files (HKCR:\*\shell\TakeOwnership)
      - Folders (HKCR:\Directory\shell\TakeOwnership)
      - Drives  (HKCR:\Drive\shell\runas)

.PARAMETER Install
    Adds the "Take Ownership" context menu entries.

.PARAMETER Remove
    Removes the "Take Ownership" context menu entries.

.EXAMPLE
    .\Manage-TakeOwnershipMenu.ps1 -Install
    .\Manage-TakeOwnershipMenu.ps1 -Remove

.NOTES
    Must be run elevated (as Administrator) because it writes to HKEY_CLASSES_ROOT.
    The script will attempt to self-elevate if not already running as admin.
#>

[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Remove')]
    [switch]$Remove
)

# ------------------------------------------------------------------
# Self-elevate if not running as Administrator
# ------------------------------------------------------------------
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Elevation required. Relaunching as Administrator..." -ForegroundColor Yellow
    $argList = @()
    if ($Install) { $argList += '-Install' }
    if ($Remove)  { $argList += '-Remove' }
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"", $argList
    )
    exit
}

# ------------------------------------------------------------------
# Default to Install if no switch was given
# ------------------------------------------------------------------
if (-not $Install -and -not $Remove) {
    $Install = $true
}

# ------------------------------------------------------------------
# Registry paths used by this script (HKEY_CLASSES_ROOT)
# ------------------------------------------------------------------
$paths = @{
    FileShell      = 'Registry::HKEY_CLASSES_ROOT\*\shell\TakeOwnership'
    FileCommand    = 'Registry::HKEY_CLASSES_ROOT\*\shell\TakeOwnership\command'
    FileRunAs      = 'Registry::HKEY_CLASSES_ROOT\*\shell\runas'
    DirShell       = 'Registry::HKEY_CLASSES_ROOT\Directory\shell\TakeOwnership'
    DirCommand     = 'Registry::HKEY_CLASSES_ROOT\Directory\shell\TakeOwnership\command'
    DriveRunAs     = 'Registry::HKEY_CLASSES_ROOT\Drive\shell\runas'
    DriveCommand   = 'Registry::HKEY_CLASSES_ROOT\Drive\shell\runas\command'
}

function Install-TakeOwnershipMenu {
    Write-Host "Adding 'Take Ownership' context menu entries..." -ForegroundColor Cyan

    # Clean slate: remove any pre-existing entries first
    Remove-TakeOwnershipMenu -Quiet

    # --- Files (*) ---
    New-Item -Path $paths.FileShell -Force | Out-Null
    Set-ItemProperty -Path $paths.FileShell -Name '(Default)' -Value 'Take Ownership'
    Set-ItemProperty -Path $paths.FileShell -Name 'HasLUAShield' -Value ''
    Set-ItemProperty -Path $paths.FileShell -Name 'NoWorkingDirectory' -Value ''
    Set-ItemProperty -Path $paths.FileShell -Name 'NeverDefault' -Value ''

    New-Item -Path $paths.FileCommand -Force | Out-Null
    $fileCmd = 'powershell -windowstyle hidden -command "Start-Process cmd -ArgumentList ''/c takeown /f \"%1\" && icacls \"%1\" /grant *S-1-3-4:F /t /c /l'' -Verb runAs"'
    Set-ItemProperty -Path $paths.FileCommand -Name '(Default)' -Value $fileCmd
    Set-ItemProperty -Path $paths.FileCommand -Name 'IsolatedCommand' -Value $fileCmd

    # --- Folders (Directory) ---
    New-Item -Path $paths.DirShell -Force | Out-Null
    Set-ItemProperty -Path $paths.DirShell -Name '(Default)' -Value 'Take Ownership'
    $appliesTo = 'NOT (System.ItemPathDisplay:="C:\Users" OR System.ItemPathDisplay:="C:\ProgramData" OR System.ItemPathDisplay:="C:\Windows" OR System.ItemPathDisplay:="C:\Windows\System32" OR System.ItemPathDisplay:="C:\Program Files" OR System.ItemPathDisplay:="C:\Program Files (x86)")'
    Set-ItemProperty -Path $paths.DirShell -Name 'AppliesTo' -Value $appliesTo
    Set-ItemProperty -Path $paths.DirShell -Name 'HasLUAShield' -Value ''
    Set-ItemProperty -Path $paths.DirShell -Name 'NoWorkingDirectory' -Value ''
    Set-ItemProperty -Path $paths.DirShell -Name 'Position' -Value 'middle'

    New-Item -Path $paths.DirCommand -Force | Out-Null
    $dirCmd = 'powershell -windowstyle hidden -command "$Y = ($null | choice).Substring(1,1); Start-Process cmd -ArgumentList (''/c takeown /f \"%1\" /r /d '' + $Y + '' && icacls \"%1\" /grant *S-1-3-4:F /t /c /l /q'') -Verb runAs"'
    Set-ItemProperty -Path $paths.DirCommand -Name '(Default)' -Value $dirCmd
    Set-ItemProperty -Path $paths.DirCommand -Name 'IsolatedCommand' -Value $dirCmd

    # --- Drives ---
    New-Item -Path $paths.DriveRunAs -Force | Out-Null
    Set-ItemProperty -Path $paths.DriveRunAs -Name '(Default)' -Value 'Take Ownership'
    Set-ItemProperty -Path $paths.DriveRunAs -Name 'HasLUAShield' -Value ''
    Set-ItemProperty -Path $paths.DriveRunAs -Name 'NoWorkingDirectory' -Value ''
    Set-ItemProperty -Path $paths.DriveRunAs -Name 'Position' -Value 'middle'
    Set-ItemProperty -Path $paths.DriveRunAs -Name 'AppliesTo' -Value 'NOT (System.ItemPathDisplay:="C:\")'

    New-Item -Path $paths.DriveCommand -Force | Out-Null
    $driveCmd = 'cmd.exe /c takeown /f "%1\" /r /d y && icacls "%1\" /grant *S-1-3-4:F /t /c'
    Set-ItemProperty -Path $paths.DriveCommand -Name '(Default)' -Value $driveCmd
    Set-ItemProperty -Path $paths.DriveCommand -Name 'IsolatedCommand' -Value $driveCmd

    Write-Host "Done. 'Take Ownership' is now available in the right-click context menu." -ForegroundColor Green
}

function Remove-TakeOwnershipMenu {
    param([switch]$Quiet)

    if (-not $Quiet) {
        Write-Host "Removing 'Take Ownership' context menu entries..." -ForegroundColor Cyan
    }

    $keysToRemove = @(
        'Registry::HKEY_CLASSES_ROOT\*\shell\TakeOwnership',
        'Registry::HKEY_CLASSES_ROOT\*\shell\runas',
        'Registry::HKEY_CLASSES_ROOT\Directory\shell\TakeOwnership',
        'Registry::HKEY_CLASSES_ROOT\Drive\shell\runas'
    )

    foreach ($key in $keysToRemove) {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $Quiet) {
        Write-Host "Done. Context menu entries removed." -ForegroundColor Green
    }
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
try {
    if ($Install) {
        Install-TakeOwnershipMenu
    }
    elseif ($Remove) {
        Remove-TakeOwnershipMenu
    }

    Write-Host "`nYou may need to restart Explorer or sign out/in for the change to appear everywhere." -ForegroundColor Yellow
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
finally {
    Read-Host "Press Enter to exit"
}
