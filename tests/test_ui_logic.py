"""Prueba de la lógica de la interfaz SIN Tkinter ni MySQL reales.
Se simulan Tkinter y la BD; la BD falsa valida cada CALL contra las firmas del script SQL
(nombre del procedimiento y número de parámetros), detectando desajustes UI <-> SQL."""
import datetime
import decimal
import os
import re
import sys
import types
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "app"))

# ------------------------------------------------------------------ Tkinter simulado
BOX = {"info": [], "warn": [], "error": [], "yesno": True}


class W:
    def __init__(self, *a, **k):
        self.opts = dict(k)
        self.bound = {}
        self.children_ = []

    def __getattr__(self, name):
        return lambda *a, **k: None

    def configure(self, **k):
        self.opts.update(k)

    config = configure

    def bind(self, ev, cb, *a):
        self.bound[ev] = cb

    def winfo_children(self):
        return []

    def __setitem__(self, k, v):
        self.opts[k] = v

    def __getitem__(self, k):
        return self.opts.get(k, [])


class Var:
    def __init__(self, value=""):
        self.v = value

    def get(self):
        return self.v

    def set(self, v):
        self.v = v


class Combobox(W):
    def __init__(self, parent=None, **k):
        super().__init__(**k)
        self.idx = -1
        self.text = ""

    def _vals(self):
        return list(self.opts.get("values", []))

    def current(self, i=None):
        if i is None:
            return self.idx
        self.idx = i
        self.text = self._vals()[i]

    def set(self, t):
        self.text = t
        v = self._vals()
        self.idx = v.index(t) if t in v else -1

    def get(self):
        return self.text


class Tree(W):
    def __init__(self, *a, **k):
        super().__init__(*a, **k)
        self.items, self.sel = {}, ()

    def insert(self, parent, where, iid=None, values=(), tags=()):
        iid = iid if iid is not None else str(len(self.items))
        self.items[iid] = list(values)
        return iid

    def delete(self, *ids):
        for i in ids:
            self.items.pop(i, None)
        self.sel = ()

    def get_children(self, *a):
        return list(self.items)

    def selection(self):
        return self.sel

    def selection_set(self, iid):
        self.sel = (iid,)
        cb = self.bound.get("<<TreeviewSelect>>")
        cb and cb(None)

    def selection_remove(self, *a):
        self.sel = ()
        cb = self.bound.get("<<TreeviewSelect>>")
        cb and cb(None)


class Listbox(W):
    def curselection(self):
        return (0,)


def install_stubs():
    tk = types.ModuleType("tkinter")
    ttk = types.ModuleType("tkinter.ttk")
    mb = types.ModuleType("tkinter.messagebox")
    fd = types.ModuleType("tkinter.filedialog")
    for n in ("Tk", "Toplevel", "Text", "Menu", "Frame", "Label", "Entry", "Button", "Checkbutton"):
        setattr(tk, n, type(n, (W,), {}))
    tk.StringVar, tk.IntVar = Var, Var
    tk.Listbox = Listbox
    tk.TclError = type("TclError", (Exception,), {})
    for n in ("Frame", "LabelFrame", "Label", "Entry", "Button", "Checkbutton", "Scrollbar", "PanedWindow",
              "Notebook", "Style"):
        setattr(ttk, n, type(n, (W,), {}))
    ttk.Combobox, ttk.Treeview = Combobox, Tree
    for n, key in (("showinfo", "info"), ("showwarning", "warn"), ("showerror", "error")):
        setattr(mb, n, (lambda key: lambda *a, **k: BOX[key].append(a))(key))
    mb.askyesno = lambda *a, **k: BOX["yesno"]
    fd.asksaveasfilename = lambda **k: ""
    fd.askopenfilename = lambda **k: ""
    tk.ttk, tk.messagebox, tk.filedialog = ttk, mb, fd
    sys.modules.update({"tkinter": tk, "tkinter.ttk": ttk, "tkinter.messagebox": mb, "tkinter.filedialog": fd})

    my = types.ModuleType("mysql")
    conn = types.ModuleType("mysql.connector")
    conn.Error = type("Error", (Exception,), {})
    conn.connect = lambda **k: None
    my.connector = conn
    sys.modules.update({"mysql": my, "mysql.connector": conn})


install_stubs()
import db as dbmod  # noqa: E402
import ui_crud, ui_cotizaciones, ui_reportes  # noqa: E402
from ui_common import LookupCombo  # noqa: E402


# ------------------------------------------------------------------ firmas reales del script
def parse_signatures():
    with open(os.path.join(ROOT, "sql", "sistema_cotizaciones_completo.sql"), encoding="utf-8") as fh:
        text = fh.read()
    sigs = {}
    for m in re.finditer(r"CREATE PROCEDURE (\w+)\(", text):
        i, depth = m.end(), 1
        while depth:
            depth += {"(": 1, ")": -1}.get(text[i], 0)
            i += 1
        params = text[m.end():i - 1]
        sigs[m.group(1)] = len(re.findall(r"\bIN\s+p_", params))
    return sigs


SIGS = parse_signatures()

TODAY = datetime.date(2026, 11, 19)
D = decimal.Decimal


class FakeDB(dbmod.Database):
    def __init__(self):
        super().__init__()
        self.calls = []

    @property
    def connected(self):
        return True

    def call(self, proc, args=()):
        assert proc in SIGS, "Procedimiento inexistente en el script: %s" % proc
        assert len(args) == SIGS[proc], "%s espera %d parámetros y recibió %d: %r" % (proc, SIGS[proc], len(args), args)
        self.calls.append((proc, list(args)))
        return [self.canned(proc, args)] if self.canned(proc, args) else []

    def rows(self, proc, args=()):
        res = self.call(proc, args)
        return res[0] if res else []

    def canned(self, proc, args):
        c = {
            "sp_ubigeo_listar": [{"Ubigeo": "080101", "Departamento": "Cusco", "Provincia": "Cusco", "Distrito": "Cusco"}],
            "sp_cliente_listar": [{"DNI_RUC": "20450123456", "Razon_social": "Muni", "Direccion": "Av 1", "Activo": 1},
                                  {"DNI_RUC": "45871236", "Razon_social": "Carlos", "Direccion": "Av 2", "Activo": 0}],
            "sp_proveedor_listar": [{"RUC_Proveedor": "20601111111", "Razon_Social": "Ferre", "Ubigeo": "080101",
                                     "Ubicacion": "Cusco / Cusco / Cusco", "Referencia": None, "Activo": 1}],
            "sp_item_listar": [{"ID_Item": 1, "Descripcion_Item": "Cemento", "Unidad_Medida": "BOLSA",
                                "Marca_Referencial": "Yura", "Activo": 1}],
            "sp_especificacion_listar": [{"ID_Especificacion_Tecnica": 1, "Obra_denominacion": "Obra", "Lugar_entrega": "L",
                                          "Area_usuario": "A", "Plazo_entrega": "15 d", "Garantia": None, "Activo": 1}],
            "sp_cotizacion_listar": [
                {"Num_solicitud": "C00001", "Fecha_solicitud": TODAY, "Estado": "Pendiente", "Moneda": "S/.",
                 "Total": D("100.00"), "Cliente": "Muni", "Proveedor": "Ferre", "Concepto": "x",
                 "ID_Cliente": "20450123456", "ID_Proveedor": "20601111111", "ID_Especificacion_Tecnica": 1,
                 "Validez_cotizacion": "30 d", "Plazo_entrega": "15 d", "Garantia_cot": "6 m",
                 "Unidad_ejecutora": "U", "Activo": 1}],
            "sp_detalle_listar": [{"ID_Item": 1, "Descripcion_Item": "Cemento", "Unidad_Medida": "BOLSA",
                                   "Marca_Referencial": "Yura", "Cantidad_Requerida": D("10.00"),
                                   "Precio_Unitario": D("10.00"), "Subtotal": D("100.00")}],
            "sp_cotizacion_insertar": [{"Num_solicitud": "C00002"}],
        }
        if proc.startswith("sp_rep_"):
            return [{"Col_A": "x", "Col_B": D("1.50")}]
        return c.get(proc, [])


class CrudTests(unittest.TestCase):
    def setUp(self):
        BOX["warn"].clear(); BOX["info"].clear(); BOX["error"].clear(); BOX["yesno"] = True
        self.db = FakeDB()

    def last(self):
        return [c for c in self.db.calls if not c[0].endswith("_listar")][-1]

    def check_crud(self, frame, new_values, edit_idx=0):
        frame.refresh()
        self.assertTrue(frame.rows)
        # modificar
        frame.tree.selection_set(str(edit_idx))
        self.assertIsNotNone(frame.current)
        frame.save()
        self.assertTrue(self.last()[0].endswith("_modificar"), self.last())
        # nuevo
        frame.new()
        for k, v in new_values.items():
            w = frame.widgets[k]
            if isinstance(w, LookupCombo):
                w.set_id(v)
            else:
                frame.vars[k].set(v)
        frame.save()
        self.assertEqual([], BOX["warn"], BOX["warn"])
        self.assertTrue(self.last()[0].endswith("_insertar"), self.last())
        # baja y reactivar
        frame.tree.selection_set("0")
        frame.delete()
        self.assertTrue(self.last()[0].endswith("_eliminar"))
        frame.reactivate()
        self.assertTrue(self.last()[0].endswith("_reactivar"))

    def test_clientes(self):
        f = ui_crud.build_clientes(W(), self.db)
        self.check_crud(f, {"DNI_RUC": "12345678", "Razon_social": "N", "Direccion": "D"})
        ins = [c for c in self.db.calls if c[0] == "sp_cliente_insertar"][0]
        self.assertEqual(ins[1], ["12345678", "N", "D"])

    def test_proveedores_opcional_none(self):
        f = ui_crud.build_proveedores(W(), self.db)
        self.check_crud(f, {"RUC_Proveedor": "20600000000", "Razon_Social": "P", "Ubigeo": "080101"})
        ins = [c for c in self.db.calls if c[0] == "sp_proveedor_insertar"][0]
        self.assertEqual(ins[1], ["20600000000", "P", "080101", None])

    def test_items_autokey(self):
        f = ui_crud.build_items(W(), self.db)
        self.check_crud(f, {"Descripcion_Item": "D", "Unidad_Medida": "UND", "Marca_Referencial": "M"})
        mod = [c for c in self.db.calls if c[0] == "sp_item_modificar"][0]
        self.assertEqual(mod[1][0], 1)                       # la llave va primero
        ins = [c for c in self.db.calls if c[0] == "sp_item_insertar"][0]
        self.assertEqual(ins[1], ["D", "UND", "M"])

    def test_especificaciones(self):
        f = ui_crud.build_especificaciones(W(), self.db)
        self.check_crud(f, {"Obra_denominacion": "O", "Lugar_entrega": "L", "Area_usuario": "A", "Plazo_entrega": "P"})
        ins = [c for c in self.db.calls if c[0] == "sp_especificacion_insertar"][0]
        self.assertEqual(ins[1], ["O", "L", "A", "P", None])

    def test_campo_obligatorio_vacio(self):
        f = ui_crud.build_clientes(W(), self.db)
        f.refresh(); f.new(); f.save()
        self.assertEqual(len(BOX["warn"]), 1)


class CotizacionTests(unittest.TestCase):
    def setUp(self):
        BOX["warn"].clear(); BOX["info"].clear(); BOX["yesno"] = True
        self.db = FakeDB()
        self.f = ui_cotizaciones.CotizacionesFrame(W(), self.db)
        self.f.refresh()

    def names(self):
        return [c[0] for c in self.db.calls]

    def test_flujo(self):
        f = self.f
        f.tree.selection_set("0")
        self.assertEqual(f.v["num"].get(), "C00001")
        f.save()
        mod = [c for c in self.db.calls if c[0] == "sp_cotizacion_modificar"][-1][1]
        self.assertEqual(mod[0], "C00001")
        self.assertEqual(mod[1], 1)                           # especificación como int
        self.assertEqual(mod[9], TODAY.isoformat())           # fecha
        # nueva
        f.new()
        f.c_cliente.set_id("20450123456"); f.c_prov.set_id("20601111111"); f.c_esp.set_id(1)
        f.v["unidad"].set("U"); f.v["concepto"].set("C")
        f.save()
        self.assertEqual([], BOX["warn"], BOX["warn"])
        ins = [c for c in self.db.calls if c[0] == "sp_cotizacion_insertar"][-1][1]
        self.assertIsNone(ins[0])                             # número automático
        # detalle
        f.tree.selection_set("0")
        f.d_item.set_id(1); f.d_cant.set("5"); f.d_precio.set("2,50")
        f.det_add()
        add = [c for c in self.db.calls if c[0] == "sp_detalle_agregar"][-1][1]
        self.assertEqual(add, ["C00001", 1, D("5"), D("2.50")])
        f.dtree.selection_set("0")
        f.det_modify()
        f.dtree.selection_set("0")
        f.det_remove()
        f.change_state("Aprobado"); f.delete(); f.reactivate()
        for n in ("sp_detalle_modificar", "sp_detalle_quitar", "sp_cotizacion_cambiar_estado",
                  "sp_cotizacion_eliminar", "sp_cotizacion_reactivar"):
            self.assertIn(n, self.names())

    def test_validaciones(self):
        f = self.f
        f.new(); f.v["fecha"].set("19-11-2026"); f.save()
        self.assertEqual(len(BOX["warn"]), 1)                 # fecha inválida
        f.tree.selection_set("0")
        for bad in ("abc", "NaN", "-1", "0"):
            f.d_item.set_id(1); f.d_cant.set(bad); f.d_precio.set("1")
            self.assertIsNone(f._det_values())


class ReporteTests(unittest.TestCase):
    def test_todos_los_reportes(self):
        db = FakeDB()
        f = ui_reportes.ReportesFrame(W(), db)
        self.assertEqual(len(ui_reportes.REPORTS), 12)
        joins = sum(1 for r in ui_reportes.REPORTS if "JOIN" in r[0])
        self.assertGreaterEqual(joins, 6)
        for i, (title, proc, spec) in enumerate(ui_reportes.REPORTS):
            self.assertIn(proc, SIGS, proc)
            self.assertEqual(SIGS[proc], len(spec), proc)
            f.listbox.curselection = (lambda i=i: (i,))
            f._on_pick()
            if spec and spec[0][0] == "cotizacion":
                f.getters = [("Cotización", "cotizacion", True, lambda: "C00001")]
            args = f._collect()
            self.assertIsNotNone(args, title)
            f.run()
            self.assertEqual(db.calls[-1][0], proc)
            self.assertEqual(f.last_keys, ["Col_A", "Col_B"])


class SqlConsistency(unittest.TestCase):
    def test_todos_los_sp_usados_existen(self):
        """Todo 'sp_...' mencionado en el código de la app existe en el script."""
        used = set()
        for fn in os.listdir(os.path.join(ROOT, "app")):
            if fn.endswith(".py"):
                with open(os.path.join(ROOT, "app", fn), encoding="utf-8") as fh:
                    used |= set(re.findall(r"\b(sp_[a-z_]+)", fh.read()))
        prefix_ok = {"sp_%s_listar", "sp_%s_insertar"}
        for name in used:
            if name in SIGS or name.endswith("_") or name in ("sp_",):
                continue
            self.fail("Procedimiento usado pero no definido: " + name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
