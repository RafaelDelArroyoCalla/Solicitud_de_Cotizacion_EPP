"""Sistema de Cotizaciones — aplicativo cliente (Entrega 5).
Tkinter + mysql-connector-python. Sin frameworks ni ORM: todo acceso a datos va por procedimientos almacenados."""
import os
import sys
import tkinter as tk
from tkinter import ttk, messagebox

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from db import Database                                   # noqa: E402
from ui_conexion import ConexionDialog                    # noqa: E402
from ui_crud import build_clientes, build_proveedores, build_items, build_especificaciones  # noqa: E402
from ui_cotizaciones import CotizacionesFrame             # noqa: E402
from ui_reportes import ReportesFrame                     # noqa: E402

APP_TITLE = "Sistema de Cotizaciones"


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.withdraw()
        self.db = Database()
        try:
            ttk.Style(self).theme_use("clam")
        except tk.TclError:
            pass
        self.title(APP_TITLE)
        self.geometry("1240x780")
        self.minsize(1000, 640)
        self.protocol("WM_DELETE_WINDOW", self.quit_app)
        if not self.connect():
            self.destroy()
            return
        self.build_main()
        self.deiconify()

    # ------------------------------------------------------------ conexión
    def connect(self):
        dlg = ConexionDialog(self, self.db)
        self.wait_window(dlg)
        return self.db.connected

    def reconnect(self):
        for child in self.winfo_children():
            child.destroy()
        self.withdraw()
        self.db.close()
        if not self.connect():
            self.destroy()
            return
        self.build_main()
        self.deiconify()

    # ------------------------------------------------------------ interfaz
    def build_main(self):
        menu = tk.Menu(self)
        file_menu = tk.Menu(menu, tearoff=0)
        file_menu.add_command(label="Cambiar conexión / Instalar BD…", command=self.reconnect)
        file_menu.add_separator()
        file_menu.add_command(label="Salir", command=self.quit_app)
        menu.add_cascade(label="Archivo", menu=file_menu)
        help_menu = tk.Menu(menu, tearoff=0)
        help_menu.add_command(label="Acerca de", command=lambda: messagebox.showinfo(
            "Acerca de", "Sistema de Cotizaciones\nEntrega 5 — Aplicativo cliente\nPython + Tkinter + MySQL "
                         "(sin frameworks)", parent=self))
        menu.add_cascade(label="Ayuda", menu=help_menu)
        self.config(menu=menu)

        self.status = tk.StringVar(value="Conectado: " + self.db.info)
        ttk.Label(self, textvariable=self.status, relief="sunken", anchor="w", padding=(8, 2)).pack(
            side="bottom", fill="x")

        self.nb = ttk.Notebook(self)
        self.nb.pack(fill="both", expand=True)
        self.tabs = [
            ("Cotizaciones", CotizacionesFrame(self.nb, self.db)),
            ("Clientes", build_clientes(self.nb, self.db)),
            ("Proveedores", build_proveedores(self.nb, self.db)),
            ("Ítems", build_items(self.nb, self.db)),
            ("Especificaciones", build_especificaciones(self.nb, self.db)),
            ("Reportes", ReportesFrame(self.nb, self.db)),
        ]
        for title, frame in self.tabs:
            self.nb.add(frame, text="  %s  " % title)
        self.nb.bind("<<NotebookTabChanged>>", self._on_tab)
        self.tabs[0][1].refresh()

    def _on_tab(self, _e=None):
        frame = self.tabs[self.nb.index("current")][1]
        frame.refresh()                   # datos siempre actualizados al cambiar de pestaña

    def quit_app(self):
        self.db.close()
        self.destroy()


def main():
    app = App()
    try:
        app.mainloop()
    except tk.TclError:
        pass


if __name__ == "__main__":
    main()
