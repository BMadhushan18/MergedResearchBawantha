# OpenCV Component Split

This workspace has two separate parts:

- `backend/` runs the Flask API that removes small connected components.
- `frontend/` contains the standalone HTML UI that uploads images to the backend.

## Run backend

```powershell
cd c:\Users\Gayantha\Downloads\files\textRemoving\backend
c:/Users/Gayantha/Downloads/files/.venv/Scripts/python.exe app.py
```

## Run frontend

```powershell
cd c:\Users\Gayantha\Downloads\files\textRemoving\frontend
c:/Users/Gayantha/Downloads/files/.venv/Scripts/python.exe -m http.server 8080
```

Then open `http://localhost:8080` in the browser.

The frontend calls the backend at `http://127.0.0.1:8010`.
