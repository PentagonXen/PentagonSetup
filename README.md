# PentagonSetup

One-command Windows setup: debloat, your tweaks, privacy hardening - then it
cleans up after itself, leaving nothing behind.

## The command (PowerShell)

    irm https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main/pentagon-setup.ps1 | iex

Short link (recommended - survives GitHub renames):

    irm tinyurl.com/pentagonsetup | iex

With options:

    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/PentagonXen/PentagonSetup/main/pentagon-setup.ps1))) -DryRun

Locally (this folder):

    .\pentagon-setup.ps1          # or double-click pentagon-setup.bat

## What it runs

| # | Step | Source |
|---|------|--------|
| 1 | Win11Debloat - default mode, silent | fetched live (raphire/win11debloat) |
| 2 | Winutil - your saved config | fetched live (christitustech/winutil) |
| 2b | Windows Update "Recommended" profile | mirrored from Winutil (MIT) |
| 2c | Cloudflare DNS + DoH on all active adapters | native |
| 2d | Ultimate Performance power plan (skipped on battery) | native |
| 3 | O&O ShutUp10++ - your settings, silent | cached in tools\ (O&O Software) |

One UAC prompt. Remote runs delete their cache, tools and logs on success -
a failed run keeps its logs for debugging (the path is printed).

## Switches

`-DryRun` `-SkipDebloat` `-SkipWinutil` `-SkipUpdateProfile` `-SkipDns`
`-SkipPowerPlan` `-SkipShutup` `-KeepCache` `-Force`

- `-DryRun` prints exactly what would run and changes nothing.
- `-KeepCache` keeps the remote-run cache even on success.
- `-Force` applies the power plan even on battery systems.

## Updating your settings

- `winutil-config.json` - exported from the Winutil GUI (Config tab, Export).
  Re-export anytime and replace this file.
- `ooshutup10.cfg` - exported from O&O ShutUp10 (File, Save settings as).
  Re-export anytime and replace this file.

## If you rename your GitHub account

1. Edit the TinyURL destination (tinyurl.com dashboard) to the new raw URL.
2. Update the URLs in this README and in your `$PROFILE` alias.
3. `git remote set-url origin https://github.com/<new-name>/PentagonSetup.git`

## Notes

- This repo is PUBLIC by design (the one-liner needs anonymous access). The
  config files contain only tweak preferences - NEVER put tokens/secrets in.
- Credits: Win11Debloat (Raphire, MIT), Winutil (Chris Titus Tech, MIT),
  O&O ShutUp10++ (O&O Software, freeware).
