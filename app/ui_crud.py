"""CRUD genérico (Clientes, Proveedores, Ítems, Especificaciones).
Usa los procedimientos sp_<prefijo>_listar / _insertar / _modificar / _eliminar / _reactivar."""
import tkinter as tk
from tkinter import ttk, messagebox

from ui_common import LookupCombo, make_tree, fill_tree, selected_index, guard


class Field:
    def __init__(self, key, label, kind="entry", width=34, loader=None, required=True):
        self.key, self.label, self.kind = key, label, kind      # kind: entry | lookup
        self.width, self.loader, self.required = width, loader, required


class CrudFrame(ttk.Frame):
    def __init__(self, parent, db, entity, prefix, fields, columns, auto_key=False):
        super().__init__(parent, padding=8)
        self.db, self.entity, self.prefix = db, entity, prefix
        self.fields, self.columns, self.auto_key = fields, columns, auto_key
        self.key = fields[0].key                      # el primer campo es siempre la llave
        self.rows, self.current = [], None
        self.vars, self.widgets = {}, {}
        self._build()

    # ------------------------------------------------------------ interfaz
    def _build(self):
        top = ttk.Frame(self)
        top.pack(fill="x")
        ttk.Label(top, text="Buscar:").pack(side="left")
        self.search = tk.StringVar()
        e = ttk.Entry(top, textvariable=self.search, width=30)
        e.pack(side="left", padx=4)
        e.bind("<Return>", lambda _e: self.refresh())
        ttk.Button(top, text="Buscar", command=self.refresh).pack(side="left")
        self.show_inactive = tk.IntVar(value=0)
        ttk.Checkbutton(top, text="Mostrar dados de baja", variable=self.show_inactive,
                        command=self.refresh).pack(side="left", padx=12)
        self.count_label = ttk.Label(top, text="")
        self.count_label.pack(side="right")

        frame, self.tree = make_tree(self, self.columns, height=9)
        frame.pack(fill="both", expand=True, pady=6)
        self.tree.bind("<<TreeviewSelect>>", self._on_select)

        form = ttk.LabelFrame(self, text="Datos de %s" % self.entity, padding=8)
        form.pack(fill="x")
        for r, f in enumerate(self.fields):
            ttk.Label(form, text=f.label + ("" if not f.required or (self.auto_key and r == 0) else " *")
                      ).grid(row=r, column=0, sticky="w", pady=2, padx=(0, 8))
            if f.kind == "lookup":
                w = LookupCombo(form, width=f.width + 6)
            else:
                var = tk.StringVar()
                self.vars[f.key] = var
                w = ttk.Entry(form, textvariable=var, width=f.width + 6)
            w.grid(row=r, column=1, sticky="w", pady=2)
            self.widgets[f.key] = w
        form.columnconfigure(1, weight=1)

        bar = ttk.Frame(self)
        bar.pack(fill="x", pady=(8, 0))
        self.btn_new = ttk.Button(bar, text="Nuevo", command=self.new)
        self.btn_save = ttk.Button(bar, text="Guardar", command=self.save)
        self.btn_del = ttk.Button(bar, text="Dar de baja", command=self.delete)
        self.btn_react = ttk.Button(bar, text="Reactivar", command=self.reactivate)
        self.btn_ref = ttk.Button(bar, text="Actualizar lista", command=self.refresh)
        for b in (self.btn_new, self.btn_save, self.btn_del, self.btn_react, self.btn_ref):
            b.pack(side="left", padx=(0, 6))
        ttk.Label(bar, text="* obligatorio", foreground="#666").pack(side="right")

    # ------------------------------------------------------------ datos
    def refresh(self, select_key=None):
        for f in self.fields:                               # recargar combos dependientes
            if f.kind == "lookup":
                ok, opts = guard(self, f.loader, self.db)
                if ok:
                    self.widgets[f.key].set_options(opts)
        ok, rows = guard(self, self.db.rows, "sp_%s_listar" % self.prefix,
                         (self.search.get().strip(), self.show_inactive.get()))
        if not ok:
            return
        self.rows = rows
        fill_tree(self.tree, rows, [c[0] for c in self.columns])
        self.count_label.config(text="%d registro(s)" % len(rows))
        self.new()
        if select_key is not None:
            for i, r in enumerate(rows):
                if str(r.get(self.key)) == str(select_key):
                    self.tree.selection_set(str(i))
                    self.tree.see(str(i))
                    break

    def _set_key_state(self):
        w = self.widgets[self.key]
        locked = self.auto_key or self.current is not None
        w.configure(state="readonly" if locked else "normal")

    def new(self):
        self.current = None
        self.tree.selection_remove(self.tree.selection())
        for f in self.fields:
            if f.kind == "lookup":
                self.widgets[f.key].clear()
            else:
                self.widgets[f.key].configure(state="normal")
                self.vars[f.key].set("")
        self._set_key_state()
        if self.auto_key:
            self.vars[self.key].set("(automático)")
        self._update_buttons()
        first = self.fields[1] if self.auto_key else self.fields[0]
        self.widgets[first.key].focus_set()

    def _on_select(self, _event=None):
        idx = selected_index(self.tree)
        if idx is None:
            return
        self.current = self.rows[idx]
        for f in self.fields:
            value = self.current.get(f.key)
            if f.kind == "lookup":
                self.widgets[f.key].set_id(value)
            else:
                self.widgets[f.key].configure(state="normal")
                self.vars[f.key].set("" if value is None else str(value))
        self._set_key_state()
        self._update_buttons()

    def _update_buttons(self):
        cur = self.current
        active = cur is not None and cur.get("Activo") in (1, True)
        inactive = cur is not None and not active
        self.btn_save.state(["disabled"] if inactive else ["!disabled"])
        self.btn_del.state(["!disabled"] if active else ["disabled"])
        self.btn_react.state(["!disabled"] if inactive else ["disabled"])

    # ------------------------------------------------------------ acciones
    def _value(self, f):
        if f.kind == "lookup":
            v = self.widgets[f.key].get_id()
        else:
            v = self.vars[f.key].get().strip()
        return v

    def _key_value(self):
        v = self.current.get(self.key)
        return v

    def save(self):
        values = []
        creating = self.current is None
        for i, f in enumerate(self.fields):
            if i == 0 and self.auto_key:
                continue
            v = self._value(f)
            if v == "" and f.required:
                messagebox.showwarning("Dato obligatorio", "Complete el campo: %s" % f.label, parent=self)
                self.widgets[f.key].focus_set()
                return
            values.append(v if v != "" else None)
        if creating:
            proc, args = "sp_%s_insertar" % self.prefix, values
        else:
            proc, args = "sp_%s_modificar" % self.prefix, ([self._key_value()] + values if self.auto_key else values)
        ok, _ = guard(self, self.db.call, proc, args)
        if ok:
            messagebox.showinfo("Listo", "%s guardado correctamente." % self.entity.capitalize(), parent=self)
            key = None if (creating and self.auto_key) else (values[0] if creating else self._key_value())
            self.refresh(select_key=key)

    def delete(self):
        if self.current is None:
            return
        if not messagebox.askyesno("Confirmar baja", "¿Dar de baja este registro?\n(Baja lógica: no se elimina de la base de datos.)",
                                   parent=self):
            return
        ok, _ = guard(self, self.db.call, "sp_%s_eliminar" % self.prefix, (self._key_value(),))
        if ok:
            self.refresh(select_key=self._key_value())

    def reactivate(self):
        if self.current is None:
            return
        key = self._key_value()
        ok, _ = guard(self, self.db.call, "sp_%s_reactivar" % self.prefix, (key,))
        if ok:
            self.refresh(select_key=key)


# ---------------------------------------------------------------- definiciones
def ubigeo_options(db):
    return [(r["Ubigeo"], "%s — %s / %s / %s" % (r["Ubigeo"], r["Departamento"], r["Provincia"], r["Distrito"]))
            for r in db.rows("sp_ubigeo_listar")]


def build_clientes(parent, db):
    return CrudFrame(parent, db, "cliente", "cliente",
                     [Field("DNI_RUC", "DNI / RUC"), Field("Razon_social", "Razón social / Nombre", width=50),
                      Field("Direccion", "Dirección", width=50)],
                     [("DNI_RUC", "DNI / RUC", 110), ("Razon_social", "Razón social", 320),
                      ("Direccion", "Dirección", 380), ("Activo", "Activo", 60)])


def build_proveedores(parent, db):
    return CrudFrame(parent, db, "proveedor", "proveedor",
                     [Field("RUC_Proveedor", "RUC"), Field("Razon_Social", "Razón social", width=50),
                      Field("Ubigeo", "Ubigeo", kind="lookup", loader=ubigeo_options, width=44),
                      Field("Referencia", "Referencia", width=50, required=False)],
                     [("RUC_Proveedor", "RUC", 100), ("Razon_Social", "Razón social", 280),
                      ("Ubicacion", "Departamento / Provincia / Distrito", 260),
                      ("Referencia", "Referencia", 220), ("Activo", "Activo", 60)])


def build_items(parent, db):
    return CrudFrame(parent, db, "ítem", "item",
                     [Field("ID_Item", "ID"), Field("Descripcion_Item", "Descripción", width=60),
                      Field("Unidad_Medida", "Unidad de medida", width=20),
                      Field("Marca_Referencial", "Marca referencial", width=40)],
                     [("ID_Item", "ID", 50), ("Descripcion_Item", "Descripción", 400),
                      ("Unidad_Medida", "Unidad", 90), ("Marca_Referencial", "Marca", 180), ("Activo", "Activo", 60)],
                     auto_key=True)


def build_especificaciones(parent, db):
    return CrudFrame(parent, db, "especificación técnica", "especificacion",
                     [Field("ID_Especificacion_Tecnica", "ID"), Field("Obra_denominacion", "Obra / denominación", width=60),
                      Field("Lugar_entrega", "Lugar de entrega", width=60),
                      Field("Area_usuario", "Área usuaria", width=40),
                      Field("Plazo_entrega", "Plazo de entrega", width=24),
                      Field("Garantia", "Garantía", width=24, required=False)],
                     [("ID_Especificacion_Tecnica", "ID", 50), ("Obra_denominacion", "Obra", 300),
                      ("Lugar_entrega", "Lugar de entrega", 260), ("Area_usuario", "Área usuaria", 180),
                      ("Plazo_entrega", "Plazo", 110), ("Garantia", "Garantía", 90), ("Activo", "Activo", 60)],
                     auto_key=True)
