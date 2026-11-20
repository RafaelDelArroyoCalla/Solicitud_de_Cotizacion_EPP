"""Pestaña de reportes: 12 consultas (9 con JOIN) ejecutadas mediante procedimientos."""
import csv
import datetime
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

from db import to_text
from ui_common import LookupCombo, guard

ESTADOS = [("", "(Todos)"), ("Pendiente", "Pendiente"), ("Aprobado", "Aprobado"), ("Rechazado", "Rechazado")]

# (título, procedimiento, [(tipo, etiqueta, obligatorio)])
REPORTS = [
    ("R1  Cotizaciones con cliente, proveedor y obra  [JOIN]", "sp_rep_cotizaciones_completas",
     [("estado", "Estado", False), ("fecha", "Desde (AAAA-MM-DD)", False), ("fecha", "Hasta (AAAA-MM-DD)", False)]),
    ("R2  Detalle de una cotización  [JOIN]", "sp_rep_detalle_cotizacion",
     [("cotizacion", "Cotización", True)]),
    ("R3  Monto cotizado por cliente  [JOIN]", "sp_rep_total_por_cliente", []),
    ("R4  Monto cotizado por proveedor y departamento  [JOIN]", "sp_rep_total_por_proveedor", []),
    ("R5  Ítems más cotizados  [JOIN]", "sp_rep_items_mas_cotizados", []),
    ("R6  Comparativo de precios por ítem y proveedor  [JOIN]", "sp_rep_comparativo_precios",
     [("item", "Ítem (vacío = todos)", False)]),
    ("R7  Proveedores por departamento y provincia  [JOIN]", "sp_rep_proveedores_por_departamento", []),
    ("R8  Clientes sin cotizaciones  [LEFT JOIN]", "sp_rep_clientes_sin_cotizaciones", []),
    ("R9  Uso de especificaciones técnicas por área  [JOIN]", "sp_rep_especificaciones_uso", []),
    ("R10 Cotizaciones por estado y moneda", "sp_rep_resumen_por_estado", []),
    ("R11 Cotizaciones por mes", "sp_rep_cotizaciones_por_mes", []),
    ("R12 Bitácora de auditoría (triggers)", "sp_rep_auditoria", []),
]


class ReportesFrame(ttk.Frame):
    def __init__(self, parent, db):
        super().__init__(parent, padding=8)
        self.db = db
        self.getters = []
        self.last_rows = []
        self.last_keys = []
        self._build()

    def _build(self):
        left = ttk.LabelFrame(self, text="Reportes", padding=6)
        left.pack(side="left", fill="y")
        self.listbox = tk.Listbox(left, width=52, height=20, exportselection=False, activestyle="dotbox")
        for r in REPORTS:
            self.listbox.insert("end", r[0])
        self.listbox.pack(fill="y", expand=True)
        self.listbox.bind("<<ListboxSelect>>", self._on_pick)

        right = ttk.Frame(self)
        right.pack(side="left", fill="both", expand=True, padx=(8, 0))
        self.params = ttk.LabelFrame(right, text="Parámetros", padding=6)
        self.params.pack(fill="x")
        bar = ttk.Frame(right)
        bar.pack(fill="x", pady=6)
        ttk.Button(bar, text="Ejecutar reporte", command=self.run).pack(side="left")
        ttk.Button(bar, text="Exportar a CSV", command=self.export).pack(side="left", padx=6)
        self.info = ttk.Label(bar, text="Seleccione un reporte de la lista.")
        self.info.pack(side="left", padx=10)

        holder = ttk.Frame(right)
        holder.pack(fill="both", expand=True)
        self.tree = ttk.Treeview(holder, show="headings", selectmode="browse")
        vs = ttk.Scrollbar(holder, orient="vertical", command=self.tree.yview)
        hs = ttk.Scrollbar(holder, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=vs.set, xscrollcommand=hs.set)
        self.tree.grid(row=0, column=0, sticky="nsew")
        vs.grid(row=0, column=1, sticky="ns")
        hs.grid(row=1, column=0, sticky="ew")
        holder.rowconfigure(0, weight=1)
        holder.columnconfigure(0, weight=1)

        self.listbox.selection_set(0)
        self._on_pick()

    def refresh(self):
        """Recarga las listas desplegables de los parámetros (cotizaciones/ítems nuevos)."""
        self._on_pick()

    # ------------------------------------------------------------ parámetros
    def _on_pick(self, _e=None):
        sel = self.listbox.curselection()
        if not sel:
            return
        _title, _proc, spec = REPORTS[sel[0]]
        for w in self.params.winfo_children():
            w.destroy()
        self.getters = []
        if not spec:
            ttk.Label(self.params, text="Este reporte no requiere parámetros.").pack(anchor="w")
            return
        for kind, label, required in spec:
            row = ttk.Frame(self.params)
            row.pack(fill="x", pady=2)
            ttk.Label(row, text=label + (" *" if required else ""), width=24).pack(side="left")
            if kind == "estado":
                w = LookupCombo(row, width=16)
                w.set_options(ESTADOS)
                w.current(0)
                self.getters.append((label, kind, required, w.get_id))
            elif kind == "fecha":
                var = tk.StringVar()
                w = ttk.Entry(row, textvariable=var, width=16)
                self.getters.append((label, kind, required, var.get))
            elif kind == "cotizacion":
                w = LookupCombo(row, width=60)
                ok, rows = guard(self, self.db.rows, "sp_cotizacion_listar", ("", "", 0))
                w.set_options([(r["Num_solicitud"], "%s — %s (%s)" % (r["Num_solicitud"], r["Cliente"], r["Estado"]))
                               for r in rows] if ok else [])
                self.getters.append((label, kind, required, w.get_id))
            elif kind == "item":
                w = LookupCombo(row, width=60)
                ok, rows = guard(self, self.db.rows, "sp_item_listar", ("", 0))
                opts = [("", "(Todos)")] + [(r["ID_Item"], r["Descripcion_Item"]) for r in rows] if ok else []
                w.set_options(opts)
                w.current(0)
                self.getters.append((label, kind, required, w.get_id))
            w.pack(side="left")

    def _collect(self):
        args = []
        for label, kind, required, getter in self.getters:
            value = (getter() or "").strip()
            if required and not value:
                messagebox.showwarning("Parámetro obligatorio", "Complete: %s" % label, parent=self)
                return None
            if value == "":
                args.append(None)
                continue
            if kind == "fecha":
                try:
                    datetime.datetime.strptime(value, "%Y-%m-%d")
                except ValueError:
                    messagebox.showwarning("Fecha inválida", "%s: use AAAA-MM-DD." % label, parent=self)
                    return None
            if kind == "item":
                value = int(value)
            args.append(value)
        return args

    # ------------------------------------------------------------ ejecución
    def run(self):
        sel = self.listbox.curselection()
        if not sel:
            messagebox.showinfo("Reportes", "Seleccione un reporte.", parent=self)
            return
        title, proc, _spec = REPORTS[sel[0]]
        args = self._collect()
        if args is None:
            return
        ok, rows = guard(self, self.db.rows, proc, args)
        if not ok:
            return
        self.last_rows = rows
        self.last_keys = list(rows[0].keys()) if rows else []
        self.tree.delete(*self.tree.get_children())
        if not rows:
            self.tree["columns"] = ()
            self.info.config(text="Sin resultados para %s" % title.split("  ")[0])
            return
        self.tree["columns"] = self.last_keys
        for k in self.last_keys:
            texts = [to_text(r[k]) for r in rows[:50]] + [k]
            width = max(70, min(320, 8 * max(len(t) for t in texts)))
            self.tree.heading(k, text=k.replace("_", " "))
            self.tree.column(k, width=width, minwidth=50, anchor="w")
        for r in rows:
            self.tree.insert("", "end", values=[to_text(r[k]) for k in self.last_keys])
        self.info.config(text="%d fila(s)" % len(rows))

    def export(self):
        if not self.last_rows:
            messagebox.showinfo("Exportar", "Primero ejecute un reporte con resultados.", parent=self)
            return
        path = filedialog.asksaveasfilename(parent=self, defaultextension=".csv",
                                            filetypes=[("CSV", "*.csv")], initialfile="reporte.csv")
        if not path:
            return
        try:
            with open(path, "w", newline="", encoding="utf-8-sig") as fh:
                writer = csv.writer(fh)
                writer.writerow(self.last_keys)
                for r in self.last_rows:
                    writer.writerow(["" if r[k] is None else r[k] for k in self.last_keys])
        except OSError as e:
            messagebox.showerror("Exportar", "No se pudo guardar el archivo:\n%s" % e, parent=self)
            return
        messagebox.showinfo("Exportar", "Reporte guardado en:\n%s" % path, parent=self)
