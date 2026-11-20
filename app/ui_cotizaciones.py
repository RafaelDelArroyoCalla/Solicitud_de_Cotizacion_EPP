"""Pantalla maestro-detalle de Cotizaciones: cabecera + ítems."""
import datetime
import decimal
import tkinter as tk
from tkinter import ttk, messagebox

from db import to_text
from ui_common import LookupCombo, make_tree, fill_tree, selected_index, guard


class CotizacionesFrame(ttk.Frame):
    LIST_COLS = [("Num_solicitud", "N° solicitud", 90), ("Fecha_solicitud", "Fecha", 90),
                 ("Estado", "Estado", 80), ("Moneda", "Mon.", 45), ("Total", "Total", 100),
                 ("Cliente", "Cliente", 220), ("Proveedor", "Proveedor", 220), ("Concepto", "Concepto", 300),
                 ("Activo", "Activo", 55)]
    DET_COLS = [("ID_Item", "ID", 45), ("Descripcion_Item", "Ítem", 330), ("Unidad_Medida", "Unidad", 70),
                ("Marca_Referencial", "Marca", 110), ("Cantidad_Requerida", "Cantidad", 80),
                ("Precio_Unitario", "P. unitario", 90), ("Subtotal", "Subtotal", 100)]

    def __init__(self, parent, db):
        super().__init__(parent, padding=6)
        self.db = db
        self.rows, self.current = [], None
        self.det_rows, self.det_current = [], None
        self._build()

    # ------------------------------------------------------------ interfaz
    def _build(self):
        paned = ttk.PanedWindow(self, orient="vertical")
        paned.pack(fill="both", expand=True)
        upper, lower = ttk.Frame(paned), ttk.Frame(paned)
        paned.add(upper, weight=3)
        paned.add(lower, weight=2)

        # --- filtros + lista
        top = ttk.Frame(upper)
        top.pack(fill="x")
        ttk.Label(top, text="Buscar:").pack(side="left")
        self.search = tk.StringVar()
        e = ttk.Entry(top, textvariable=self.search, width=24)
        e.pack(side="left", padx=4)
        e.bind("<Return>", lambda _e: self.refresh())
        ttk.Label(top, text="Estado:").pack(side="left", padx=(10, 0))
        self.f_estado = LookupCombo(top, width=12)
        self.f_estado.set_options([("", "(Todos)"), ("Pendiente", "Pendiente"), ("Aprobado", "Aprobado"),
                                   ("Rechazado", "Rechazado")])
        self.f_estado.current(0)
        self.f_estado.pack(side="left", padx=4)
        self.f_estado.bind("<<ComboboxSelected>>", lambda _e: self.refresh())
        self.show_inactive = tk.IntVar(value=0)
        ttk.Checkbutton(top, text="Mostrar dadas de baja", variable=self.show_inactive,
                        command=self.refresh).pack(side="left", padx=10)
        ttk.Button(top, text="Buscar", command=self.refresh).pack(side="left")
        self.count_label = ttk.Label(top, text="")
        self.count_label.pack(side="right")

        frame, self.tree = make_tree(upper, self.LIST_COLS, height=7)
        frame.pack(fill="both", expand=True, pady=4)
        self.tree.bind("<<TreeviewSelect>>", self._on_select)

        # --- formulario de cabecera
        form = ttk.LabelFrame(upper, text="Cabecera de la cotización", padding=6)
        form.pack(fill="x")
        self.v = {k: tk.StringVar() for k in ("num", "fecha", "estado", "validez", "plazo", "garantia", "unidad",
                                              "concepto")}
        self.c_cliente = LookupCombo(form, width=34)
        self.c_prov = LookupCombo(form, width=34)
        self.c_esp = LookupCombo(form, width=34)
        self.c_moneda = LookupCombo(form, width=8)
        self.c_moneda.set_options([("S/.", "S/."), ("USD", "USD")])

        def add(r, c, text, widget):
            ttk.Label(form, text=text).grid(row=r, column=c * 2, sticky="w", padx=(6, 4), pady=2)
            widget.grid(row=r, column=c * 2 + 1, sticky="w", pady=2)

        self.e_num = ttk.Entry(form, textvariable=self.v["num"], width=12)
        add(0, 0, "N° solicitud", self.e_num)
        add(0, 1, "Fecha (AAAA-MM-DD) *", ttk.Entry(form, textvariable=self.v["fecha"], width=14))
        e_estado = ttk.Entry(form, textvariable=self.v["estado"], width=12, state="readonly")
        add(0, 2, "Estado", e_estado)
        add(1, 0, "Cliente *", self.c_cliente)
        add(1, 1, "Proveedor *", self.c_prov)
        add(1, 2, "Especificación *", self.c_esp)
        add(2, 0, "Validez *", ttk.Entry(form, textvariable=self.v["validez"], width=20))
        add(2, 1, "Plazo de entrega *", ttk.Entry(form, textvariable=self.v["plazo"], width=20))
        add(2, 2, "Garantía *", ttk.Entry(form, textvariable=self.v["garantia"], width=20))
        add(3, 0, "Moneda *", self.c_moneda)
        add(3, 1, "Unidad ejecutora *", ttk.Entry(form, textvariable=self.v["unidad"], width=34))
        add(3, 2, "Concepto *", ttk.Entry(form, textvariable=self.v["concepto"], width=34))

        bar = ttk.Frame(upper)
        bar.pack(fill="x", pady=(6, 0))
        self.btn = {}
        for key, text, cmd in (("new", "Nueva", self.new), ("save", "Guardar", self.save),
                               ("del", "Dar de baja", self.delete), ("react", "Reactivar", self.reactivate),
                               ("ok", "Aprobar", lambda: self.change_state("Aprobado")),
                               ("no", "Rechazar", lambda: self.change_state("Rechazado"))):
            b = ttk.Button(bar, text=text, command=cmd)
            b.pack(side="left", padx=(0, 6))
            self.btn[key] = b
        ttk.Label(bar, text="N° solicitud vacío = se genera automáticamente (C00001, C00002...)",
                  foreground="#666").pack(side="left", padx=10)

        # --- detalle
        box = ttk.LabelFrame(lower, text="Ítems de la cotización seleccionada", padding=6)
        box.pack(fill="both", expand=True, pady=(6, 0))
        dframe, self.dtree = make_tree(box, self.DET_COLS, height=5)
        dframe.pack(fill="both", expand=True)
        self.dtree.bind("<<TreeviewSelect>>", self._on_det_select)

        dbar = ttk.Frame(box)
        dbar.pack(fill="x", pady=(6, 0))
        ttk.Label(dbar, text="Ítem").pack(side="left")
        self.d_item = LookupCombo(dbar, width=44)
        self.d_item.pack(side="left", padx=4)
        ttk.Label(dbar, text="Cantidad").pack(side="left")
        self.d_cant = tk.StringVar()
        ttk.Entry(dbar, textvariable=self.d_cant, width=10).pack(side="left", padx=4)
        ttk.Label(dbar, text="Precio unit.").pack(side="left")
        self.d_precio = tk.StringVar()
        ttk.Entry(dbar, textvariable=self.d_precio, width=12).pack(side="left", padx=4)
        self.btn["dadd"] = ttk.Button(dbar, text="Agregar", command=self.det_add)
        self.btn["dmod"] = ttk.Button(dbar, text="Modificar", command=self.det_modify)
        self.btn["ddel"] = ttk.Button(dbar, text="Quitar", command=self.det_remove)
        for k in ("dadd", "dmod", "ddel"):
            self.btn[k].pack(side="left", padx=3)
        self.total_label = ttk.Label(dbar, text="Total: —", font=("TkDefaultFont", 10, "bold"))
        self.total_label.pack(side="right")

    # ------------------------------------------------------------ carga
    def _load_lookups(self):
        ok, rows = guard(self, self.db.rows, "sp_cliente_listar", ("", 0))
        if ok:
            self.c_cliente.set_options([(r["DNI_RUC"], "%s — %s" % (r["DNI_RUC"], r["Razon_social"])) for r in rows])
        ok, rows = guard(self, self.db.rows, "sp_proveedor_listar", ("", 0))
        if ok:
            self.c_prov.set_options([(r["RUC_Proveedor"], "%s — %s" % (r["RUC_Proveedor"], r["Razon_Social"]))
                                     for r in rows])
        ok, rows = guard(self, self.db.rows, "sp_especificacion_listar", ("", 0))
        if ok:
            self.c_esp.set_options([(r["ID_Especificacion_Tecnica"], "%s — %s" % (r["ID_Especificacion_Tecnica"],
                                                                                   r["Obra_denominacion"]))
                                    for r in rows])
        ok, rows = guard(self, self.db.rows, "sp_item_listar", ("", 0))
        if ok:
            self.d_item.set_options([(r["ID_Item"], "%s — %s (%s)" % (r["ID_Item"], r["Descripcion_Item"],
                                                                      r["Unidad_Medida"])) for r in rows])

    def refresh(self, select_num=None):
        self._load_lookups()
        ok, rows = guard(self, self.db.rows, "sp_cotizacion_listar",
                         (self.search.get().strip(), self.f_estado.get_id(), self.show_inactive.get()))
        if not ok:
            return
        self.rows = rows
        fill_tree(self.tree, rows, [c[0] for c in self.LIST_COLS])
        self.count_label.config(text="%d cotización(es)" % len(rows))
        self.new()
        if select_num is not None:
            for i, r in enumerate(rows):
                if r["Num_solicitud"] == select_num:
                    self.tree.selection_set(str(i))
                    self.tree.see(str(i))
                    break

    # ------------------------------------------------------------ cabecera
    def new(self):
        self.current = None
        self.tree.selection_remove(self.tree.selection())
        self.e_num.configure(state="normal")
        for var in self.v.values():
            var.set("")
        self.v["fecha"].set(datetime.date.today().isoformat())
        self.v["estado"].set("Pendiente")
        self.v["validez"].set("30 días calendario")
        self.v["plazo"].set("15 días calendario")
        self.v["garantia"].set("6 meses")
        for c in (self.c_cliente, self.c_prov, self.c_esp):
            c.clear()
        self.c_moneda.set_id("S/.")
        self._load_details()
        self._update_buttons()

    def _on_select(self, _e=None):
        idx = selected_index(self.tree)
        if idx is None:
            return
        r = self.current = self.rows[idx]
        self.e_num.configure(state="normal")
        self.v["num"].set(r["Num_solicitud"])
        self.e_num.configure(state="readonly")
        self.v["fecha"].set(to_text(r["Fecha_solicitud"]))
        self.v["estado"].set(r["Estado"])
        self.v["validez"].set(r["Validez_cotizacion"])
        self.v["plazo"].set(r["Plazo_entrega"])
        self.v["garantia"].set(r["Garantia_cot"])
        self.v["unidad"].set(r["Unidad_ejecutora"])
        self.v["concepto"].set(r["Concepto"])
        self.c_cliente.set_id(r["ID_Cliente"])
        self.c_prov.set_id(r["ID_Proveedor"])
        self.c_esp.set_id(r["ID_Especificacion_Tecnica"])
        self.c_moneda.set_id(r["Moneda"])
        self._load_details()
        self._update_buttons()

    def _header_args(self):
        """Devuelve la lista de argumentos para insertar/modificar, o None si hay errores."""
        v = {k: var.get().strip() for k, var in self.v.items()}
        try:
            datetime.datetime.strptime(v["fecha"], "%Y-%m-%d")
        except ValueError:
            messagebox.showwarning("Fecha inválida", "Use el formato AAAA-MM-DD (por ejemplo 2026-11-19).", parent=self)
            return None
        required = [(v["validez"], "Validez"), (v["plazo"], "Plazo de entrega"), (v["garantia"], "Garantía"),
                    (v["unidad"], "Unidad ejecutora"), (v["concepto"], "Concepto"),
                    (self.c_cliente.get_id(), "Cliente"), (self.c_prov.get_id(), "Proveedor"),
                    (self.c_esp.get_id(), "Especificación"), (self.c_moneda.get_id(), "Moneda")]
        for value, label in required:
            if not value:
                messagebox.showwarning("Dato obligatorio", "Complete el campo: %s" % label, parent=self)
                return None
        return [self.c_esp.get_id() and int(self.c_esp.get_id()), self.c_cliente.get_id(), self.c_prov.get_id(),
                v["validez"], v["plazo"], v["garantia"], self.c_moneda.get_id(), v["unidad"], v["fecha"],
                v["concepto"]]

    def save(self):
        rest = self._header_args()
        if rest is None:
            return
        if self.current is None:
            ok, res = guard(self, self.db.call, "sp_cotizacion_insertar", [self.v["num"].get().strip() or None] + rest)
            if ok:
                num = res[0][0]["Num_solicitud"] if res and res[0] else None
                messagebox.showinfo("Listo", "Cotización %s creada. Ahora agregue sus ítems abajo." % num, parent=self)
                self.refresh(select_num=num)
        else:
            num = self.current["Num_solicitud"]
            ok, _ = guard(self, self.db.call, "sp_cotizacion_modificar", [num] + rest)
            if ok:
                messagebox.showinfo("Listo", "Cotización %s actualizada." % num, parent=self)
                self.refresh(select_num=num)

    def delete(self):
        if self.current is None:
            return
        num = self.current["Num_solicitud"]
        if messagebox.askyesno("Confirmar baja", "¿Dar de baja la cotización %s?\n(Baja lógica)" % num, parent=self):
            ok, _ = guard(self, self.db.call, "sp_cotizacion_eliminar", (num,))
            if ok:
                self.refresh(select_num=num)

    def reactivate(self):
        if self.current is None:
            return
        num = self.current["Num_solicitud"]
        ok, _ = guard(self, self.db.call, "sp_cotizacion_reactivar", (num,))
        if ok:
            self.refresh(select_num=num)

    def change_state(self, estado):
        if self.current is None:
            return
        num = self.current["Num_solicitud"]
        if messagebox.askyesno("Confirmar", "¿Marcar la cotización %s como %s?\nEste cambio no se puede revertir." %
                               (num, estado), parent=self):
            ok, _ = guard(self, self.db.call, "sp_cotizacion_cambiar_estado", (num, estado))
            if ok:
                self.refresh(select_num=num)

    # ------------------------------------------------------------ detalle
    def _load_details(self):
        self.det_current = None
        self.d_item.clear()
        self.d_cant.set("")
        self.d_precio.set("")
        if self.current is None:
            self.det_rows = []
            fill_tree(self.dtree, [], [c[0] for c in self.DET_COLS])
            self.total_label.config(text="Total: —")
            return
        ok, rows = guard(self, self.db.rows, "sp_detalle_listar", (self.current["Num_solicitud"],))
        self.det_rows = rows if ok else []
        fill_tree(self.dtree, self.det_rows, [c[0] for c in self.DET_COLS])
        total = sum((r["Subtotal"] for r in self.det_rows), decimal.Decimal("0"))
        self.total_label.config(text="Total: %s %s" % (self.current["Moneda"], to_text(total)))

    def _on_det_select(self, _e=None):
        idx = selected_index(self.dtree)
        if idx is None:
            return
        r = self.det_current = self.det_rows[idx]
        self.d_item.set_id(r["ID_Item"])
        self.d_cant.set(str(r["Cantidad_Requerida"]))
        self.d_precio.set(str(r["Precio_Unitario"]))

    def _det_values(self, need_item=True):
        item = self.d_item.get_id()
        if need_item and not item:
            messagebox.showwarning("Dato obligatorio", "Seleccione un ítem.", parent=self)
            return None
        try:
            cant = decimal.Decimal(self.d_cant.get().strip().replace(",", "."))
            precio = decimal.Decimal(self.d_precio.get().strip().replace(",", "."))
        except decimal.InvalidOperation:
            messagebox.showwarning("Dato inválido", "Cantidad y precio deben ser números (ej.: 12.50).", parent=self)
            return None
        if not (cant.is_finite() and precio.is_finite()) or cant <= 0 or precio <= 0:
            messagebox.showwarning("Dato inválido", "Cantidad y precio deben ser mayores que 0.", parent=self)
            return None
        return item, cant, precio

    def _refresh_keep(self):
        self.refresh(select_num=self.current["Num_solicitud"])

    def det_add(self):
        if self.current is None:
            messagebox.showinfo("Seleccione una cotización", "Primero seleccione o cree una cotización.", parent=self)
            return
        vals = self._det_values()
        if vals is None:
            return
        ok, _ = guard(self, self.db.call, "sp_detalle_agregar", (self.current["Num_solicitud"], int(vals[0]),
                                                                  vals[1], vals[2]))
        if ok:
            self._refresh_keep()

    def det_modify(self):
        if self.current is None or self.det_current is None:
            messagebox.showinfo("Seleccione un ítem", "Seleccione un ítem de la tabla para modificarlo.", parent=self)
            return
        vals = self._det_values(need_item=False)
        if vals is None:
            return
        ok, _ = guard(self, self.db.call, "sp_detalle_modificar", (self.current["Num_solicitud"],
                                                                    self.det_current["ID_Item"], vals[1], vals[2]))
        if ok:
            self._refresh_keep()

    def det_remove(self):
        if self.current is None or self.det_current is None:
            messagebox.showinfo("Seleccione un ítem", "Seleccione un ítem de la tabla para quitarlo.", parent=self)
            return
        if messagebox.askyesno("Confirmar", "¿Quitar el ítem de la cotización?", parent=self):
            ok, _ = guard(self, self.db.call, "sp_detalle_quitar", (self.current["Num_solicitud"],
                                                                     self.det_current["ID_Item"]))
            if ok:
                self._refresh_keep()

    # ------------------------------------------------------------ estados de botones
    def _update_buttons(self):
        cur = self.current
        active = cur is not None and cur["Activo"] == 1
        pending = active and cur["Estado"] == "Pendiente"

        def st(btn, enabled):
            self.btn[btn].state(["!disabled"] if enabled else ["disabled"])

        st("save", cur is None or pending)
        st("del", active and cur["Estado"] != "Aprobado")
        st("react", cur is not None and not active)
        st("ok", pending)
        st("no", pending)
        for k in ("dadd", "dmod", "ddel"):
            st(k, pending)
