"""Acceso nativo a MySQL con mysql-connector-python (sin ORM ni frameworks).
Toda operación de datos se hace llamando a procedimientos almacenados."""
import datetime
import decimal

import mysql.connector
from mysql.connector import Error


class DBError(Exception):
    """Error de base de datos con mensaje apto para mostrar al usuario."""


def friendly_message(err):
    errno = getattr(err, "errno", None)
    msg = getattr(err, "msg", None) or str(err)
    if errno == 1644:                       # SIGNAL SQLSTATE '45000' (reglas de negocio / triggers)
        return msg
    if errno == 1045:
        return "Usuario o contraseña incorrectos."
    if errno == 1049:
        return "La base de datos indicada no existe. Use 'Instalar base de datos'."
    if errno in (2003, 2002, 2005):
        return "No se pudo contactar al servidor MySQL (¿está encendido? ¿host y puerto correctos?)."
    if errno == 1305:
        return "Falta un procedimiento en la base de datos. Reinstale el script completo."
    if errno:
        return "%s (error MySQL %s)" % (msg, errno)
    return msg


def normalize(value):
    if isinstance(value, (bytes, bytearray)):
        return bytes(value).decode("utf-8", errors="replace")
    return value


def _rows_from(cursor):
    cols = [d[0] for d in (cursor.description or [])]
    out = []
    for row in cursor.fetchall():
        if isinstance(row, dict):
            out.append({k: normalize(v) for k, v in row.items()})
        else:
            out.append({c: normalize(v) for c, v in zip(cols, row)})
    return out


def to_text(value):
    """Texto para mostrar en tablas."""
    if value is None:
        return ""
    if isinstance(value, decimal.Decimal):
        return "{:,.2f}".format(value)
    if isinstance(value, float):
        return "{:,.2f}".format(value)
    if isinstance(value, (datetime.datetime,)):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, datetime.date):
        return value.isoformat()
    return str(value)


class Database:
    def __init__(self):
        self.conn = None
        self.info = ""

    # -- conexión ---------------------------------------------------------
    @property
    def connected(self):
        return self.conn is not None and self.conn.is_connected()

    def _open(self, host, port, user, password, database):
        try:
            return mysql.connector.connect(
                host=host, port=int(port), user=user, password=password,
                database=database or None, charset="utf8mb4", collation="utf8mb4_unicode_ci",
                use_pure=True, autocommit=True, connection_timeout=8)
        except (Error, ValueError) as e:
            raise DBError(friendly_message(e) if isinstance(e, Error) else "Puerto inválido.") from e

    def connect(self, host, port, user, password, database):
        self.close()
        self.conn = self._open(host, port, user, password, database)
        self.info = "%s@%s:%s/%s" % (user, host, port, database)

    def connect_server_only(self, host, port, user, password):
        """Conexión sin base de datos (para instalar el script)."""
        self.close()
        self.conn = self._open(host, port, user, password, None)
        self.info = "%s@%s:%s" % (user, host, port)

    def close(self):
        if self.conn is not None:
            try:
                self.conn.close()
            except Error:
                pass
        self.conn = None

    # -- prueba de conexión (reunión 10) ----------------------------------
    def test_connection(self, host, port, user, password, database):
        """Devuelve una lista de (ok, texto) con cada paso de la prueba."""
        steps = []
        conn = None
        try:
            conn = self._open(host, port, user, password, None)
            steps.append((True, "Servidor MySQL alcanzado en %s:%s con el usuario '%s'." % (host, port, user)))
            cur = conn.cursor()
            cur.execute("SELECT VERSION()")
            steps.append((True, "Versión del servidor: %s" % cur.fetchone()[0]))
            cur.execute("SHOW DATABASES LIKE %s", (database,))
            if not cur.fetchall():
                steps.append((False, "La base de datos '%s' no existe todavía. Use 'Instalar base de datos'." % database))
                cur.close()
                return steps
            steps.append((True, "La base de datos '%s' existe." % database))
            cur.execute("USE `%s`" % database.replace("`", "``"))
            cur.execute("SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = %s", (database,))
            routines = cur.fetchone()[0]
            if routines == 0:
                steps.append((False, "La base existe pero no tiene procedimientos. Use 'Instalar base de datos'."))
                cur.close()
                return steps
            cur.callproc("sp_prueba_conexion")
            for rs in cur.stored_results():
                rows = _rows_from(rs)
                if rows:
                    r = rows[0]
                    steps.append((True, "Procedimiento sp_prueba_conexion OK: %s tablas, %s rutinas, %s triggers."
                                  % (r.get("Tablas"), r.get("Rutinas"), r.get("Triggers"))))
            cur.close()
        except Error as e:
            steps.append((False, friendly_message(e)))
        except DBError as e:
            steps.append((False, str(e)))
        finally:
            if conn is not None:
                try:
                    conn.close()
                except Error:
                    pass
        return steps

    # -- llamadas a procedimientos ----------------------------------------
    def call(self, proc, args=()):
        """Ejecuta CALL proc(args). Devuelve una lista de resultados (cada uno: lista de dicts)."""
        if self.conn is None:
            raise DBError("No hay conexión con la base de datos.")
        try:
            self.conn.ping(reconnect=True, attempts=2, delay=1)   # reconecta si el servidor cerró la sesión
        except Error as e:
            raise DBError(friendly_message(e)) from e
        cur = self.conn.cursor()
        try:
            cur.callproc(proc, list(args))
            return [_rows_from(rs) for rs in cur.stored_results()]
        except Error as e:
            raise DBError(friendly_message(e)) from e
        finally:
            cur.close()

    def rows(self, proc, args=()):
        """Primer conjunto de resultados del procedimiento (lista de dicts)."""
        result = self.call(proc, args)
        return result[0] if result else []
