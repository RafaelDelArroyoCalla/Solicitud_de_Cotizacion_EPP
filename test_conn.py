import mysql.connector, sys
cfg = {
    'host':'localhost',
    'port':3306,
    'user':'app_cotizaciones',
    'password':'Luna2026!',
    'database':'sistema_cotizaciones'
}
try:
    cnx = mysql.connector.connect(**cfg)
    cursor = cnx.cursor()
    cursor.execute('SHOW TABLES;')
    rows = cursor.fetchall()
    print('Connection OK. Tables:')
    for r in rows:
        print(r[0])
    cursor.close()
    cnx.close()
except mysql.connector.Error as err:
    print('Error:', err)
    sys.exit(1)
