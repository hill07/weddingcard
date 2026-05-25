@echo off
REM ============================================================
REM  Wedding card publisher
REM  ----------------------------------------------------------
REM  1. Edit wedding-config.json with the details you want.
REM  2. Double-click this file (update.bat).
REM  3. Review the changes when prompted, then type Y to publish.
REM  4. Vercel will redeploy your site in about 1 minute.
REM ============================================================

cd /d "%~dp0"

echo.
echo === Step 1/3: Regenerating bundle from wedding-config.json ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-details.ps1"
if errorlevel 1 (
    echo.
    echo ERROR: Could not regenerate the bundle. Fix the issue above and try again.
    pause
    exit /b 1
)

echo.
echo === Step 2/3: Review what changed ===
git diff --stat wedding-config.json assets/index-C78NrZjj.js
echo.

git diff --quiet wedding-config.json assets/index-C78NrZjj.js
if not errorlevel 1 (
    echo No changes to publish. Did you edit wedding-config.json?
    pause
    exit /b 0
)

set "CONFIRM="
set /p CONFIRM="Publish these changes to your live site? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo Cancelled. Local files were updated but nothing was published.
    echo To undo local changes:  git restore wedding-config.json assets/index-C78NrZjj.js
    pause
    exit /b 0
)

echo.
echo === Step 3/3: Publishing ===
git add wedding-config.json assets/index-C78NrZjj.js
git commit -m "Update wedding details"
if errorlevel 1 (
    echo Commit failed.
    pause
    exit /b 1
)

git push origin main
if errorlevel 1 (
    echo Push failed. Check your internet connection / GitHub credentials.
    pause
    exit /b 1
)

echo.
echo Done! Vercel will redeploy in about 1 minute.
echo Live site: https://weddingcard-roan.vercel.app
echo.
pause
