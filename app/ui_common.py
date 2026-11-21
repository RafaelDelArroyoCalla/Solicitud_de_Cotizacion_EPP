"""Componentes de interfaz reutilizables (Tkinter estándar, sin frameworks)."""
import tkinter as tk
from tkinter import ttk, messagebox

from db import DBError, to_text


def guard(parent, func, *args, **kwargs):
    """Ejecuta func y muestra el error de BD en un cuadro de diálogo.
    Devuelve (True, resultado) o (False, None)."""
    try:
        return True, func(*args, **kwargs)
    except DBError as e:
        messagebox.showerror("No se pudo completar la operación", str(e), parent=parent)
        return False, None


class LookupCombo(ttk.Combobox):
    """Combo de solo lectura que maneja pares (id, texto)."""

    def __init__(self, parent, width=40, **kw):
        super().__init__(parent, state="readonly", width=width, **kw)
        self._ids = []

    def set_options(self, options):
        """options: lista de (id, texto)."""
        self._ids = [str(o[0]) for o in options]
        self["values"] = [o[1] for o in options]

    def get_id(self):
        idx = self.current()
        if idx is None or idx < 0 or idx >= len(self._ids):
            return ""
        return self._ids[idx]

    def set_id(self, value):
        value = "" if value is None else str(value)
        if value in self._ids:
            self.current(self._ids.index(value))
        else:
            self.set("")

    def clear(self):
        self.set("")


def make_tree(parent, columns, height=10):
    """columns: lista de (clave, encabezado, ancho). Devuelve (frame, tree)."""
    frame = ttk.Frame(parent)
    tree = ttk.Treeview(frame, columns=[c[0] for c in columns], show="headings", height=height,
                        selectmode="browse")
    for key, head, width in columns:
        tree.heading(key, text=head)
        tree.column(key, width=width, minwidth=50, anchor="w")
    vs = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
    hs = ttk.Scrollbar(frame, orient="horizontal", command=tree.xview)
    tree.configure(yscrollcommand=vs.set, xscrollcommand=hs.set)
    tree.grid(row=0, column=0, sticky="nsew")
    vs.grid(row=0, column=1, sticky="ns")
    hs.grid(row=1, column=0, sticky="ew")
    frame.rowconfigure(0, weight=1)
    frame.columnconfigure(0, weight=1)
    tree.tag_configure("baja", foreground="#8a8a8a")
    return frame, tree


def cell_text(key, value):
    if key == "Activo":
        return "Sí" if value in (1, True, "1") else "Baja"
    return to_text(value)


def fill_tree(tree, rows, keys):
    """Rellena el Treeview; el iid de cada fila es su índice en `rows`."""
    tree.delete(*tree.get_children())
    for i, row in enumerate(rows):
        tags = ("baja",) if row.get("Activo") in (0, False, "0") else ()
        tree.insert("", "end", iid=str(i), values=[cell_text(k, row.get(k)) for k in keys], tags=tags)


def selected_index(tree):
    sel = tree.selection()
    return int(sel[0]) if sel else None
