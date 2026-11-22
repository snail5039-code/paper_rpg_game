@echo off
rem Double-click to run the game. (Godot 4.7.2 installed by winget)
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot not found: %GODOT%
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
