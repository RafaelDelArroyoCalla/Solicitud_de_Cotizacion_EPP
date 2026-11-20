-- 3. FUNCIONES Y PROCEDIMIENTOS ALMACENADOS -----------------
-- El aplicativo SOLO accede a la base de datos mediante estos procedimientos.
-- Convención de parámetros: p_xxx (entrada), v_xxx (variables locales).
-- Los errores de negocio se lanzan con SIGNAL SQLSTATE '45000'.

DELIMITER $$

-- ---------- Funciones auxiliares ----------

CREATE FUNCTION fn_total_cotizacion(p_num VARCHAR(6))
RETURNS DECIMAL(14,2)
READS SQL DATA
BEGIN
    RETURN IFNULL((SELECT SUM(Cantidad_Requerida * Precio_Unitario)
                   FROM Detalle_Cotizacion
                   WHERE Num_solicitud = p_num AND Activo = 1), 0);
END$$

CREATE FUNCTION fn_siguiente_num_solicitud()
RETURNS VARCHAR(6)
READS SQL DATA
BEGIN
    DECLARE v_max INT;
    SET v_max = (SELECT IFNULL(MAX(CAST(SUBSTRING(Num_solicitud, 2) AS UNSIGNED)), 0)
                 FROM Cotizacion
                 WHERE Num_solicitud REGEXP '^C[0-9]{5}$');
    RETURN CONCAT('C', LPAD(v_max + 1, 5, '0'));
END$$

-- ---------- Conexión y auditoría ----------

CREATE PROCEDURE sp_prueba_conexion()
BEGIN
    SELECT VERSION() AS Version_MySQL,
           DATABASE() AS Base_de_datos,
           CURRENT_USER() AS Usuario,
           (SELECT COUNT(*) FROM information_schema.TABLES
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE') AS Tablas,
           (SELECT COUNT(*) FROM information_schema.ROUTINES
             WHERE ROUTINE_SCHEMA = DATABASE()) AS Rutinas,
           (SELECT COUNT(*) FROM information_schema.TRIGGERS
             WHERE TRIGGER_SCHEMA = DATABASE()) AS Triggers;
END$$

-- Usado por los triggers para registrar en la bitácora
CREATE PROCEDURE sp_aud_registrar(IN p_tabla VARCHAR(30), IN p_operacion VARCHAR(20),
                                  IN p_llave VARCHAR(60), IN p_detalle VARCHAR(400))
BEGIN
    INSERT INTO Auditoria (Tabla, Operacion, Llave, Detalle, Usuario)
    VALUES (p_tabla, p_operacion, p_llave, p_detalle, USER());
END$$

-- ---------- Ubigeo (catálogo, solo lectura) ----------

CREATE PROCEDURE sp_ubigeo_listar()
BEGIN
    SELECT Ubigeo, Departamento, Provincia, Distrito
    FROM Ubigeo
    ORDER BY Departamento, Provincia, Distrito;
END$$

-- ---------- CLIENTE ----------

CREATE PROCEDURE sp_cliente_listar(IN p_buscar VARCHAR(100), IN p_inactivos TINYINT)
BEGIN
    SELECT DNI_RUC, Razon_social, Direccion, Activo
    FROM Cliente
    WHERE (p_inactivos = 1 OR Activo = 1)
      AND (p_buscar IS NULL OR p_buscar = ''
           OR DNI_RUC LIKE CONCAT('%', p_buscar, '%')
           OR Razon_social LIKE CONCAT('%', p_buscar, '%'))
    ORDER BY Razon_social;
END$$

CREATE PROCEDURE sp_cliente_insertar(IN p_dni VARCHAR(50), IN p_razon VARCHAR(150), IN p_dir VARCHAR(200))
BEGIN
    DECLARE v_activo TINYINT;
    SET p_dni = TRIM(p_dni), p_razon = TRIM(p_razon), p_dir = TRIM(p_dir);
    IF p_dni IS NULL OR p_dni NOT REGEXP '^([0-9]{8}|[0-9]{11})$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El DNI debe tener 8 dígitos o el RUC 11 dígitos numéricos.';
    END IF;
    IF p_razon IS NULL OR p_razon = '' OR p_dir IS NULL OR p_dir = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La razón social y la dirección son obligatorias.';
    END IF;
    SET v_activo = (SELECT Activo FROM Cliente WHERE DNI_RUC = p_dni);
    IF v_activo = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un cliente con ese DNI/RUC.';
    ELSEIF v_activo = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese DNI/RUC existe dado de baja. Use la opción Reactivar.';
    END IF;
    INSERT INTO Cliente (DNI_RUC, Razon_social, Direccion) VALUES (p_dni, p_razon, p_dir);
END$$

CREATE PROCEDURE sp_cliente_modificar(IN p_dni VARCHAR(50), IN p_razon VARCHAR(150), IN p_dir VARCHAR(200))
BEGIN
    SET p_razon = TRIM(p_razon), p_dir = TRIM(p_dir);
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE DNI_RUC = p_dni AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o está dado de baja.';
    END IF;
    IF p_razon IS NULL OR p_razon = '' OR p_dir IS NULL OR p_dir = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La razón social y la dirección son obligatorias.';
    END IF;
    UPDATE Cliente SET Razon_social = p_razon, Direccion = p_dir WHERE DNI_RUC = p_dni;
END$$

CREATE PROCEDURE sp_cliente_eliminar(IN p_dni VARCHAR(50))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE DNI_RUC = p_dni AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o ya está dado de baja.';
    END IF;
    UPDATE Cliente SET Activo = 0 WHERE DNI_RUC = p_dni;   -- baja lógica
END$$

CREATE PROCEDURE sp_cliente_reactivar(IN p_dni VARCHAR(50))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE DNI_RUC = p_dni AND Activo = 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o ya está activo.';
    END IF;
    UPDATE Cliente SET Activo = 1 WHERE DNI_RUC = p_dni;
END$$

-- ---------- PROVEEDOR ----------

CREATE PROCEDURE sp_proveedor_listar(IN p_buscar VARCHAR(100), IN p_inactivos TINYINT)
BEGIN
    SELECT p.RUC_Proveedor, p.Razon_Social, p.Ubigeo,
           CONCAT(u.Departamento, ' / ', u.Provincia, ' / ', u.Distrito) AS Ubicacion,
           p.Referencia, p.Activo
    FROM Proveedor p
    JOIN Ubigeo u ON u.Ubigeo = p.Ubigeo
    WHERE (p_inactivos = 1 OR p.Activo = 1)
      AND (p_buscar IS NULL OR p_buscar = ''
           OR p.RUC_Proveedor LIKE CONCAT('%', p_buscar, '%')
           OR p.Razon_Social LIKE CONCAT('%', p_buscar, '%')
           OR u.Departamento LIKE CONCAT('%', p_buscar, '%'))
    ORDER BY p.Razon_Social;
END$$

CREATE PROCEDURE sp_proveedor_insertar(IN p_ruc VARCHAR(50), IN p_razon VARCHAR(150),
                                       IN p_ubigeo VARCHAR(10), IN p_ref VARCHAR(150))
BEGIN
    DECLARE v_activo TINYINT;
    SET p_ruc = TRIM(p_ruc), p_razon = TRIM(p_razon), p_ref = NULLIF(TRIM(p_ref), '');
    IF p_ruc IS NULL OR p_ruc NOT REGEXP '^[0-9]{11}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El RUC debe tener 11 dígitos numéricos.';
    END IF;
    IF p_razon IS NULL OR p_razon = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La razón social es obligatoria.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Ubigeo WHERE Ubigeo = p_ubigeo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ubigeo indicado no existe.';
    END IF;
    SET v_activo = (SELECT Activo FROM Proveedor WHERE RUC_Proveedor = p_ruc);
    IF v_activo = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un proveedor con ese RUC.';
    ELSEIF v_activo = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese RUC existe dado de baja. Use la opción Reactivar.';
    END IF;
    INSERT INTO Proveedor (RUC_Proveedor, Razon_Social, Ubigeo, Referencia)
    VALUES (p_ruc, p_razon, p_ubigeo, p_ref);
END$$

CREATE PROCEDURE sp_proveedor_modificar(IN p_ruc VARCHAR(50), IN p_razon VARCHAR(150),
                                        IN p_ubigeo VARCHAR(10), IN p_ref VARCHAR(150))
BEGIN
    SET p_razon = TRIM(p_razon), p_ref = NULLIF(TRIM(p_ref), '');
    IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE RUC_Proveedor = p_ruc AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe o está dado de baja.';
    END IF;
    IF p_razon IS NULL OR p_razon = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La razón social es obligatoria.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Ubigeo WHERE Ubigeo = p_ubigeo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ubigeo indicado no existe.';
    END IF;
    UPDATE Proveedor SET Razon_Social = p_razon, Ubigeo = p_ubigeo, Referencia = p_ref
    WHERE RUC_Proveedor = p_ruc;
END$$

CREATE PROCEDURE sp_proveedor_eliminar(IN p_ruc VARCHAR(50))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE RUC_Proveedor = p_ruc AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe o ya está dado de baja.';
    END IF;
    UPDATE Proveedor SET Activo = 0 WHERE RUC_Proveedor = p_ruc;
END$$

CREATE PROCEDURE sp_proveedor_reactivar(IN p_ruc VARCHAR(50))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE RUC_Proveedor = p_ruc AND Activo = 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe o ya está activo.';
    END IF;
    UPDATE Proveedor SET Activo = 1 WHERE RUC_Proveedor = p_ruc;
END$$

-- ---------- ITEM ----------

CREATE PROCEDURE sp_item_listar(IN p_buscar VARCHAR(100), IN p_inactivos TINYINT)
BEGIN
    SELECT ID_Item, Descripcion_Item, Unidad_Medida, Marca_Referencial, Activo
    FROM Item
    WHERE (p_inactivos = 1 OR Activo = 1)
      AND (p_buscar IS NULL OR p_buscar = ''
           OR Descripcion_Item LIKE CONCAT('%', p_buscar, '%')
           OR Marca_Referencial LIKE CONCAT('%', p_buscar, '%'))
    ORDER BY Descripcion_Item;
END$$

CREATE PROCEDURE sp_item_insertar(IN p_desc VARCHAR(255), IN p_unidad VARCHAR(50), IN p_marca VARCHAR(150))
BEGIN
    SET p_desc = TRIM(p_desc), p_unidad = UPPER(TRIM(p_unidad)), p_marca = TRIM(p_marca);
    IF p_desc IS NULL OR p_desc = '' OR p_unidad IS NULL OR p_unidad = '' OR p_marca IS NULL OR p_marca = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Descripción, unidad de medida y marca son obligatorias.';
    END IF;
    IF CHAR_LENGTH(p_unidad) > 20 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La unidad de medida admite máximo 20 caracteres.';
    END IF;
    IF CHAR_LENGTH(p_marca) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La marca admite máximo 100 caracteres.';
    END IF;
    IF EXISTS (SELECT 1 FROM Item WHERE Descripcion_Item = p_desc AND Marca_Referencial = p_marca AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un ítem con la misma descripción y marca.';
    END IF;
    INSERT INTO Item (Descripcion_Item, Unidad_Medida, Marca_Referencial) VALUES (p_desc, p_unidad, p_marca);
END$$

CREATE PROCEDURE sp_item_modificar(IN p_id INT, IN p_desc VARCHAR(255), IN p_unidad VARCHAR(50), IN p_marca VARCHAR(150))
BEGIN
    SET p_desc = TRIM(p_desc), p_unidad = UPPER(TRIM(p_unidad)), p_marca = TRIM(p_marca);
    IF NOT EXISTS (SELECT 1 FROM Item WHERE ID_Item = p_id AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ítem no existe o está dado de baja.';
    END IF;
    IF p_desc IS NULL OR p_desc = '' OR p_unidad IS NULL OR p_unidad = '' OR p_marca IS NULL OR p_marca = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Descripción, unidad de medida y marca son obligatorias.';
    END IF;
    IF CHAR_LENGTH(p_unidad) > 20 OR CHAR_LENGTH(p_marca) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unidad (máx. 20) o marca (máx. 100) demasiado largas.';
    END IF;
    UPDATE Item SET Descripcion_Item = p_desc, Unidad_Medida = p_unidad, Marca_Referencial = p_marca
    WHERE ID_Item = p_id;
END$$

CREATE PROCEDURE sp_item_eliminar(IN p_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Item WHERE ID_Item = p_id AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ítem no existe o ya está dado de baja.';
    END IF;
    UPDATE Item SET Activo = 0 WHERE ID_Item = p_id;
END$$

CREATE PROCEDURE sp_item_reactivar(IN p_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Item WHERE ID_Item = p_id AND Activo = 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ítem no existe o ya está activo.';
    END IF;
    UPDATE Item SET Activo = 1 WHERE ID_Item = p_id;
END$$

-- ---------- ESPECIFICACIÓN TÉCNICA ----------

CREATE PROCEDURE sp_especificacion_listar(IN p_buscar VARCHAR(100), IN p_inactivos TINYINT)
BEGIN
    SELECT ID_Especificacion_Tecnica, Obra_denominacion, Lugar_entrega, Area_usuario,
           Plazo_entrega, Garantia, Activo
    FROM Especificacion_Tecnica
    WHERE (p_inactivos = 1 OR Activo = 1)
      AND (p_buscar IS NULL OR p_buscar = ''
           OR Obra_denominacion LIKE CONCAT('%', p_buscar, '%')
           OR Area_usuario LIKE CONCAT('%', p_buscar, '%')
           OR Lugar_entrega LIKE CONCAT('%', p_buscar, '%'))
    ORDER BY Obra_denominacion;
END$$

CREATE PROCEDURE sp_especificacion_insertar(IN p_obra VARCHAR(150), IN p_lugar VARCHAR(200),
                                            IN p_area VARCHAR(100), IN p_plazo VARCHAR(50), IN p_garantia VARCHAR(100))
BEGIN
    SET p_obra = TRIM(p_obra), p_lugar = TRIM(p_lugar), p_area = TRIM(p_area),
        p_plazo = TRIM(p_plazo), p_garantia = NULLIF(TRIM(p_garantia), '');
    IF p_obra IS NULL OR p_obra = '' OR p_lugar IS NULL OR p_lugar = ''
       OR p_area IS NULL OR p_area = '' OR p_plazo IS NULL OR p_plazo = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Obra, lugar de entrega, área usuaria y plazo son obligatorios.';
    END IF;
    INSERT INTO Especificacion_Tecnica (Lugar_entrega, Obra_denominacion, Area_usuario, Plazo_entrega, Garantia)
    VALUES (p_lugar, p_obra, p_area, p_plazo, p_garantia);
END$$

CREATE PROCEDURE sp_especificacion_modificar(IN p_id INT, IN p_obra VARCHAR(150), IN p_lugar VARCHAR(200),
                                             IN p_area VARCHAR(100), IN p_plazo VARCHAR(50), IN p_garantia VARCHAR(100))
BEGIN
    SET p_obra = TRIM(p_obra), p_lugar = TRIM(p_lugar), p_area = TRIM(p_area),
        p_plazo = TRIM(p_plazo), p_garantia = NULLIF(TRIM(p_garantia), '');
    IF NOT EXISTS (SELECT 1 FROM Especificacion_Tecnica WHERE ID_Especificacion_Tecnica = p_id AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La especificación no existe o está dada de baja.';
    END IF;
    IF p_obra IS NULL OR p_obra = '' OR p_lugar IS NULL OR p_lugar = ''
       OR p_area IS NULL OR p_area = '' OR p_plazo IS NULL OR p_plazo = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Obra, lugar de entrega, área usuaria y plazo son obligatorios.';
    END IF;
    UPDATE Especificacion_Tecnica
    SET Obra_denominacion = p_obra, Lugar_entrega = p_lugar, Area_usuario = p_area,
        Plazo_entrega = p_plazo, Garantia = p_garantia
    WHERE ID_Especificacion_Tecnica = p_id;
END$$

CREATE PROCEDURE sp_especificacion_eliminar(IN p_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Especificacion_Tecnica WHERE ID_Especificacion_Tecnica = p_id AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La especificación no existe o ya está dada de baja.';
    END IF;
    UPDATE Especificacion_Tecnica SET Activo = 0 WHERE ID_Especificacion_Tecnica = p_id;
END$$

CREATE PROCEDURE sp_especificacion_reactivar(IN p_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Especificacion_Tecnica WHERE ID_Especificacion_Tecnica = p_id AND Activo = 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La especificación no existe o ya está activa.';
    END IF;
    UPDATE Especificacion_Tecnica SET Activo = 1 WHERE ID_Especificacion_Tecnica = p_id;
END$$

-- ---------- COTIZACIÓN ----------

CREATE PROCEDURE sp_cotizacion_listar(IN p_buscar VARCHAR(100), IN p_estado VARCHAR(20), IN p_inactivos TINYINT)
BEGIN
    SELECT c.Num_solicitud, c.Fecha_solicitud, c.Estado, c.Moneda,
           fn_total_cotizacion(c.Num_solicitud) AS Total,
           cl.Razon_social AS Cliente, p.Razon_Social AS Proveedor, c.Concepto,
           c.ID_Cliente, c.ID_Proveedor, c.ID_Especificacion_Tecnica,
           c.Validez_cotizacion, c.Plazo_entrega, c.`Garantía` AS Garantia_cot,
           c.Unidad_ejecutora, c.Activo
    FROM Cotizacion c
    JOIN Cliente cl ON cl.DNI_RUC = c.ID_Cliente
    JOIN Proveedor p ON p.RUC_Proveedor = c.ID_Proveedor
    WHERE (p_inactivos = 1 OR c.Activo = 1)
      AND (p_estado IS NULL OR p_estado = '' OR c.Estado = p_estado)
      AND (p_buscar IS NULL OR p_buscar = ''
           OR c.Num_solicitud LIKE CONCAT('%', p_buscar, '%')
           OR cl.Razon_social LIKE CONCAT('%', p_buscar, '%')
           OR p.Razon_Social LIKE CONCAT('%', p_buscar, '%')
           OR c.Concepto LIKE CONCAT('%', p_buscar, '%'))
    ORDER BY c.Fecha_solicitud DESC, c.Num_solicitud DESC;
END$$

CREATE PROCEDURE sp_cotizacion_insertar(IN p_num VARCHAR(20), IN p_esp INT, IN p_cliente VARCHAR(50),
                                        IN p_prov VARCHAR(50), IN p_validez VARCHAR(50), IN p_plazo VARCHAR(50),
                                        IN p_garantia VARCHAR(100), IN p_moneda VARCHAR(10),
                                        IN p_unidad VARCHAR(100), IN p_fecha DATE, IN p_concepto VARCHAR(255))
BEGIN
    SET p_num = NULLIF(TRIM(p_num), ''), p_validez = TRIM(p_validez), p_plazo = TRIM(p_plazo),
        p_garantia = TRIM(p_garantia), p_unidad = TRIM(p_unidad), p_concepto = TRIM(p_concepto);
    IF p_num IS NULL THEN
        SET p_num = fn_siguiente_num_solicitud();
    END IF;
    IF p_num NOT REGEXP '^[A-Za-z0-9]{1,6}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El número de solicitud admite 1 a 6 letras o dígitos.';
    END IF;
    IF EXISTS (SELECT 1 FROM Cotizacion WHERE Num_solicitud = p_num) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe una cotización con ese número de solicitud.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE DNI_RUC = p_cliente AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o está dado de baja.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE RUC_Proveedor = p_prov AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe o está dado de baja.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Especificacion_Tecnica WHERE ID_Especificacion_Tecnica = p_esp AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La especificación técnica no existe o está dada de baja.';
    END IF;
    IF p_moneda NOT IN ('S/.', 'USD') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La moneda debe ser S/. o USD.';
    END IF;
    IF p_fecha IS NULL OR p_validez = '' OR p_plazo = '' OR p_garantia = '' OR p_unidad = '' OR p_concepto = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Complete todos los campos obligatorios de la cotización.';
    END IF;
    INSERT INTO Cotizacion (Num_solicitud, ID_Especificacion_Tecnica, ID_Cliente, ID_Proveedor,
                            Validez_cotizacion, Plazo_entrega, `Garantía`, Estado, Moneda,
                            Unidad_ejecutora, Fecha_solicitud, Concepto)
    VALUES (p_num, p_esp, p_cliente, p_prov, p_validez, p_plazo, p_garantia, 'Pendiente', p_moneda,
            p_unidad, p_fecha, p_concepto);
    SELECT p_num AS Num_solicitud;
END$$

CREATE PROCEDURE sp_cotizacion_modificar(IN p_num VARCHAR(20), IN p_esp INT, IN p_cliente VARCHAR(50),
                                         IN p_prov VARCHAR(50), IN p_validez VARCHAR(50), IN p_plazo VARCHAR(50),
                                         IN p_garantia VARCHAR(100), IN p_moneda VARCHAR(10),
                                         IN p_unidad VARCHAR(100), IN p_fecha DATE, IN p_concepto VARCHAR(255))
BEGIN
    DECLARE v_estado VARCHAR(20);
    SET p_validez = TRIM(p_validez), p_plazo = TRIM(p_plazo), p_garantia = TRIM(p_garantia),
        p_unidad = TRIM(p_unidad), p_concepto = TRIM(p_concepto);
    SET v_estado = (SELECT Estado FROM Cotizacion WHERE Num_solicitud = p_num AND Activo = 1);
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cotización no existe o está dada de baja.';
    END IF;
    IF v_estado <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden modificar cotizaciones en estado Pendiente.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE DNI_RUC = p_cliente AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o está dado de baja.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE RUC_Proveedor = p_prov AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe o está dado de baja.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Especificacion_Tecnica WHERE ID_Especificacion_Tecnica = p_esp AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La especificación técnica no existe o está dada de baja.';
    END IF;
    IF p_moneda NOT IN ('S/.', 'USD') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La moneda debe ser S/. o USD.';
    END IF;
    IF p_fecha IS NULL OR p_validez = '' OR p_plazo = '' OR p_garantia = '' OR p_unidad = '' OR p_concepto = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Complete todos los campos obligatorios de la cotización.';
    END IF;
    UPDATE Cotizacion
    SET ID_Especificacion_Tecnica = p_esp, ID_Cliente = p_cliente, ID_Proveedor = p_prov,
        Validez_cotizacion = p_validez, Plazo_entrega = p_plazo, `Garantía` = p_garantia,
        Moneda = p_moneda, Unidad_ejecutora = p_unidad, Fecha_solicitud = p_fecha, Concepto = p_concepto
    WHERE Num_solicitud = p_num;
END$$

CREATE PROCEDURE sp_cotizacion_cambiar_estado(IN p_num VARCHAR(20), IN p_estado VARCHAR(20))
BEGIN
    DECLARE v_estado VARCHAR(20);
    IF p_estado NOT IN ('Aprobado', 'Rechazado') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nuevo estado debe ser Aprobado o Rechazado.';
    END IF;
    SET v_estado = (SELECT Estado FROM Cotizacion WHERE Num_solicitud = p_num AND Activo = 1);
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cotización no existe o está dada de baja.';
    END IF;
    IF v_estado <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo una cotización Pendiente puede ser aprobada o rechazada.';
    END IF;
    IF p_estado = 'Aprobado'
       AND NOT EXISTS (SELECT 1 FROM Detalle_Cotizacion WHERE Num_solicitud = p_num AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede aprobar una cotización sin ítems.';
    END IF;
    UPDATE Cotizacion SET Estado = p_estado WHERE Num_solicitud = p_num;
END$$

CREATE PROCEDURE sp_cotizacion_eliminar(IN p_num VARCHAR(20))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Cotizacion WHERE Num_solicitud = p_num AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cotización no existe o ya está dada de baja.';
    END IF;
    UPDATE Cotizacion SET Activo = 0 WHERE Num_solicitud = p_num;   -- baja lógica
END$$

CREATE PROCEDURE sp_cotizacion_reactivar(IN p_num VARCHAR(20))
BEGIN
    DECLARE v_cli VARCHAR(11);
    DECLARE v_prov CHAR(11);
    DECLARE v_esp INT;
    IF NOT EXISTS (SELECT 1 FROM Cotizacion WHERE Num_solicitud = p_num AND Activo = 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cotización no existe o ya está activa.';
    END IF;
    SET v_cli = (SELECT ID_Cliente FROM Cotizacion WHERE Num_solicitud = p_num);
    SET v_prov = (SELECT ID_Proveedor FROM Cotizacion WHERE Num_solicitud = p_num);
    SET v_esp = (SELECT ID_Especificacion_Tecnica FROM Cotizacion WHERE Num_solicitud = p_num);
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE DNI_RUC = v_cli AND Activo = 1)
       OR NOT EXISTS (SELECT 1 FROM Proveedor WHERE RUC_Proveedor = v_prov AND Activo = 1)
       OR NOT EXISTS (SELECT 1 FROM Especificacion_Tecnica WHERE ID_Especificacion_Tecnica = v_esp AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reactive primero el cliente, proveedor o especificación asociados.';
    END IF;
    UPDATE Cotizacion SET Activo = 1 WHERE Num_solicitud = p_num;
END$$

-- ---------- DETALLE DE COTIZACIÓN ----------

CREATE PROCEDURE sp_detalle_listar(IN p_num VARCHAR(20))
BEGIN
    SELECT d.ID_Item, i.Descripcion_Item, i.Unidad_Medida, i.Marca_Referencial,
           d.Cantidad_Requerida, d.Precio_Unitario,
           ROUND(d.Cantidad_Requerida * d.Precio_Unitario, 2) AS Subtotal
    FROM Detalle_Cotizacion d
    JOIN Item i ON i.ID_Item = d.ID_Item
    WHERE d.Num_solicitud = p_num AND d.Activo = 1
    ORDER BY i.Descripcion_Item;
END$$

CREATE PROCEDURE sp_detalle_agregar(IN p_num VARCHAR(20), IN p_item INT,
                                    IN p_cant DECIMAL(12,2), IN p_precio DECIMAL(14,2))
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_activo TINYINT;
    SET v_estado = (SELECT Estado FROM Cotizacion WHERE Num_solicitud = p_num AND Activo = 1);
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cotización no existe o está dada de baja.';
    END IF;
    IF v_estado <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar el detalle de cotizaciones Pendientes.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Item WHERE ID_Item = p_item AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ítem no existe o está dado de baja.';
    END IF;
    IF p_cant IS NULL OR p_cant <= 0 OR p_cant > 99999999.99 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor que 0 y menor que 100 000 000.';
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 OR p_precio > 9999999999.99 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio unitario debe ser mayor que 0 y menor que 10 000 000 000.';
    END IF;
    SET v_activo = (SELECT Activo FROM Detalle_Cotizacion WHERE Num_solicitud = p_num AND ID_Item = p_item);
    IF v_activo = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese ítem ya está en la cotización; use Modificar.';
    ELSEIF v_activo = 0 THEN
        UPDATE Detalle_Cotizacion
        SET Cantidad_Requerida = p_cant, Precio_Unitario = p_precio, Activo = 1
        WHERE Num_solicitud = p_num AND ID_Item = p_item;
    ELSE
        INSERT INTO Detalle_Cotizacion (Num_solicitud, ID_Item, Cantidad_Requerida, Precio_Unitario)
        VALUES (p_num, p_item, p_cant, p_precio);
    END IF;
END$$

CREATE PROCEDURE sp_detalle_modificar(IN p_num VARCHAR(20), IN p_item INT,
                                      IN p_cant DECIMAL(12,2), IN p_precio DECIMAL(14,2))
BEGIN
    DECLARE v_estado VARCHAR(20);
    SET v_estado = (SELECT Estado FROM Cotizacion WHERE Num_solicitud = p_num AND Activo = 1);
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cotización no existe o está dada de baja.';
    END IF;
    IF v_estado <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar el detalle de cotizaciones Pendientes.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Detalle_Cotizacion WHERE Num_solicitud = p_num AND ID_Item = p_item AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese ítem no está en la cotización.';
    END IF;
    IF p_cant IS NULL OR p_cant <= 0 OR p_cant > 99999999.99 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor que 0 y menor que 100 000 000.';
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 OR p_precio > 9999999999.99 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio unitario debe ser mayor que 0 y menor que 10 000 000 000.';
    END IF;
    UPDATE Detalle_Cotizacion SET Cantidad_Requerida = p_cant, Precio_Unitario = p_precio
    WHERE Num_solicitud = p_num AND ID_Item = p_item;
END$$

CREATE PROCEDURE sp_detalle_quitar(IN p_num VARCHAR(20), IN p_item INT)
BEGIN
    DECLARE v_estado VARCHAR(20);
    SET v_estado = (SELECT Estado FROM Cotizacion WHERE Num_solicitud = p_num AND Activo = 1);
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cotización no existe o está dada de baja.';
    END IF;
    IF v_estado <> 'Pendiente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar el detalle de cotizaciones Pendientes.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Detalle_Cotizacion WHERE Num_solicitud = p_num AND ID_Item = p_item AND Activo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese ítem no está en la cotización.';
    END IF;
    UPDATE Detalle_Cotizacion SET Activo = 0 WHERE Num_solicitud = p_num AND ID_Item = p_item;
END$$

-- ---------- REPORTES (12) ----------
-- R1-R9 usan JOIN (se requieren al menos 6). R10-R12 son consultas simples.

-- R1: Cotizaciones con cliente, proveedor, obra y total (JOIN x4)
CREATE PROCEDURE sp_rep_cotizaciones_completas(IN p_estado VARCHAR(20), IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT c.Num_solicitud, c.Fecha_solicitud, c.Estado, cl.Razon_social AS Cliente,
           p.Razon_Social AS Proveedor, e.Obra_denominacion AS Obra, c.Moneda,
           fn_total_cotizacion(c.Num_solicitud) AS Total
    FROM Cotizacion c
    JOIN Cliente cl ON cl.DNI_RUC = c.ID_Cliente
    JOIN Proveedor p ON p.RUC_Proveedor = c.ID_Proveedor
    JOIN Especificacion_Tecnica e ON e.ID_Especificacion_Tecnica = c.ID_Especificacion_Tecnica
    WHERE c.Activo = 1
      AND (p_estado IS NULL OR p_estado = '' OR c.Estado = p_estado)
      AND (p_desde IS NULL OR c.Fecha_solicitud >= p_desde)
      AND (p_hasta IS NULL OR c.Fecha_solicitud <= p_hasta)
    ORDER BY c.Fecha_solicitud DESC, c.Num_solicitud DESC;
END$$

-- R2: Detalle de una cotización (JOIN x5)
CREATE PROCEDURE sp_rep_detalle_cotizacion(IN p_num VARCHAR(20))
BEGIN
    SELECT c.Num_solicitud, cl.Razon_social AS Cliente, p.Razon_Social AS Proveedor,
           i.Descripcion_Item AS Item, i.Unidad_Medida AS Unidad, d.Cantidad_Requerida AS Cantidad,
           d.Precio_Unitario AS Precio_unitario,
           ROUND(d.Cantidad_Requerida * d.Precio_Unitario, 2) AS Subtotal, c.Moneda
    FROM Detalle_Cotizacion d
    JOIN Item i ON i.ID_Item = d.ID_Item
    JOIN Cotizacion c ON c.Num_solicitud = d.Num_solicitud
    JOIN Cliente cl ON cl.DNI_RUC = c.ID_Cliente
    JOIN Proveedor p ON p.RUC_Proveedor = c.ID_Proveedor
    WHERE d.Num_solicitud = p_num AND d.Activo = 1
    ORDER BY i.Descripcion_Item;
END$$

-- R3: Monto cotizado por cliente (JOIN x3 + GROUP BY)
CREATE PROCEDURE sp_rep_total_por_cliente()
BEGIN
    SELECT cl.DNI_RUC, cl.Razon_social AS Cliente, c.Moneda,
           COUNT(DISTINCT c.Num_solicitud) AS Cotizaciones,
           SUM(d.Cantidad_Requerida * d.Precio_Unitario) AS Monto_total
    FROM Cliente cl
    JOIN Cotizacion c ON c.ID_Cliente = cl.DNI_RUC
    JOIN Detalle_Cotizacion d ON d.Num_solicitud = c.Num_solicitud
    WHERE c.Activo = 1 AND d.Activo = 1
    GROUP BY cl.DNI_RUC, cl.Razon_social, c.Moneda
    ORDER BY Monto_total DESC;
END$$

-- R4: Monto cotizado por proveedor y departamento (JOIN x4 + GROUP BY)
CREATE PROCEDURE sp_rep_total_por_proveedor()
BEGIN
    SELECT p.RUC_Proveedor, p.Razon_Social AS Proveedor, u.Departamento, c.Moneda,
           COUNT(DISTINCT c.Num_solicitud) AS Cotizaciones,
           SUM(d.Cantidad_Requerida * d.Precio_Unitario) AS Monto_total
    FROM Proveedor p
    JOIN Ubigeo u ON u.Ubigeo = p.Ubigeo
    JOIN Cotizacion c ON c.ID_Proveedor = p.RUC_Proveedor
    JOIN Detalle_Cotizacion d ON d.Num_solicitud = c.Num_solicitud
    WHERE c.Activo = 1 AND d.Activo = 1
    GROUP BY p.RUC_Proveedor, p.Razon_Social, u.Departamento, c.Moneda
    ORDER BY Monto_total DESC;
END$$

-- R5: Ítems más cotizados (JOIN x3 + GROUP BY)
CREATE PROCEDURE sp_rep_items_mas_cotizados()
BEGIN
    SELECT i.ID_Item, i.Descripcion_Item AS Item, i.Unidad_Medida AS Unidad,
           COUNT(DISTINCT c.Num_solicitud) AS Veces_cotizado,
           SUM(d.Cantidad_Requerida) AS Cantidad_total,
           ROUND(AVG(d.Precio_Unitario), 2) AS Precio_promedio
    FROM Item i
    JOIN Detalle_Cotizacion d ON d.ID_Item = i.ID_Item
    JOIN Cotizacion c ON c.Num_solicitud = d.Num_solicitud
    WHERE c.Activo = 1 AND d.Activo = 1
    GROUP BY i.ID_Item, i.Descripcion_Item, i.Unidad_Medida
    ORDER BY Veces_cotizado DESC, Cantidad_total DESC;
END$$

-- R6: Comparativo de precios por ítem y proveedor (JOIN x4 + GROUP BY); p_item NULL = todos
CREATE PROCEDURE sp_rep_comparativo_precios(IN p_item INT)
BEGIN
    SELECT i.Descripcion_Item AS Item, p.Razon_Social AS Proveedor, c.Moneda,
           COUNT(*) AS Cotizaciones,
           MIN(d.Precio_Unitario) AS Precio_minimo,
           ROUND(AVG(d.Precio_Unitario), 2) AS Precio_promedio,
           MAX(d.Precio_Unitario) AS Precio_maximo
    FROM Detalle_Cotizacion d
    JOIN Item i ON i.ID_Item = d.ID_Item
    JOIN Cotizacion c ON c.Num_solicitud = d.Num_solicitud
    JOIN Proveedor p ON p.RUC_Proveedor = c.ID_Proveedor
    WHERE c.Activo = 1 AND d.Activo = 1
      AND (p_item IS NULL OR d.ID_Item = p_item)
    GROUP BY i.ID_Item, i.Descripcion_Item, p.RUC_Proveedor, p.Razon_Social, c.Moneda
    ORDER BY i.Descripcion_Item, Precio_promedio;
END$$

-- R7: Proveedores por departamento y provincia (JOIN + GROUP BY)
CREATE PROCEDURE sp_rep_proveedores_por_departamento()
BEGIN
    SELECT u.Departamento, u.Provincia, COUNT(p.RUC_Proveedor) AS Proveedores
    FROM Ubigeo u
    JOIN Proveedor p ON p.Ubigeo = u.Ubigeo
    WHERE p.Activo = 1
    GROUP BY u.Departamento, u.Provincia
    ORDER BY Proveedores DESC, u.Departamento;
END$$

-- R8: Clientes activos sin cotizaciones (LEFT JOIN)
CREATE PROCEDURE sp_rep_clientes_sin_cotizaciones()
BEGIN
    SELECT cl.DNI_RUC, cl.Razon_social AS Cliente, cl.Direccion
    FROM Cliente cl
    LEFT JOIN Cotizacion c ON c.ID_Cliente = cl.DNI_RUC AND c.Activo = 1
    WHERE cl.Activo = 1 AND c.Num_solicitud IS NULL
    ORDER BY cl.Razon_social;
END$$

-- R9: Uso de especificaciones técnicas por área (JOIN + GROUP BY)
CREATE PROCEDURE sp_rep_especificaciones_uso()
BEGIN
    SELECT e.Area_usuario AS Area, e.Obra_denominacion AS Obra, e.Lugar_entrega AS Lugar,
           COUNT(c.Num_solicitud) AS Cotizaciones,
           SUM(c.Estado = 'Aprobado') AS Aprobadas
    FROM Especificacion_Tecnica e
    JOIN Cotizacion c ON c.ID_Especificacion_Tecnica = e.ID_Especificacion_Tecnica
    WHERE e.Activo = 1 AND c.Activo = 1
    GROUP BY e.ID_Especificacion_Tecnica, e.Area_usuario, e.Obra_denominacion, e.Lugar_entrega
    ORDER BY Cotizaciones DESC, e.Obra_denominacion;
END$$

-- R10: Cotizaciones por estado y moneda (sin JOIN)
CREATE PROCEDURE sp_rep_resumen_por_estado()
BEGIN
    SELECT Estado, Moneda, COUNT(*) AS Cantidad
    FROM Cotizacion
    WHERE Activo = 1
    GROUP BY Estado, Moneda
    ORDER BY Estado, Moneda;
END$$

-- R11: Cotizaciones por mes (sin JOIN)
CREATE PROCEDURE sp_rep_cotizaciones_por_mes()
BEGIN
    SELECT DATE_FORMAT(Fecha_solicitud, '%Y-%m') AS Mes,
           COUNT(*) AS Cotizaciones,
           SUM(Estado = 'Aprobado') AS Aprobadas,
           SUM(Estado = 'Rechazado') AS Rechazadas,
           SUM(Estado = 'Pendiente') AS Pendientes
    FROM Cotizacion
    WHERE Activo = 1
    GROUP BY DATE_FORMAT(Fecha_solicitud, '%Y-%m')
    ORDER BY Mes;
END$$

-- R12: Bitácora de auditoría generada por triggers (sin JOIN)
CREATE PROCEDURE sp_rep_auditoria()
BEGIN
    SELECT ID_Auditoria, Fecha_hora, Tabla, Operacion, Llave, Detalle, Usuario
    FROM Auditoria
    ORDER BY ID_Auditoria DESC
    LIMIT 300;
END$$

DELIMITER ;
