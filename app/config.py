"""Configuración de conexión (config.ini junto al programa). La contraseña NO se guarda."""
import configparser
import os
import sys

DEFAULTS = {"host": "localhost", "port": "3306", "user": "app_cotizaciones", "database": "sistema_cotizaciones"}


def base_dir():
    if getattr(sys, "frozen", False):          # ejecutable generado con PyInstaller
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def resource_dir():
    """Carpeta de recursos empaquetados (PyInstaller --onefile) o la del proyecto."""
    return getattr(sys, "_MEIPASS", base_dir())


def _path():
    return os.path.join(base_dir(), "config.ini")


def load():
    cfg = dict(DEFAULTS)
    parser = configparser.ConfigParser()
    try:
        parser.read(_path(), encoding="utf-8")
        if parser.has_section("conexion"):
            for k in DEFAULTS:
                if parser.has_option("conexion", k):
                    cfg[k] = parser.get("conexion", k)
    except (configparser.Error, OSError):
        pass
    return cfg


def save(cfg):
    parser = configparser.ConfigParser()
    parser["conexion"] = {k: str(cfg.get(k, DEFAULTS[k])) for k in DEFAULTS}
    try:
        with open(_path(), "w", encoding="utf-8") as fh:
            parser.write(fh)
    except OSError:
        pass  # si la carpeta es de solo lectura simplemente no se recuerda
