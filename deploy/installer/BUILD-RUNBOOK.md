# Chromium Build Runbook (Windows, unsigned)

This is the step-by-step to produce an unsigned BrowserOS Windows installer
from source, **after IT has approved the Trend Micro Behavior Monitoring
exclusion for `C:\src\`**.

Do not start this before that exclusion is in place — depot_tools' first-run
bootstrap will be killed by Anti-Ransomware exactly the same way it was
during initial investigation.

## Phase 0 — Confirm IT exclusion is live

Right-click any Trend Micro icon → check current policy or simply re-run
the failing command:

```cmd
cd C:\src\depot_tools
update_depot_tools.bat
```

If it completes without "vpython3.exe is not recognized" and the
Behavior Monitoring log shows no new "Μη εξουσιοδοτημένη κρυπτογράφηση
αρχείων" entries on `cipd_client.exe`, the exclusion is working.

If it still fails, the exclusion isn't deployed yet — wait, don't proceed.

## Phase 1 — Clean the broken bootstrap state

The earlier failed bootstrap left junk in `.cipd_bin\`. Wipe it so depot_tools
starts fresh:

```cmd
rmdir /s /q C:\src\depot_tools\.cipd_bin
rmdir /s /q "%LOCALAPPDATA%\vpython-root.0"
```

Both directories will be re-created automatically on the next gclient call.

## Phase 2 — Bootstrap depot_tools cleanly

```cmd
cd C:\src\depot_tools
gclient --version
```

This triggers the full bootstrap: downloads CIPD client, fetches vpython3,
fetches CPython 3.11, sets up the venv. Takes ~2 minutes. With the AV
exclusion in place, all renames complete and you'll get a real version
string at the end like `gclient.py v0.7`.

Re-confirm everything's in place:
```cmd
where gclient
where vpython3
vpython3 --version
```

## Phase 3 — Set environment variables for the build

These tell the build system where Chromium source will live and what
toolchain to use. From an Administrator PowerShell (one-time):

```powershell
# Where Chromium source will land (will be created in next phase)
[Environment]::SetEnvironmentVariable("CHROMIUM_SRC", "C:\src\chromium\src", "User")

# These should already be set from earlier setup — verify with:
#   echo %DEPOT_TOOLS_WIN_TOOLCHAIN%
#   echo %GYP_MSVS_VERSION%
#   echo %vs2022_install%
# If any are missing, re-set them:
[Environment]::SetEnvironmentVariable("DEPOT_TOOLS_WIN_TOOLCHAIN", "0", "User")
[Environment]::SetEnvironmentVariable("GYP_MSVS_VERSION", "2022", "User")
[Environment]::SetEnvironmentVariable("vs2022_install", "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools", "User")
```

Close + reopen your terminal so env vars propagate.

## Phase 4 — Fetch Chromium source (~35 GB download, 30-60 min)

```cmd
mkdir C:\src\chromium
cd C:\src\chromium
fetch --nohooks chromium
```

`fetch` clones Chromium and its dependencies into `C:\src\chromium\src\`.
Watch for any new Trend Micro popups — if the exclusion is correctly
applied, there should be none. If popups appear, the exclusion may not
cover all the operations and you'll need another IT round.

After fetch completes:
```cmd
cd C:\src\chromium\src
gclient sync --no-history --shallow
gclient runhooks
```

`runhooks` is the part that downloads many additional CIPD-managed tools
(clang, gn, ninja, etc.). Expect another 10-20 min and ~10 GB of extra
downloads. This is where additional AV exclusions would bite if they
weren't comprehensive.

## Phase 5 — Run the unsigned BrowserOS build

The unsigned YAML we prepared in `packages/browseros/build/config/release.windows.unsigned.yaml`
omits the `sign_windows` and `upload` modules so no SSL.com credentials
are needed.

```cmd
cd C:\Users\spyrosvi\PycharmProjects\chemsafe-browser\packages\browseros
browseros build --config build/config/release.windows.unsigned.yaml --chromium-src C:\src\chromium\src
```

This is the 4-8 hour build. It runs in sequence:
1. **clean** — wipes previous build artifacts
2. **git_setup** — verifies Chromium source is at the right commit (pinned in `CHROMIUM_VERSION` file)
3. **download_resources** — fetches third-party resources from R2 (read-only, no creds needed)
4. **resources** — copies BrowserOS resource files (icons, manifests) into Chromium source
5. **bundled_extensions** — downloads default bundled extensions from `cdn.browseros.com`
6. **chromium_replace** — full-file replacements in Chromium source
7. **string_replaces** — text-level patches
8. **series_patches** — ordered series of source patches
9. **patches** — per-file patches from `chromium_patches/`
10. **configure** — runs `gn gen` to produce ninja build files
11. **compile** — runs `autoninja -C out/Default mini_installer` (the long one)
12. **package_windows** — copies `mini_installer.exe` to `dist/` and creates portable zip

Run this overnight or during a long meeting. Your machine will be heavily
loaded for the compile + link phases.

## Phase 6 — Find and verify the output

```cmd
dir C:\Users\spyrosvi\PycharmProjects\chemsafe-browser\packages\browseros\dist
```

Should contain:
- `BrowserOS-<version>-x64-mini_installer.exe` (or similar) — the unsigned Windows installer
- A portable zip alongside it

Run the installer to verify:
```cmd
dist\BrowserOS-<version>-x64-mini_installer.exe
```

Windows SmartScreen will show "Windows protected your PC" — click "More info"
→ "Run anyway". That warning is expected for unsigned binaries and will go
away once we have signing credentials.

## Phase 7 — Wrap your custom Chromium .exe in your NSIS installer

Once Phase 6 produces a working `mini_installer.exe`, replace the upstream
one in our NSIS bundle:

```cmd
copy C:\Users\spyrosvi\PycharmProjects\chemsafe-browser\packages\browseros\dist\BrowserOS-*.exe ^
     C:\Users\spyrosvi\PycharmProjects\chemsafe-browser\deploy\installer\files\BrowserOS_installer.exe

cd C:\Users\spyrosvi\PycharmProjects\chemsafe-browser\deploy\installer
"C:\Program Files (x86)\NSIS\makensis.exe" chemsafe-browser-setup.nsi
```

Now `ChemSafeBrowserSetup.exe` chain-installs **your** custom BrowserOS
build plus the ChemSafe Helper extension, in one wizard.

## Troubleshooting

**Build fails mid-compile with random C++ errors:** usually a toolchain
version mismatch. Check that VS Build Tools 2022 + Windows 11 SDK
(10.0.22621 or .26100) is what Chromium expects for this version. Run
`browseros build --list` to see expected component versions.

**`fetch` runs forever / stalls:** Chromium fetch sometimes hangs on slow
or proxied connections. Cancel (Ctrl+C), run `gclient sync` to resume.

**Link phase OOMs:** the linker peaks at ~12 GB RAM. Close everything
else (Edge, IDEs, Slack). If still OOM, the only fix is more physical
RAM — you have 32 GB which should be plenty.

**Trend Micro fires during build despite the exclusion:** the exclusion
may be path-specific. The build creates intermediate files in
`%TEMP%`, `%LOCALAPPDATA%\vpython-root.0\`, and a few other locations.
Get those added to the exclusion via a follow-up IT ticket.

## Incremental rebuilds after the first

Once the full build succeeds once, subsequent builds skip the slow phases:

```cmd
cd C:\Users\spyrosvi\PycharmProjects\chemsafe-browser\packages\browseros
browseros build --build --package --chromium-src C:\src\chromium\src
```

`--build --package` (no `--setup --prep`) runs only `compile` and
`package_windows` — typically 5-30 minutes depending on what changed.

Pure Chromium-patch changes (`chromium_patches/`) take ~30 min.
BrowserOS resource changes (icons, strings): ~5-15 min.
Agent code changes (`packages/browseros-agent/`): no Chromium rebuild
needed at all — see the agent dev loop separately.
