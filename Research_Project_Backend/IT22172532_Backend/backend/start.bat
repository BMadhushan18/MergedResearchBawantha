@echo off
echo Installing dependencies...
pip install -r requirements.txt
echo.
echo Opening port in Windows Firewall (allows Android device connections)...
netsh advfirewall firewall delete rule name="Smart Construction Backend Port 8008" >nul 2>&1
netsh advfirewall firewall add    rule name="Smart Construction Backend Port 8008" dir=in action=allow protocol=TCP localport=8008
echo.
echo Starting Smart Construction Backend on port 8008...
echo   API base : http://0.0.0.0:8008/
echo   Health   : http://localhost:8008/health
echo.
python app.py
