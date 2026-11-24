@echo off
rem Abre el banco de pruebas de la pierna Klann en Edge (Web Serial necesita localhost)
cd /d "%~dp0"
start "Servidor Klann" /min "C:\Users\Roger\AppData\Local\Programs\Python\Python313\python.exe" -m http.server 8766 --bind 127.0.0.1
timeout /t 2 /nobreak >nul
start msedge http://localhost:8766
