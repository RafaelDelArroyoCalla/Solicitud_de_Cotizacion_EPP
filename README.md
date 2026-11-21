# Sistema de Cotizaciones — Solicitud de Cotización de EPP

Aplicativo de escritorio que consume la base de datos MySQL `sistema_cotizaciones` para registrar y controlar las solicitudes de cotización de equipos de protección personal (EPP).

- **Lenguaje:** Python 3.10+ con Tkinter (biblioteca estándar).
- **Acceso a BD:** `mysql-connector-python` (driver nativo). Sin frameworks ni ORM.
- **Toda operación de datos se hace con procedimientos almacenados:** 45 procedimientos, 2 funciones y 26 triggers.

## Puesta en marcha

1. Tener MySQL 8.0 o superior encendido y Python 3.10+ instalado (Tkinter viene por defecto en Windows).
2. **Crear el usuario de la aplicación** (solo una vez): abra `sql/create_user.sql`, reemplace `<CAMBIAR_CONTRASEÑA>` por una contraseña propia y ejecute el script con un usuario administrador (por ejemplo `root`).
3. Doble clic en `run.bat` (o `pip install -r requirements.txt` y `python app\main.py`).
4. **Primera vez:** en la ventana de conexión ingrese el usuario **administrador** y pulse **Instalar base de datos…**. Este paso ejecuta `sql/sistema_cotizaciones_completo.sql`, que borra la base `sistema_cotizaciones` si existe y la recrea con datos de prueba. Solo se hace una vez.
5. Para el uso diario, ingrese el usuario `app_cotizaciones` y su contraseña, pulse **Probar conexión** y luego **Conectar**.

> La contraseña no se guarda en `config.ini`; se solicita en la ventana de conexión.

El script también puede ejecutarse a mano en MySQL Workbench o en consola:
`mysql -u root -p < sql/sistema_cotizaciones_completo.sql`

## Ejecutable (Windows)

Ejecute `build_exe.bat`. Genera `dist/SistemaCotizaciones.exe`, que incluye el script SQL.

## Estructura

```
app/        main.py · db.py · config.py · sqlrunner.py · ui_conexion.py · ui_crud.py · ui_cotizaciones.py · ui_reportes.py · ui_common.py
sql/        create_user.sql                    (usuario de la aplicación)
            sistema_cotizaciones_completo.sql  (= 01_esquema + 02_datos + 03_procedimientos + 04_triggers)
            01_esquema.sql · 02_datos.sql · 03_procedimientos.sql · 04_triggers.sql
tests/      pruebas automáticas
```

## Características del sistema

| Característica | Descripción |
|---|---|
| Aplicativo cliente sin frameworks | `app/`: Tkinter y driver nativo de MySQL |
| Operaciones CRUD con borrado lógico | Pestañas Cotizaciones, Clientes, Proveedores, Ítems y Especificaciones. Columna `Activo`; botones *Dar de baja* y *Reactivar* |
| Procedimientos y triggers | `sql/03_procedimientos.sql` (`sp_<entidad>_listar/insertar/modificar/eliminar/reactivar`) y `sql/04_triggers.sql` |
| Reportes con JOIN | Pestaña **Reportes**: 12 reportes, 9 con JOIN (R1 a R9). Exportables a CSV |
| Datos de prueba | 12 clientes, 12 proveedores, 22 ubigeos, 9 especificaciones, 26 ítems de EPP, 30 cotizaciones y 118 líneas de detalle (ficticios) |

### Reglas de negocio (procedimientos y triggers)
- DNI de 8 dígitos o RUC de 11 dígitos; no se repiten llaves. Un registro dado de baja se *reactiva*, no se duplica.
- Una cotización nueva siempre nace **Pendiente**. Solo una Pendiente se puede modificar, editar en su detalle, aprobar o rechazar. No se aprueba sin ítems. Una Aprobada o Rechazada no cambia de estado, y una Aprobada no se da de baja.
- No se da de baja un cliente, proveedor, especificación o ítem usado por cotizaciones Pendientes.
- El `DELETE` físico está bloqueado por trigger en todas las tablas de negocio.
- La fecha de solicitud no puede ser futura.
- Auditoría automática en la tabla `Auditoria` (reporte R12) de altas, cambios, bajas, reactivaciones y cambios de estado.

## Pruebas

```
python tests/test_sqlrunner.py
python tests/test_ui_logic.py
```

La segunda prueba simula Tkinter y MySQL, y verifica que cada llamada de la interfaz coincida con la firma real de los procedimientos.
