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

-- 2. DATOS DE PRUEBA (ficticios) - enfoque EPP (equipos de protección personal) ----
INSERT INTO Ubigeo (Ubigeo, Departamento, Provincia, Distrito) VALUES
('150101','Lima','Lima','Lima'),
('150103','Lima','Lima','Ate'),
('150104','Lima','Lima','Barranco'),
('150115','Lima','Lima','La Victoria'),
('150122','Lima','Lima','Miraflores'),
('150130','Lima','Lima','San Borja'),
('150131','Lima','Lima','San Isidro'),
('150140','Lima','Lima','Santiago de Surco'),
('080101','Cusco','Cusco','Cusco'),
('080104','Cusco','Cusco','San Jerónimo'),
('080105','Cusco','Cusco','San Sebastián'),
('080106','Cusco','Cusco','Santiago'),
('080108','Cusco','Cusco','Wanchaq'),
('040101','Arequipa','Arequipa','Arequipa'),
('040103','Arequipa','Arequipa','Cayma'),
('040129','Arequipa','Arequipa','Yanahuara'),
('210101','Puno','Puno','Puno'),
('211101','Puno','San Román','Juliaca'),
('130101','La Libertad','Trujillo','Trujillo'),
('200101','Piura','Piura','Piura'),
('230101','Tacna','Tacna','Tacna'),
('110101','Ica','Ica','Ica');

INSERT INTO Cliente (DNI_RUC, Razon_social, Direccion) VALUES
('20450123456','Minera Cerro Alto SAC','Km 38 Carretera Yura, Cerro Colorado, Arequipa'),
('20450234567','Gobierno Regional del Cusco','Av. Tomasa Tito Condemayta s/n, Wanchaq, Cusco'),
('20450345678','Municipalidad Provincial de Puno','Jr. Deustua 458, Puno'),
('20450456789','Hospital Regional de Arequipa','Av. Daniel Alcides Carrión 505, Arequipa'),
('20450567890','Universidad Nacional de San Antonio Abad','Av. de la Cultura 733, Cusco'),
('20450678901','Constructora Andina SAC','Calle Los Pinos 210, San Borja, Lima'),
('20450789012','Industrias Metálicas del Sur SA','Parque Industrial Río Seco Mz. C Lt. 5, Cerro Colorado, Arequipa'),
('20450890123','Transportes y Logística Cusco SRL','Av. Collasuyo 1450, Wanchaq, Cusco'),
('45871236','Carlos Mendoza Quispe','Urb. Los Incas B-12, San Sebastián, Cusco'),
('71203648','Lucía Fernández Huamán','Calle Pumacahua 245, Santiago, Cusco'),
('20450901234','Consorcio Vial del Sur','Av. Ejército 912, Yanahuara, Arequipa'),
('20451012345','Agroindustrial Majes del Sur SAC','Av. Kennedy 310, Cayma, Arequipa');

INSERT INTO Proveedor (RUC_Proveedor, Razon_Social, Ubigeo, Referencia) VALUES
('20601111111','Seguridad Industrial Cusco EIRL','080101','Frente al Mercado de Wanchaq'),
('20601222222','EPP Andes Perú SAC','080105','Cerca al Óvalo San Sebastián'),
('20601333333','Distribuidora de Seguridad del Sur SRL','040101','Parque Industrial Río Seco'),
('20601444444','Protección Total Arequipa SA','040103','Av. Ramón Castilla 800'),
('20601555555','Safety Lima Import SAC','150103','Carretera Central km 7.5'),
('20601666666','Importadora 3S Seguridad SAC','150115','Jr. Parinacochas 1120'),
('20601777777','Altiplano Safety EIRL','210101','Av. El Sol 365'),
('20601888888','Calzado de Seguridad Perú SA','150131',NULL),
('20601999999','Respiratorios y Filtros Norte SRL','130101','Av. España 1540'),
('20602000001','Uniformes Industriales Los Andes SAC','211101','Salida a Cusco km 2'),
('20602000002','Alturas y Rescate Tacna SAC','230101','Av. Bolognesi 1200'),
('20602000003','Óptica Industrial Piura EIRL','200101',NULL);

INSERT INTO Especificacion_Tecnica (Lugar_entrega, Obra_denominacion, Area_usuario, Plazo_entrega, Garantia) VALUES
('Campamento Cerro Alto, Cerro Colorado, Arequipa','Dotación anual de EPP para operaciones de mina superficial','Superintendencia de Seguridad y Salud','30 días calendario','12 meses'),
('Calle Los Pinos 210, San Borja, Lima','Dotación de EPP para obra edificio multifamiliar Los Pinos','Residencia de Obra','15 días calendario','6 meses'),
('Av. Ejército 912, Yanahuara, Arequipa','EPP para cuadrilla de mejoramiento de carretera Arequipa–Yura','Almacén de Obra','20 días calendario','6 meses'),
('Av. Daniel Alcides Carrión 505, Arequipa','Equipos de bioseguridad para personal de salud','Oficina de Logística','10 días calendario','12 meses'),
('Parque Industrial Río Seco Mz. C Lt. 5, Arequipa','Reposición de EPP para planta metalmecánica','Jefatura de Seguridad Industrial','15 días calendario','12 meses'),
('Av. Tomasa Tito Condemayta s/n, Wanchaq, Cusco','EPP para cuadrillas de mantenimiento vial regional','Gerencia de Infraestructura','30 días calendario','6 meses'),
('Av. de la Cultura 733, Cusco','EPP para laboratorios y talleres de ingeniería','Oficina de Servicios Generales','20 días calendario','12 meses'),
('Jr. Deustua 458, Puno','EPP para personal de limpieza pública y obras menores','Subgerencia de Servicios Públicos','15 días calendario','6 meses'),
('Av. Collasuyo 1450, Wanchaq, Cusco','EPP para operarios de almacén y carga','Jefatura de Almacén','10 días calendario',NULL);

INSERT INTO Item (Descripcion_Item, Unidad_Medida, Marca_Referencial) VALUES
('Casco de seguridad dieléctrico tipo I clase E','UND','3M'),
('Casco minero con portalámpara','UND','MSA'),
('Lentes de seguridad claros antiempañantes','UND','3M'),
('Lentes de seguridad oscuros protección UV','UND','Steelpro'),
('Careta facial de policarbonato','UND','Honeywell'),
('Tapones auditivos reutilizables','PAR','3M'),
('Orejeras tipo copa NRR 25 dB','UND','3M Peltor'),
('Respirador media cara serie 6200','UND','3M'),
('Filtro para vapores orgánicos 6001','PAR','3M'),
('Mascarilla descartable N95','UND','3M'),
('Guantes de cuero para soldador','PAR','Steelpro'),
('Guantes de nitrilo recubiertos','PAR','Ansell'),
('Guantes anticorte nivel 5','PAR','Ansell'),
('Guantes dieléctricos clase 0','PAR','Steelpro'),
('Botas de seguridad punta de acero','PAR','Bata'),
('Botas de jebe punta de acero','PAR','Steelpro'),
('Chaleco de seguridad con cinta reflectiva','UND','Steelpro'),
('Overol de algodón con cinta reflectiva','UND','Libus'),
('Mameluco desechable Tyvek','UND','DuPont'),
('Arnés de seguridad cuerpo entero','UND','3M DBI-SALA'),
('Línea de vida con absorbedor de impacto','UND','3M DBI-SALA'),
('Barbiquejo de 3 puntos','UND','Steelpro'),
('Legionario protector solar para casco','UND','Steelpro'),
('Faja lumbar de soporte','UND','Steelpro'),
('Traje impermeable (saco y pantalón)','JUEGO','Steelpro'),
('Botiquín de primeros auxilios tipo A','UND','Safetyline');

INSERT INTO Cotizacion (Num_solicitud, ID_Especificacion_Tecnica, ID_Cliente, ID_Proveedor, Validez_cotizacion, Plazo_entrega, `Garantía`, Estado, Moneda, Unidad_ejecutora, Fecha_solicitud, Concepto) VALUES
('C00001',1,'20450123456','20601999999','45 días calendario','30 días calendario','12 meses','Aprobado','USD','Superintendencia de Seguridad y Salud','2026-01-16','Adquisición de EPP: dotación anual de EPP para operaciones de mina superficial'),
('C00002',2,'20450678901','20602000003','45 días calendario','30 días calendario','6 meses','Aprobado','S/.','Almacén Central','2026-01-26','Adquisición de EPP: dotación de EPP para obra edificio multifamiliar Los Pinos'),
('C00003',3,'71203648','20601999999','30 días calendario','30 días calendario','24 meses','Rechazado','S/.','Almacén de Obra','2026-02-06','Adquisición de EPP: EPP para cuadrilla de mejoramiento de carretera Arequipa–Yura'),
('C00004',4,'20450456789','20602000001','15 días calendario','30 días calendario','12 meses','Aprobado','S/.','Almacén Central','2026-02-15','Adquisición de EPP: equipos de bioseguridad para personal de salud'),
('C00005',5,'20450789012','20601888888','30 días calendario','30 días calendario','3 meses','Rechazado','S/.','Jefatura de Seguridad Industrial','2026-02-25','Adquisición de EPP: reposición de EPP para planta metalmecánica'),
('C00006',6,'20450890123','20601222222','15 días calendario','7 días calendario','3 meses','Aprobado','S/.','Almacén Central','2026-03-06','Adquisición de EPP: EPP para cuadrillas de mantenimiento vial regional'),
('C00007',7,'20450567890','20602000003','45 días calendario','30 días calendario','12 meses','Aprobado','S/.','Oficina de Servicios Generales','2026-03-17','Adquisición de EPP: EPP para laboratorios y talleres de ingeniería'),
('C00008',8,'20450345678','20601777777','30 días calendario','7 días calendario','12 meses','Aprobado','S/.','Almacén Central','2026-03-29','Adquisición de EPP: EPP para personal de limpieza pública y obras menores'),
('C00009',9,'20451012345','20602000001','45 días calendario','7 días calendario','3 meses','Pendiente','S/.','Jefatura de Almacén','2026-04-10','Adquisición de EPP: EPP para operarios de almacén y carga'),
('C00010',1,'20450123456','20602000002','15 días calendario','15 días calendario','3 meses','Aprobado','S/.','Almacén Central','2026-04-17','Adquisición de EPP: dotación anual de EPP para operaciones de mina superficial'),
('C00011',2,'20450678901','20601999999','15 días calendario','7 días calendario','12 meses','Aprobado','S/.','Residencia de Obra','2026-05-01','Adquisición de EPP: dotación de EPP para obra edificio multifamiliar Los Pinos'),
('C00012',3,'20450567890','20602000003','45 días calendario','15 días calendario','12 meses','Aprobado','S/.','Almacén Central','2026-05-09','Adquisición de EPP: EPP para cuadrilla de mejoramiento de carretera Arequipa–Yura'),
('C00013',4,'20450456789','20601666666','15 días calendario','15 días calendario','24 meses','Aprobado','S/.','Oficina de Logística','2026-05-20','Adquisición de EPP: equipos de bioseguridad para personal de salud'),
('C00014',5,'20450789012','20601444444','30 días calendario','15 días calendario','24 meses','Pendiente','S/.','Almacén Central','2026-05-28','Adquisición de EPP: reposición de EPP para planta metalmecánica'),
('C00015',6,'20450890123','20602000003','30 días calendario','15 días calendario','6 meses','Pendiente','USD','Gerencia de Infraestructura','2026-06-10','Adquisición de EPP: EPP para cuadrillas de mantenimiento vial regional'),
('C00016',7,'20450567890','20601222222','15 días calendario','15 días calendario','24 meses','Pendiente','S/.','Almacén Central','2026-06-18','Adquisición de EPP: EPP para laboratorios y talleres de ingeniería'),
('C00017',8,'20450345678','20601444444','30 días calendario','15 días calendario','3 meses','Pendiente','S/.','Subgerencia de Servicios Públicos','2026-06-29','Adquisición de EPP: EPP para personal de limpieza pública y obras menores'),
('C00018',9,'45871236','20602000002','15 días calendario','30 días calendario','6 meses','Aprobado','S/.','Almacén Central','2026-07-09','Adquisición de EPP: EPP para operarios de almacén y carga'),
('C00019',1,'20450123456','20601333333','30 días calendario','30 días calendario','6 meses','Aprobado','S/.','Superintendencia de Seguridad y Salud','2026-07-25','Adquisición de EPP: dotación anual de EPP para operaciones de mina superficial'),
('C00020',2,'20450678901','20602000003','45 días calendario','30 días calendario','12 meses','Rechazado','S/.','Almacén Central','2026-07-30','Adquisición de EPP: dotación de EPP para obra edificio multifamiliar Los Pinos'),
('C00021',3,'71203648','20601222222','30 días calendario','7 días calendario','24 meses','Aprobado','S/.','Almacén de Obra','2026-08-11','Adquisición de EPP: EPP para cuadrilla de mejoramiento de carretera Arequipa–Yura'),
('C00022',4,'20450456789','20601999999','45 días calendario','7 días calendario','24 meses','Aprobado','S/.','Almacén Central','2026-08-21','Adquisición de EPP: equipos de bioseguridad para personal de salud'),
('C00023',5,'20450789012','20601444444','15 días calendario','15 días calendario','12 meses','Pendiente','S/.','Jefatura de Seguridad Industrial','2026-09-04','Adquisición de EPP: reposición de EPP para planta metalmecánica'),
('C00024',6,'20450123456','20601888888','45 días calendario','15 días calendario','24 meses','Aprobado','S/.','Almacén Central','2026-09-10','Adquisición de EPP: EPP para cuadrillas de mantenimiento vial regional'),
('C00025',7,'20450567890','20601666666','30 días calendario','15 días calendario','3 meses','Aprobado','S/.','Oficina de Servicios Generales','2026-09-24','Adquisición de EPP: EPP para laboratorios y talleres de ingeniería'),
('C00026',8,'20450345678','20601333333','30 días calendario','15 días calendario','12 meses','Aprobado','S/.','Almacén Central','2026-10-04','Adquisición de EPP: EPP para personal de limpieza pública y obras menores'),
('C00027',9,'20450567890','20601666666','45 días calendario','15 días calendario','24 meses','Aprobado','S/.','Jefatura de Almacén','2026-10-13','Adquisición de EPP: EPP para operarios de almacén y carga'),
('C00028',1,'20450123456','20601555555','30 días calendario','15 días calendario','3 meses','Aprobado','S/.','Almacén Central','2026-10-26','Adquisición de EPP: dotación anual de EPP para operaciones de mina superficial'),
('C00029',2,'20450678901','20601444444','15 días calendario','30 días calendario','24 meses','Aprobado','S/.','Residencia de Obra','2026-11-05','Adquisición de EPP: dotación de EPP para obra edificio multifamiliar Los Pinos'),
('C00030',3,'45871236','20601555555','15 días calendario','7 días calendario','12 meses','Aprobado','S/.','Almacén Central','2026-11-12','Adquisición de EPP: EPP para cuadrilla de mejoramiento de carretera Arequipa–Yura');

INSERT INTO Detalle_Cotizacion (Num_solicitud, ID_Item, Cantidad_Requerida, Precio_Unitario) VALUES
('C00001',9,60.00,12.42),
('C00001',17,50.00,5.23),
('C00002',22,300.00,5.96),
('C00002',25,60.00,56.13),
('C00002',21,20.00,203.46),
('C00003',23,50.00,7.71),
('C00003',1,60.00,27.97),
('C00003',25,25.00,55.43),
('C00003',3,150.00,11.35),
('C00003',16,25.00,73.24),
('C00004',19,100.00,21.19),
('C00004',8,60.00,92.89),
('C00004',3,150.00,12.69),
('C00004',10,150.00,4.07),
('C00004',9,40.00,41.16),
('C00005',11,50.00,22.48),
('C00005',18,50.00,84.46),
('C00006',6,200.00,3.86),
('C00006',25,10.00,55.71),
('C00006',12,100.00,9.24),
('C00006',23,300.00,8.64),
('C00006',3,50.00,13.14),
('C00007',13,200.00,18.68),
('C00007',5,60.00,36.69),
('C00007',19,300.00,24.30),
('C00007',26,40.00,90.75),
('C00007',3,150.00,12.57),
('C00008',10,100.00,4.06),
('C00008',16,50.00,78.32),
('C00008',18,50.00,94.46),
('C00008',12,150.00,9.94),
('C00008',23,150.00,8.82),
('C00009',26,25.00,102.88),
('C00009',13,50.00,18.01),
('C00009',24,60.00,37.87),
('C00009',12,300.00,9.65),
('C00009',1,20.00,26.79),
('C00010',10,150.00,4.94),
('C00010',21,40.00,175.04),
('C00010',15,10.00,146.94),
('C00010',3,50.00,11.99),
('C00010',8,40.00,78.22),
('C00011',22,300.00,5.73),
('C00011',12,300.00,8.19),
('C00012',18,40.00,87.40),
('C00012',1,20.00,29.45),
('C00012',6,200.00,3.57),
('C00012',16,50.00,77.20),
('C00013',19,300.00,24.33),
('C00013',5,40.00,33.86),
('C00013',8,20.00,83.80),
('C00013',26,20.00,96.37),
('C00014',1,60.00,30.34),
('C00014',3,50.00,11.73),
('C00014',11,200.00,19.92),
('C00014',18,25.00,82.63),
('C00014',6,50.00,3.50),
('C00015',18,25.00,22.56),
('C00015',6,100.00,0.93),
('C00015',25,10.00,15.39),
('C00015',12,50.00,2.45),
('C00015',17,100.00,4.53),
('C00016',3,100.00,13.09),
('C00016',19,50.00,22.14),
('C00017',16,20.00,82.26),
('C00017',10,100.00,4.21),
('C00017',23,200.00,7.89),
('C00018',15,20.00,126.69),
('C00018',24,40.00,38.36),
('C00018',17,100.00,17.34),
('C00018',26,40.00,92.31),
('C00018',12,300.00,8.98),
('C00019',10,50.00,4.05),
('C00019',3,150.00,13.12),
('C00019',7,60.00,47.51),
('C00019',21,5.00,178.63),
('C00020',6,300.00,3.32),
('C00020',17,300.00,19.04),
('C00020',21,40.00,202.40),
('C00020',22,150.00,5.68),
('C00021',6,200.00,3.22),
('C00021',18,60.00,79.70),
('C00021',1,25.00,25.57),
('C00021',3,100.00,12.71),
('C00022',8,10.00,87.50),
('C00022',3,150.00,11.57),
('C00023',8,25.00,76.76),
('C00023',6,50.00,3.47),
('C00023',3,100.00,10.95),
('C00024',17,150.00,18.48),
('C00024',6,200.00,3.39),
('C00024',16,60.00,77.52),
('C00024',25,10.00,58.14),
('C00025',9,60.00,41.74),
('C00025',8,60.00,92.93),
('C00025',5,50.00,34.38),
('C00025',26,25.00,99.74),
('C00025',19,150.00,21.68),
('C00026',10,150.00,4.33),
('C00026',17,50.00,17.35),
('C00027',12,50.00,8.49),
('C00027',13,50.00,19.06),
('C00027',1,10.00,26.20),
('C00027',18,20.00,78.71),
('C00027',17,300.00,18.27),
('C00028',2,40.00,44.02),
('C00028',12,200.00,8.85),
('C00028',18,20.00,88.89),
('C00028',5,10.00,32.91),
('C00029',15,20.00,129.72),
('C00029',6,150.00,3.47),
('C00029',12,300.00,8.37),
('C00029',1,20.00,25.75),
('C00029',21,40.00,194.11),
('C00030',16,60.00,81.37),
('C00030',6,200.00,3.90),
('C00030',1,20.00,25.56),
('C00030',3,100.00,12.59);

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

