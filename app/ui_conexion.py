"""Ventana de conexión: prueba de conexión, conexión e instalación del script."""
import os
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

import config
from db import DBError
from sqlrunner import run_script, ScriptError

SCRIPT_NAME = "sistema_cotizaciones_completo.sql"


class ConexionDialog(tk.Toplevel):
    def __init__(self, parent, db):
        super().__init__(parent)
        self.db = db
        self.title("Sistema de Cotizaciones — Conexión a la base de datos")
        self.resizable(False, False)
        self.protocol("WM_DELETE_WINDOW", self.destroy)
        cfg = config.load()
        self.vars = {k: tk.StringVar(value=cfg[k]) for k in ("host", "port", "user", "database")}
        self.vars["password"] = tk.StringVar()

        body = ttk.Frame(self, padding=14)
        body.pack(fill="both", expand=True)
        ttk.Label(body, text="Conexión a MySQL", font=("TkDefaultFont", 13, "bold")).grid(
            row=0, column=0, columnspan=2, sticky="w", pady=(0, 8))
        for i, (key, label, show) in enumerate((("host", "Servidor", ""), ("port", "Puerto", ""),
                                                ("user", "Usuario", ""), ("password", "Contraseña", "•"),
                                                ("database", "Base de datos", "")), start=1):
            ttk.Label(body, text=label).grid(row=i, column=0, sticky="w", pady=3, padx=(0, 10))
            e = ttk.Entry(body, textvariable=self.vars[key], width=30, show=show)
            e.grid(row=i, column=1, sticky="w", pady=3)
            if key == "password":
                self.pw_entry = e
                e.bind("<Return>", lambda _e: self.connect())

        btns = ttk.Frame(body)
        btns.grid(row=6, column=0, columnspan=2, pady=(10, 6), sticky="w")
        ttk.Button(btns, text="Probar conexión", command=self.test).pack(side="left", padx=(0, 6))
        ttk.Button(btns, text="Conectar", command=self.connect).pack(side="left", padx=(0, 6))
        ttk.Button(btns, text="Instalar base de datos…", command=self.install).pack(side="left", padx=(0, 6))
        ttk.Button(btns, text="Salir", command=self.destroy).pack(side="left")

        self.log = tk.Text(body, width=64, height=9, state="disabled", wrap="word", relief="solid", borderwidth=1)
        self.log.grid(row=7, column=0, columnspan=2, sticky="ew")
        self.log.tag_configure("ok", foreground="#1b7f3b")
        self.log.tag_configure("bad", foreground="#b3261e")
        self.log.tag_configure("info", foreground="#444444")

        self.pw_entry.focus_set()
        self.transient_center()
        self.grab_set()

    def transient_center(self):
        self.update_idletasks()
        w, h = self.winfo_reqwidth(), self.winfo_reqheight()
        x = (self.winfo_screenwidth() - w) // 2
        y = (self.winfo_screenheight() - h) // 3
        self.geometry("+%d+%d" % (x, y))

    # ------------------------------------------------------------ utilidades
    def _vals(self):
        v = {k: var.get().strip() for k, var in self.vars.items()}
        v["password"] = self.vars["password"].get()          # la contraseña no se recorta
        return v

    def _log(self, text, tag="info"):
        self.log.configure(state="normal")
        self.log.insert("end", text + "\n", tag)
        self.log.see("end")
        self.log.configure(state="disabled")
        self.update_idletasks()

    def _clear_log(self):
        self.log.configure(state="normal")
        self.log.delete("1.0", "end")
        self.log.configure(state="disabled")

    # ------------------------------------------------------------ acciones
    def test(self):
        v = self._vals()
        self._clear_log()
        self._log("Probando conexión…")
        all_ok = True
        for ok, text in self.db.test_connection(v["host"], v["port"], v["user"], v["password"], v["database"]):
            self._log(("✔ " if ok else "✘ ") + text, "ok" if ok else "bad")
            all_ok = all_ok and ok
        self._log("\nRESULTADO: " + ("conexión exitosa." if all_ok else "la prueba encontró problemas."),
                  "ok" if all_ok else "bad")

    def connect(self):
        v = self._vals()
        try:
            self.db.connect(v["host"], v["port"], v["user"], v["password"], v["database"])
            self.db.rows("sp_prueba_conexion")
        except DBError as e:
            self.db.close()
            self._clear_log()
            self._log("✘ " + str(e), "bad")
            messagebox.showerror("No se pudo conectar", str(e), parent=self)
            return
        config.save(v)
        self.destroy()

    def _find_script(self):
        for folder in (config.base_dir(), os.path.join(config.base_dir(), "sql"), config.resource_dir(), os.getcwd()):
            path = os.path.join(folder, SCRIPT_NAME)
            if os.path.isfile(path):
                return path
        return filedialog.askopenfilename(parent=self, title="Seleccione el script %s" % SCRIPT_NAME,
                                          filetypes=[("Script SQL", "*.sql"), ("Todos", "*.*")])

    def install(self):
        v = self._vals()
        if not messagebox.askyesno(
                "Instalar base de datos",
                "Se ELIMINARÁ y volverá a crear la base de datos 'sistema_cotizaciones' con el esquema, "
                "procedimientos, triggers y datos de prueba.\n\n¿Desea continuar?", icon="warning", parent=self):
            return
        path = self._find_script()
        if not path:
            return
        self._clear_log()
        try:
            with open(path, encoding="utf-8-sig") as fh:
                text = fh.read()
            self._log("Leyendo %s" % path)
            self.db.connect_server_only(v["host"], v["port"], v["user"], v["password"])
            last = [0]

            def progress(i, total):
                if i == total or i - last[0] >= 15:
                    last[0] = i
                    self._log("Ejecutando sentencias… %d / %d" % (i, total))

            total = run_script(self.db.conn, text, progress)
            self._log("✔ Base de datos instalada (%d sentencias)." % total, "ok")
            messagebox.showinfo("Instalación completa",
                                "La base de datos se instaló correctamente.\nAhora pulse 'Conectar'.", parent=self)
        except ScriptError as e:
            self._log("✘ Falló la sentencia %d: %s…\n   %s" % (e.index, e.snippet, e.original), "bad")
            messagebox.showerror("Error al instalar", "Falló la sentencia %d.\n\n%s" % (e.index, e.original), parent=self)
        except DBError as e:
            self._log("✘ " + str(e), "bad")
            messagebox.showerror("Error al instalar", str(e), parent=self)
        except OSError as e:
            self._log("✘ No se pudo leer el script: %s" % e, "bad")
        finally:
            self.db.close()
