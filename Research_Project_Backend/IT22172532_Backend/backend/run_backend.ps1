$ErrorActionPreference = "Continue"

Set-Location $PSScriptRoot

"Starting backend at $(Get-Date -Format o)" | Out-File -FilePath ".\backend_run.log" -Encoding utf8
& "C:\Users\Gayantha\AppData\Local\Programs\Python\Python310\python.exe" -u ".\app.py" *>> ".\backend_run.log"
