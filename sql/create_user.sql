-- -------------------------------------------------------------------
-- Script para crear el usuario de la aplicación (app_cotizaciones)
-- -------------------------------------------------------------------
-- Asegúrese de ejecutar este script con un usuario que tenga privilegios
-- de CREATE USER y GRANT (por ejemplo, root).

CREATE USER IF NOT EXISTS 'app_cotizaciones'@'localhost'
    IDENTIFIED WITH caching_sha2_password BY 'Luna2026!';

CREATE USER IF NOT EXISTS 'app_cotizaciones'@'127.0.0.1'
    IDENTIFIED WITH caching_sha2_password BY 'Luna2026!';

GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
    ON sistema_cotizaciones.* TO 'app_cotizaciones'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
    ON sistema_cotizaciones.* TO 'app_cotizaciones'@'127.0.0.1';

FLUSH PRIVILEGES;
