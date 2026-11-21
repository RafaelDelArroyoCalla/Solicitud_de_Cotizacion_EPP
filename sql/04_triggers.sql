-- 4. TRIGGERS -------------------------------------------------
-- (a) Reglas de integridad que se cumplen aunque alguien use SQL directo.
-- (b) Prohibición del DELETE físico (solo baja lógica).
-- (c) Auditoría automática en la tabla Auditoria.

DELIMITER $$

-- ===== COTIZACIÓN: validaciones =====

CREATE TRIGGER trg_cotizacion_bi BEFORE INSERT ON Cotizacion
FOR EACH ROW
BEGIN
    IF NEW.Fecha_solicitud > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha de solicitud no puede ser futura.';
    END IF;
    IF NEW.Estado <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Toda cotización nueva debe iniciar en estado Pendiente.';
    END IF;
END$$

CREATE TRIGGER trg_cotizacion_bu BEFORE UPDATE ON Cotizacion
FOR EACH ROW
BEGIN
    IF NEW.Fecha_solicitud <> OLD.Fecha_solicitud AND NEW.Fecha_solicitud > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha de solicitud no puede ser futura.';
    END IF;
    IF OLD.Estado <> 'Pendiente' AND NEW.Estado <> OLD.Estado THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una cotización Aprobada o Rechazada ya no puede cambiar de estado.';
    END IF;
    IF OLD.Activo = 1 AND NEW.Activo = 0 AND OLD.Estado = 'Aprobado' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede dar de baja una cotización Aprobada.';
    END IF;
END$$

-- ===== DETALLE: solo editable mientras la cotización esté Pendiente =====

CREATE TRIGGER trg_detalle_bi BEFORE INSERT ON Detalle_Cotizacion
FOR EACH ROW
BEGIN
    IF IFNULL((SELECT Estado FROM Cotizacion WHERE Num_solicitud = NEW.Num_solicitud), '') <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar el detalle de cotizaciones Pendientes.';
    END IF;
END$$

CREATE TRIGGER trg_detalle_bu BEFORE UPDATE ON Detalle_Cotizacion
FOR EACH ROW
BEGIN
    IF IFNULL((SELECT Estado FROM Cotizacion WHERE Num_solicitud = NEW.Num_solicitud), '') <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar el detalle de cotizaciones Pendientes.';
    END IF;
END$$

-- ===== BAJA LÓGICA: no se da de baja lo que está en uso por cotizaciones Pendientes =====

CREATE TRIGGER trg_cliente_bu BEFORE UPDATE ON Cliente
FOR EACH ROW
BEGIN
    IF OLD.Activo = 1 AND NEW.Activo = 0
       AND EXISTS (SELECT 1 FROM Cotizacion
                   WHERE ID_Cliente = OLD.DNI_RUC AND Activo = 1 AND Estado = 'Pendiente') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente tiene cotizaciones Pendientes; no se puede dar de baja.';
    END IF;
END$$

CREATE TRIGGER trg_proveedor_bu BEFORE UPDATE ON Proveedor
FOR EACH ROW
BEGIN
    IF OLD.Activo = 1 AND NEW.Activo = 0
       AND EXISTS (SELECT 1 FROM Cotizacion
                   WHERE ID_Proveedor = OLD.RUC_Proveedor AND Activo = 1 AND Estado = 'Pendiente') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor tiene cotizaciones Pendientes; no se puede dar de baja.';
    END IF;
END$$

CREATE TRIGGER trg_especificacion_bu BEFORE UPDATE ON Especificacion_Tecnica
FOR EACH ROW
BEGIN
    IF OLD.Activo = 1 AND NEW.Activo = 0
       AND EXISTS (SELECT 1 FROM Cotizacion
                   WHERE ID_Especificacion_Tecnica = OLD.ID_Especificacion_Tecnica
                     AND Activo = 1 AND Estado = 'Pendiente') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La especificación tiene cotizaciones Pendientes; no se puede dar de baja.';
    END IF;
END$$

CREATE TRIGGER trg_item_bu BEFORE UPDATE ON Item
FOR EACH ROW
BEGIN
    IF OLD.Activo = 1 AND NEW.Activo = 0
       AND EXISTS (SELECT 1
                   FROM Detalle_Cotizacion d
                   JOIN Cotizacion c ON c.Num_solicitud = d.Num_solicitud
                   WHERE d.ID_Item = OLD.ID_Item AND d.Activo = 1
                     AND c.Activo = 1 AND c.Estado = 'Pendiente') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ítem está en cotizaciones Pendientes; no se puede dar de baja.';
    END IF;
END$$

-- ===== PROHIBIR DELETE FÍSICO =====

CREATE TRIGGER trg_cliente_bd BEFORE DELETE ON Cliente
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite borrar físicamente; use la baja lógica (Activo = 0).';
END$$

CREATE TRIGGER trg_proveedor_bd BEFORE DELETE ON Proveedor
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite borrar físicamente; use la baja lógica (Activo = 0).';
END$$

CREATE TRIGGER trg_especificacion_bd BEFORE DELETE ON Especificacion_Tecnica
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite borrar físicamente; use la baja lógica (Activo = 0).';
END$$

CREATE TRIGGER trg_item_bd BEFORE DELETE ON Item
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite borrar físicamente; use la baja lógica (Activo = 0).';
END$$

CREATE TRIGGER trg_cotizacion_bd BEFORE DELETE ON Cotizacion
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite borrar físicamente; use la baja lógica (Activo = 0).';
END$$

CREATE TRIGGER trg_detalle_bd BEFORE DELETE ON Detalle_Cotizacion
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite borrar físicamente; use la baja lógica (Activo = 0).';
END$$

-- ===== AUDITORÍA =====

CREATE TRIGGER trg_cliente_ai AFTER INSERT ON Cliente
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Cliente', 'INSERT', NEW.DNI_RUC, CONCAT('Alta: ', NEW.Razon_social));
END$$

CREATE TRIGGER trg_cliente_au AFTER UPDATE ON Cliente
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Cliente',
        CASE WHEN OLD.Activo = 1 AND NEW.Activo = 0 THEN 'BAJA_LOGICA'
             WHEN OLD.Activo = 0 AND NEW.Activo = 1 THEN 'REACTIVACION'
             ELSE 'UPDATE' END,
        NEW.DNI_RUC, NEW.Razon_social);
END$$

CREATE TRIGGER trg_proveedor_ai AFTER INSERT ON Proveedor
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Proveedor', 'INSERT', NEW.RUC_Proveedor, CONCAT('Alta: ', NEW.Razon_Social));
END$$

CREATE TRIGGER trg_proveedor_au AFTER UPDATE ON Proveedor
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Proveedor',
        CASE WHEN OLD.Activo = 1 AND NEW.Activo = 0 THEN 'BAJA_LOGICA'
             WHEN OLD.Activo = 0 AND NEW.Activo = 1 THEN 'REACTIVACION'
             ELSE 'UPDATE' END,
        NEW.RUC_Proveedor, NEW.Razon_Social);
END$$

CREATE TRIGGER trg_item_ai AFTER INSERT ON Item
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Item', 'INSERT', CAST(NEW.ID_Item AS CHAR), CONCAT('Alta: ', NEW.Descripcion_Item));
END$$

CREATE TRIGGER trg_item_au AFTER UPDATE ON Item
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Item',
        CASE WHEN OLD.Activo = 1 AND NEW.Activo = 0 THEN 'BAJA_LOGICA'
             WHEN OLD.Activo = 0 AND NEW.Activo = 1 THEN 'REACTIVACION'
             ELSE 'UPDATE' END,
        CAST(NEW.ID_Item AS CHAR), NEW.Descripcion_Item);
END$$

CREATE TRIGGER trg_especificacion_ai AFTER INSERT ON Especificacion_Tecnica
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Especificacion', 'INSERT', CAST(NEW.ID_Especificacion_Tecnica AS CHAR),
                          CONCAT('Alta: ', NEW.Obra_denominacion));
END$$

CREATE TRIGGER trg_especificacion_au AFTER UPDATE ON Especificacion_Tecnica
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Especificacion',
        CASE WHEN OLD.Activo = 1 AND NEW.Activo = 0 THEN 'BAJA_LOGICA'
             WHEN OLD.Activo = 0 AND NEW.Activo = 1 THEN 'REACTIVACION'
             ELSE 'UPDATE' END,
        CAST(NEW.ID_Especificacion_Tecnica AS CHAR), NEW.Obra_denominacion);
END$$

CREATE TRIGGER trg_cotizacion_ai AFTER INSERT ON Cotizacion
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Cotizacion', 'INSERT', NEW.Num_solicitud, CONCAT('Alta: ', NEW.Concepto));
END$$

CREATE TRIGGER trg_cotizacion_au AFTER UPDATE ON Cotizacion
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Cotizacion',
        CASE WHEN OLD.Activo = 1 AND NEW.Activo = 0 THEN 'BAJA_LOGICA'
             WHEN OLD.Activo = 0 AND NEW.Activo = 1 THEN 'REACTIVACION'
             WHEN OLD.Estado <> NEW.Estado THEN 'CAMBIO_ESTADO'
             ELSE 'UPDATE' END,
        NEW.Num_solicitud,
        CASE WHEN OLD.Estado <> NEW.Estado THEN CONCAT('Estado: ', OLD.Estado, ' -> ', NEW.Estado)
             ELSE NEW.Concepto END);
END$$

CREATE TRIGGER trg_detalle_ai AFTER INSERT ON Detalle_Cotizacion
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Detalle_Cotizacion', 'INSERT', CONCAT(NEW.Num_solicitud, '/', NEW.ID_Item),
                          CONCAT('Cant ', NEW.Cantidad_Requerida, ' x ', NEW.Precio_Unitario));
END$$

CREATE TRIGGER trg_detalle_au AFTER UPDATE ON Detalle_Cotizacion
FOR EACH ROW
BEGIN
    CALL sp_aud_registrar('Detalle_Cotizacion',
        CASE WHEN OLD.Activo = 1 AND NEW.Activo = 0 THEN 'BAJA_LOGICA'
             WHEN OLD.Activo = 0 AND NEW.Activo = 1 THEN 'REACTIVACION'
             ELSE 'UPDATE' END,
        CONCAT(NEW.Num_solicitud, '/', NEW.ID_Item),
        CONCAT('Cant ', NEW.Cantidad_Requerida, ' x ', NEW.Precio_Unitario));
END$$

DELIMITER ;
