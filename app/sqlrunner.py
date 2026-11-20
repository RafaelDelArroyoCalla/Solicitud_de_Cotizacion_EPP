"""Ejecuta un script .sql con soporte de DELIMITER (procedimientos y triggers)."""


def split_script(text):
    """Divide el script en sentencias respetando cadenas, comentarios y DELIMITER."""
    statements = []
    delim = ";"
    buf = []
    i, n = 0, len(text)

    def at_statement_start():
        return "".join(buf).strip() == ""

    while i < n:
        ch = text[i]

        # Directiva DELIMITER (solo al inicio de una sentencia)
        if at_statement_start() and text[i:i + 9].upper() == "DELIMITER" and (i + 9 < n and text[i + 9] in " \t"):
            j = text.find("\n", i)
            j = n if j == -1 else j
            delim = text[i + 9:j].strip()
            buf = []
            i = j + 1
            continue

        # Comentarios (se descartan)
        if ch == "#" or (text.startswith("--", i) and (i + 2 >= n or text[i + 2] in " \t\r\n")):
            j = text.find("\n", i)
            i = n if j == -1 else j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue

        # Cadenas e identificadores entre comillas
        if ch in ("'", '"', "`"):
            quote = ch
            buf.append(ch)
            i += 1
            while i < n:
                c = text[i]
                buf.append(c)
                if c == "\\" and quote != "`" and i + 1 < n:
                    buf.append(text[i + 1])
                    i += 2
                    continue
                if c == quote:
                    if i + 1 < n and text[i + 1] == quote:   # comilla duplicada
                        buf.append(text[i + 1])
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            continue

        # Fin de sentencia
        if text.startswith(delim, i):
            stmt = "".join(buf).strip()
            if stmt:
                statements.append(stmt)
            buf = []
            i += len(delim)
            continue

        buf.append(ch)
        i += 1

    tail = "".join(buf).strip()
    if tail:
        statements.append(tail)
    return statements


class ScriptError(Exception):
    """Falla al ejecutar una sentencia del script."""

    def __init__(self, index, snippet, original):
        super().__init__("Sentencia %d: %s" % (index, original))
        self.index, self.snippet, self.original = index, snippet, original


def run_script(connection, text, progress=None):
    """Ejecuta todas las sentencias; devuelve cuántas se ejecutaron."""
    statements = split_script(text)
    cursor = connection.cursor()
    idx = 0
    try:
        for idx, stmt in enumerate(statements, 1):
            try:
                cursor.execute(stmt)
                if cursor.with_rows:            # descartar posibles resultados pendientes
                    cursor.fetchall()
            except Exception as e:  # noqa: BLE001 - se re-lanza con contexto
                snippet = " ".join(stmt.split())[:70]
                raise ScriptError(idx, snippet, getattr(e, "msg", None) or str(e)) from e
            if progress:
                progress(idx, len(statements))
    finally:
        cursor.close()
    return len(statements)
