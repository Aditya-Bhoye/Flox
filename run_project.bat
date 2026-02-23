@echo off
echo ===================================================
echo   Loan Approval App Launcher
echo ===================================================

echo [1/2] Starting Backend Server...
start "Loan Approval Backend" cmd /k "cd /d e:\LoanApproval\backend && python main.py"

echo Waiting 5 seconds for backend to initialize...
timeout /t 5 /nobreak >nul

echo [2/2] Starting Mobile App...
cd /d e:\LoanApproval\mobile_app
flutter run -d emulator-5554

pause
