# TakeOwnership feature on Windows
A PowerShell script that adds or removes a **"Take Ownership"** entry from the Windows Explorer right-click context menu — letting you quickly take administrative ownership of files, folders, and drives without manually running `takeown` / `icacls` from the command line.

Based on the registry tweak originally published by Shawn Brink on [TenForums.com](https://www.tenforums.com/tutorials/3841-add-take-ownership-context-menu-windows-10-a.html), packaged here as a single self-elevating script instead of separate `.reg` files.

## Features

- Adds "Take Ownership" to the context menu for:
  - **Files** (any file type)
  - **Folders** (with recursive ownership option)
  - **Drives**
- Automatically excludes sensitive system folders (`C:\Windows`, `C:\Program Files`, `C:\Users`, etc.) from the folder menu entry to prevent accidental misuse.
- Self-elevates via UAC — no need to manually "Run as Administrator."
- Idempotent install — safe to run multiple times without creating duplicate entries.
- One script handles both **install** and **uninstall**.

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.0+
- Administrator rights (the script will prompt for elevation automatically)

## Usage

Clone or download the repo, then from PowerShell:

```powershell
# Add "Take Ownership" to the context menu
.\Manage-TakeOwnershipMenu.ps1 -Install

# Remove "Take Ownership" from the context menu
.\Manage-TakeOwnershipMenu.ps1 -Remove
```

Running the script with no parameters defaults to `-Install`.

You can also just right-click the `.ps1` file and choose **Run with PowerShell**.

> **Note:** If the new entry doesn't appear immediately in File Explorer, restart Explorer (`Stop-Process -Name explorer -Force`) or sign out and back in.

## What it actually does

Once installed, right-clicking a file, folder, or drive and selecting **Take Ownership** runs:

```
takeown /f "<path>" [/r /d y]
icacls "<path>" /grant *S-1-3-4:F /t /c /l
```

- `takeown` — transfers ownership of the object to the current user.
- `icacls ... /grant *S-1-3-4:F` — grants Full Control to the currently logged-in interactive user (`S-1-3-4` is the well-known SID for the current user, not a hardcoded account).
- For folders, you'll be prompted whether to apply the change recursively to subfolders/files.

## Uninstalling

Run the script with `-Remove` to cleanly delete all registry keys it created. No other system settings are touched.

## Disclaimer

This script modifies the Windows Registry (`HKEY_CLASSES_ROOT`) and grants elevated file/folder permissions. Use at your own risk. Always understand what a script does before running it with administrator rights — review [`Manage-TakeOwnershipMenu.ps1`](./Manage-TakeOwnershipMenu.ps1) before use.

## Credits

- Original registry tweak: [Shawn Brink, TenForums.com](https://www.tenforums.com/tutorials/3841-add-take-ownership-context-menu-windows-10-a.html)
- PowerShell wrapper: this repository

## License

MIT — feel free to use, modify, and share.
