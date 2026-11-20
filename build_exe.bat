@echo off
REM Genera dist\SistemaCotizaciones.exe (requiere Python 3.10+ con Tkinter)
python -m pip install -r requirements.txt pyinstaller
pyinstaller --noconfirm --onefile --windowed --name SistemaCotizaciones ^
  --collect-submodules mysql.connector ^
  --add-data "sql\sistema_cotizaciones_completo.sql;." ^
  app\main.py
echo.
echo Listo: dist\SistemaCotizaciones.exe
pause
