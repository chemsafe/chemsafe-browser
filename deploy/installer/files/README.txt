ChemSafe Browser
================

This is a placeholder file installed by the test version of the
ChemSafe Browser installer. The actual product wraps BrowserOS with
team-specific customizations.

What this installer includes today:
  - This README
  - A version marker (version.txt)
  - The "ChemSafe Helper" Chrome extension at:
        %LOCALAPPDATA%\ChemSafe\extension\
    To load it into BrowserOS:
      1. Open BrowserOS
      2. Navigate to chrome://extensions
      3. Enable "Developer mode" (top-right toggle)
      4. Click "Load unpacked"
      5. Select the extension folder above
    A "ChemSafe Helper" toolbar button should appear. Click it to see
    the current tab's URL — proves the bundled extension was installed
    correctly by this setup.

What the real installer will eventually contain (next iterations):
  - A check for BrowserOS being installed (download/install if missing)
  - Auto-loading the extension via Chromium's external-extensions registry
  - Pre-configured AI provider settings pointing at the team LLM gateway
  - A user-token entry step during install
  - A launcher shortcut that opens BrowserOS with the team profile
