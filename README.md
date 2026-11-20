# Sistema de Cotizaciones — Entrega 5 (aplicativo cliente)

Aplicativo de escritorio que consume la base de datos MySQL `sistema_cotizaciones` (Entrega 4).

- **Lenguaje:** Python 3.10+ con Tkinter (biblioteca estándar).
- **Acceso a BD:** `mysql-connector-python` (driver nativo). **Sin frameworks ni ORM.**
- **Toda operación de datos se hace con procedimientos almacenados** (45 procedimientos, 2 funciones, 26 triggers).

## Puesta en marcha

1. Tener MySQL 8.0+ encendido y Python 3.10+ instalado (con Tkinter; viene por defecto en Windows).
2. Doble clic en `run.bat` (o `pip install -r requirements.txt` y `python app/main.py`).
3. En la ventana de conexión escriba servidor, puerto, usuario y contraseña.
4. **Primera vez:** pulse **Instalar base de datos…** (ejecuta `sql/sistema_cotizaciones_completo.sql`; borra y recrea la BD con datos de prueba).
5. Pulse **Probar conexión** y luego **Conectar**.

El script también puede ejecutarse a mano en MySQL Workbench / consola (`mysql -u root -p < sql/sistema_cotizaciones_completo.sql`).

## Ejecutable (Windows)

Ejecute `build_exe.bat`; genera `dist/SistemaCotizaciones.exe` (el script SQL va incluido).

## Estructura

```
app/        main.py · db.py · config.py · sqlrunner.py · ui_conexion.py · ui_crud.py · ui_cotizaciones.py · ui_reportes.py · ui_common.py
sql/        sistema_cotizaciones_completo.sql  (= 01_esquema + 02_datos + 03_procedimientos + 04_triggers)
tests/      pruebas automáticas
```

## Características del sistema

| Característica | Descripción |
|---|---|
| Aplicativo cliente sin frameworks | `app/` — Tkinter + driver nativo |
| Operaciones CRUD con borrado lógico | Pestañas Cotizaciones, Clientes, Proveedores, Ítems, Especificaciones. Columna `Activo`; botones *Dar de baja* / *Reactivar* |
| Procedimientos y triggers | `sql/03_procedimientos.sql` y `sql/04_triggers.sql` |
| Reportes con JOIN | Pestaña **Reportes**: 12 reportes, 9 con JOIN (R1‑R9). Exportables a CSV |
| Datos de prueba extensos | 12 clientes, 12 proveedores, 22 ubigeos, 9 especificaciones, 26 ítems, 30 cotizaciones, 118 líneas de detalle |


| Requisito | Dónde |
|---|---|
| Aplicativo cliente sin frameworks | `app/` — Tkinter + driver nativo |
| Insertar, modificar y borrar (borrado lógico) | Pestañas Cotizaciones, Clientes, Proveedores, Ítems, Especificaciones. Columna `Activo`; botones *Dar de baja* / *Reactivar* |
| Procedimientos y triggers para todo | `sql/03_procedimientos.sql` (`sp_<entidad>_listar/insertar/modificar/eliminar/reactivar`) y `sql/04_triggers.sql` |
| ≥ 10 reportes, ≥ 6 con JOIN | Pestaña **Reportes**: 12 reportes, 9 con JOIN (R1–R9). Exportables a CSV |
| Script con más datos | 12 clientes, 12 proveedores, 22 ubigeos, 9 especificaciones, 26 ítems de EPP, 30 cotizaciones, 118 líneas de detalle (ficticios, enfocados en EPP) |

### Reglas de negocio (procedimientos + triggers)
- DNI = 8 dígitos / RUC = 11 dígitos; no se repiten llaves; un registro dado de baja se *reactiva*, no se duplica.
- Una cotización nueva siempre nace **Pendiente**; solo una Pendiente se puede modificar, editar su detalle, aprobar o rechazar. No se aprueba sin ítems. Aprobada/Rechazada no cambia de estado. No se da de baja una Aprobada.
- No se da de baja un cliente, proveedor, especificación o ítem usado por cotizaciones Pendientes.
- `DELETE` físico bloqueado por trigger en todas las tablas de negocio.
- La fecha de solicitud no puede ser futura.
- Auditoría automática (tabla `Auditoria`, reporte R12) de altas, cambios, bajas, reactivaciones y cambios de estado.

## Pruebas

```
python tests/test_sqlrunner.py
python tests/test_ui_logic.py
```
La segunda simula Tkinter y MySQL y verifica que cada llamada de la interfaz coincida con la firma rea
