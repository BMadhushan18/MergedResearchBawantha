@echo off
echo Installing dependencies...
pip install -r requirements.txt
echo.
echo Opening port in Windows Firewall (allows Android device connections)...
netsh advfirewall firewall delete rule name="Smart Construction Backend Port 8004" >nul 2>&1
netsh advfirewall firewall add    rule name="Smart Construction Backend Port 8004" dir=in action=allow protocol=TCP localport=8004
echo.
echo Starting Smart Construction Backend on port 8004...
echo   API base : http://0.0.0.0:8004/
echo   Health   : http://localhost:8004/health
echo.
python app.py
