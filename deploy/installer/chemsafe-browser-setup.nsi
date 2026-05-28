; ChemSafe Browser Setup — minimal NSIS installer for testing the .exe build pipeline.
;
; Compile with:   makensis chemsafe-browser-setup.nsi
; Output:         ChemSafeBrowserSetup.exe (in this directory)
;
; This installer currently just creates a placeholder install folder and registers
; itself in Add/Remove Programs. It does NOT yet install BrowserOS or any
; customizations — that's the next iteration. The point of this version is to
; prove the pipeline works end-to-end (compile → install → uninstall).

!define APP_NAME       "ChemSafe Browser"
!define APP_VERSION    "0.1.0"
!define COMPANY_NAME   "Chemical Safety"
!define INSTALL_DIR    "$LOCALAPPDATA\ChemSafe"

Name        "${APP_NAME}"
OutFile     "ChemSafeBrowserSetup.exe"
InstallDir  "${INSTALL_DIR}"
; user-level install — no admin elevation prompt. Switch to "admin" once we
; need to write into Program Files or the BrowserOS install dir.
RequestExecutionLevel user

; Modern UI 2 — gives us a real wizard instead of the classic 90s look
!include "MUI2.nsh"

!define MUI_ABORTWARNING

; Install pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Uninstall pages
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

; -------------- Install section --------------
Section "Install"
  SetOutPath "$INSTDIR"

  ; Drop a static file from disk into the install dir
  File "files\README.txt"

  ; -------------------------------------------------------------------------
  ; Step 1: Run the bundled upstream BrowserOS installer silently.
  ;
  ; We extract the embedded BrowserOS_installer.exe to a temp dir, run it
  ; with /S (NSIS silent-install flag), then clean up. ExecWait blocks until
  ; the chained installer finishes so we don't race against it.
  ;
  ; If BrowserOS is already installed, its setup will either no-op or
  ; upgrade in place — both are fine outcomes here.
  ; -------------------------------------------------------------------------
  SetOutPath "$TEMP\ChemSafeSetup"
  File "files\BrowserOS_installer.exe"

  DetailPrint "Installing BrowserOS — this may take a minute, please wait..."
  ExecWait '"$TEMP\ChemSafeSetup\BrowserOS_installer.exe" /S' $1

  Delete "$TEMP\ChemSafeSetup\BrowserOS_installer.exe"
  RMDir  "$TEMP\ChemSafeSetup"

  ${If} $1 != 0
    DetailPrint "WARNING: BrowserOS installer exited with code $1. Continuing anyway."
  ${EndIf}

  ; -------------------------------------------------------------------------
  ; Step 2: Drop the bundled Chrome extension folder. The /r flag copies
  ; recursively. SetOutPath redirects into a subdir so the extension lands
  ; at $INSTDIR\extension\ instead of being merged at the root.
  ; -------------------------------------------------------------------------
  SetOutPath "$INSTDIR\extension"
  File /r "files\extension\*.*"
  SetOutPath "$INSTDIR"

  ; Write a dynamic version marker so we can later detect "is this installed?"
  FileOpen  $0 "$INSTDIR\version.txt" w
  FileWrite $0 "${APP_NAME} ${APP_VERSION}$\r$\n"
  FileClose $0

  ; Write the uninstaller exe
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Register in Windows Add/Remove Programs (under "Apps & Features")
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "DisplayName"     "${APP_NAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "DisplayVersion"  "${APP_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "Publisher"       "${COMPANY_NAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "InstallLocation" "$INSTDIR"

  ; Start Menu shortcuts
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\Open Install Folder.lnk" "$INSTDIR"
  CreateShortcut  "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

; -------------- Uninstall section --------------
Section "Uninstall"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\version.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR\extension"
  RMDir  "$INSTDIR"

  Delete "$SMPROGRAMS\${APP_NAME}\Open Install Folder.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
  RMDir  "$SMPROGRAMS\${APP_NAME}"

  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
SectionEnd
