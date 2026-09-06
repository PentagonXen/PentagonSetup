# PentagonSetup

One-command Windows setup. I run a debloat pass, apply my Winutil config,
harden privacy with O&O ShutUp10++, then clean up after myself. Nothing left
behind.

> Modifies system settings: removes apps, changes services, registry, DNS
> and the active power plan. Review the scripts, and prefer a fresh restore
> point. Use at your own risk.

## Quick run

    irm tinyurl.com/pentagonsetup | iex

Or the full URL:

    irm https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main/pentagon-setup.ps1 | iex

With options:

    & ([scriptblock]::Create((irm tinyurl.com/pentagonsetup))) -DryRun

From a local checkout:

    .\pentagon-setup.ps1        # or double-click pentagon-setup.bat

## What it does

| # | Step | Source |
|---|------|--------|
| 1 | Win11Debloat - default mode, silent | fetched live ([raphire/win11debloat](https://github.com/raphire/win11debloat)) |
| 2 | Winutil - applies my `winutil-config.json` | fetched live ([christitustech/winutil](https://github.com/christitustech/winutil)) |
| 3 | Windows Update "Recommended" profile - defer feature 365d / quality 4d, no driver offers, no auto-reboot | clean-room implementation |
| 4 | Cloudflare DNS + DoH on every active adapter | built-in |
| 5 | Ultimate Performance power plan (auto-skipped on battery systems) | built-in |
| 6 | O&O ShutUp10++ - applies my `ooshutup10.cfg` silently | fresh-downloaded each run, auto-deleted ([O&O Software](https://www.oo-software.com/en/shutup10)) |

One UAC prompt total. The remote tools are always the latest version.

For CTT and O&O ShutUp I used my own preferences FYI - swap them out if you
want (see Configuration).

## Switches

`-DryRun` `-SkipDebloat` `-SkipWinutil` `-SkipUpdateProfile` `-SkipDns`
`-SkipPowerPlan` `-SkipShutup` `-KeepCache` `-Force`

- `-DryRun` prints exactly what would run and changes nothing.
- `-KeepCache` keeps the download cache even on success.
- `-Force` applies the power plan even on battery systems.

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
