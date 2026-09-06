# PentagonSetup

Tool for debloating and setting up Windows.

> Modifies system settings: removes apps, changes services, registry, DNS
> and the active power plan. Review the scripts, and prefer a fresh restore
> point. Use at your own risk.

I run these scripts on every Windows system I touch. Best run right after a
fresh Windows 10 or 11 install, before you pile on your own apps and
settings. Works on an existing setup too, but a clean start is the ideal
time.

Before you run: don't touch your mouse or keyboard while the script is running.
A restart is highly recommended once the script finishes; several changes
(debloat, services, update policy, power plan) only fully take effect after a
reboot.

## Quick run

    irm https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main/pentagon-setup.ps1 | iex

Or the short link:

    irm tinyurl.com/pentagonsetup | iex

With options:

    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main/pentagon-setup.ps1))) -DryRun

From a local checkout:

    .\pentagon-setup.ps1        # or double-click pentagon-setup.bat

## What it does

| # | Step | Source |
|---|------|--------|
| 1 | Win11Debloat - default mode, silent | fetched live ([raphire/win11debloat](https://github.com/raphire/win11debloat)) |
| 2 | Winutil - applies my `winutil-config.json` | fetched live ([christitustech/winutil](https://github.com/christitustech/winutil)) |
| 3 | Windows Update "Recommended" profile - defer feature 365d / quality 4d, no driver offers, no auto-reboot | clean-room implementation |
| 4 | Cloudflare DNS + DoH on every active adapter | built-in |
| 5 | Ultimate Performance power plan | built-in |
| 6 | O&O ShutUp10++ - applies my `ooshutup10.cfg` silently | fresh-downloaded each run, auto-deleted ([O&O Software](https://www.oo-software.com/en/shutup10)) |

One UAC prompt total. The remote tools are always the latest version.

For CTT and O&O ShutUp I used my own preferences FYI - swap them out if you
want (see Configuration).

## Switches

`-DryRun` `-SkipDebloat` `-SkipWinutil` `-SkipUpdateProfile` `-SkipDns`
`-SkipPowerPlan` `-SkipShutup` `-KeepCache`

- `-DryRun` prints exactly what would run and changes nothing.
- `-KeepCache` keeps the download cache even on success.

## Configuration

Both config files are plain tool exports - swap in your own:

- `winutil-config.json` - exported from Winutil (Config tab, Export)
- `ooshutup10.cfg` - exported from O&O ShutUp10++ (File, Save settings as)

## Cleanup behavior

- One-liner runs download to a local cache and **deletes it on success** -
  nothing is left behind.
- A failed run keeps its logs for debugging (the path is printed).
- Local checkouts are never touched; logs live in `logs\`.

## Requirements

- Windows 10 or 11, PowerShell 5.1 (built in)
- Internet access (the remote tools are fetched at run time)
- Administrator rights (the script elevates itself once)

## Notes

- This repository is public - keep the config files free of secrets/tokens.
- This repo contains no third-party code or binaries - only original code
  and data config files.

## Credits

- [Win11Debloat](https://github.com/raphire/win11debloat) by Raphire - MIT
- [Winutil](https://github.com/christitustech/winutil) by Chris Titus Tech - MIT (invoked live)
- [O&O ShutUp10++](https://www.oo-software.com/en/shutup10) by O&O Software - freeware
