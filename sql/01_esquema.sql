-- =====================================================
-- ENTREGA 5: SISTEMA DE COTIZACIONES  (MySQL 8.0+)
-- Script completo: esquema + datos + procedimientos + triggers
--
-- Cambios respecto a la Entrega 4:
--   * Columna Activo (1 = vigente, 0 = baja lógica) en las tablas de negocio.
--   * Tabla Auditoria (bitácora alimentada por triggers).
--   * Más datos de prueba.
-- ATENCIÓN: este script elimina y vuelve a crear la base de datos.
-- =====================================================
DROP DATABASE IF EXISTS sistema_cotizaciones;

CREATE DATABASE IF NOT EXISTS sistema_cotizaciones
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sistema_cotizaciones;

-- 1. TABLAS ------------------------------------------------

CREATE TABLE IF NOT EXISTS Cliente (
    DNI_RUC VARCHAR(11) NOT NULL PRIMARY KEY,
    Razon_social VARCHAR(150) NOT NULL,
    Direccion VARCHAR(200) NOT NULL,
    Activo TINYINT(1) NOT NULL DEFAULT 1,
    INDEX idx_cliente_razon_social (Razon_social)
) ENGINE=InnoDB;

-- 3FN: Departamento, Provincia y Distrito dependen de Ubigeo
CREATE TABLE IF NOT EXISTS Ubigeo (
    Ubigeo CHAR(6) NOT NULL PRIMARY KEY,
    Departamento VARCHAR(50) NOT NULL,
    Provincia VARCHAR(50) NOT NULL,
    Distrito VARCHAR(50) NOT NULL,
    INDEX idx_ubigeo_depto_prov_dist (Departamento, Provincia, Distrito)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Proveedor (
    RUC_Proveedor CHAR(11) NOT NULL PRIMARY KEY,
    Razon_Social VARCHAR(150) NOT NULL,
    Ubigeo CHAR(6) NOT NULL,
    Referencia VARCHAR(150) NULL,
    Activo TINYINT(1) NOT NULL DEFAULT 1,
    INDEX idx_proveedor_razon_social (Razon_Social),
    CONSTRAINT fk_prov_ubigeo FOREIGN KEY (Ubigeo)
        REFERENCES Ubigeo(Ubigeo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Especificacion_Tecnica (
    ID_Especificacion_Tecnica INT AUTO_INCREMENT PRIMARY KEY,
    Lugar_entrega VARCHAR(200) NOT NULL,
    Obra_denominacion VARCHAR(150) NOT NULL,
    Area_usuario VARCHAR(100) NOT NULL,
    Plazo_entrega VARCHAR(50) NOT NULL,
    Garantia VARCHAR(100) NULL,
    Activo TINYINT(1) NOT NULL DEFAULT 1,
    INDEX idx_et_area_usuario (Area_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Item (
    ID_Item INT AUTO_INCREMENT PRIMARY KEY,
    Descripcion_Item VARCHAR(255) NOT NULL,
    Unidad_Medida VARCHAR(20) NOT NULL,
    Marca_Referencial VARCHAR(100) NOT NULL,
    Activo TINYINT(1) NOT NULL DEFAULT 1,
    INDEX idx_item_descripcion (Descripcion_Item)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Cotizacion (
    Num_solicitud VARCHAR(6) NOT NULL PRIMARY KEY,
    ID_Especificacion_Tecnica INT NOT NULL,
    ID_Cliente VARCHAR(11) NOT NULL,
    ID_Proveedor CHAR(11) NOT NULL,
    Validez_cotizacion VARCHAR(50) NOT NULL,
    Plazo_entrega VARCHAR(50) NOT NULL,
    `Garantía` VARCHAR(100) NOT NULL,
    Estado VARCHAR(20) NOT NULL
        CHECK (Estado IN ('Pendiente','Aprobado','Rechazado')),
    Moneda VARCHAR(10) NOT NULL
        CHECK (Moneda IN ('S/.','USD')),
    Unidad_ejecutora VARCHAR(100) NOT NULL,
    Fecha_solicitud DATE NOT NULL,
    Concepto VARCHAR(255) NOT NULL,
    Activo TINYINT(1) NOT NULL DEFAULT 1,
    INDEX idx_cotizacion_estado (Estado),
    INDEX idx_cotizacion_fecha (Fecha_solicitud),
    INDEX idx_cotizacion_estado_fecha (Estado, Fecha_solicitud),
    CONSTRAINT fk_cot_est FOREIGN KEY (ID_Especificacion_Tecnica)
        REFERENCES Especificacion_Tecnica(ID_Especificacion_Tecnica),
    CONSTRAINT fk_cot_cliente FOREIGN KEY (ID_Cliente)
        REFERENCES Cliente(DNI_RUC),
    CONSTRAINT fk_cot_proveedor FOREIGN KEY (ID_Proveedor)
        REFERENCES Proveedor(RUC_Proveedor)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Detalle_Cotizacion (
    Num_solicitud VARCHAR(6) NOT NULL,
    ID_Item INT NOT NULL,
    Cantidad_Requerida DECIMAL(10,2) NOT NULL
        CHECK (Cantidad_Requerida > 0),
    Precio_Unitario DECIMAL(12,2) NOT NULL
        CHECK (Precio_Unitario > 0),
    Activo TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (Num_solicitud, ID_Item),
    FOREIGN KEY (Num_solicitud)
        REFERENCES Cotizacion(Num_solicitud)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (ID_Item)
        REFERENCES Item(ID_Item)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Bitácora llenada automáticamente por los triggers
CREATE TABLE IF NOT EXISTS Auditoria (
    ID_Auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    Fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Tabla VARCHAR(30) NOT NULL,
    Operacion VARCHAR(20) NOT NULL,
    Llave VARCHAR(60) NOT NULL,
    Detalle VARCHAR(400) NULL,
    Usuario VARCHAR(255) NOT NULL,
    INDEX idx_auditoria_fecha (Fecha_hora)
) ENGINE=InnoDB;
