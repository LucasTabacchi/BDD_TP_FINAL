BEGIN;

-- =========================================================
-- PROVINCIA (15 filas)
-- =========================================================
INSERT INTO Provincia (nombre) VALUES
('Buenos Aires'),
('Córdoba'),
('Santa Fe'),
('Mendoza'),
('Tucumán'),
('Salta'),
('San Juan'),
('Neuquén'),
('Río Negro'),
('Chubut'),
('Misiones'),
('Entre Ríos'),
('La Pampa'),
('San Luis'),
('Formosa');

-- =========================================================
-- CIUDAD (15 filas)
-- =========================================================
INSERT INTO Ciudad (id_provincia, cp, nombre) VALUES
(1,  '1000', 'CABA'),
(1,  '1704', 'Ramos Mejía'),
(2,  '5000', 'Córdoba Capital'),
(3,  '2000', 'Rosario'),
(4,  '5500', 'Mendoza'),
(5,  '4000', 'San Miguel de Tucumán'),
(6,  '4400', 'Salta'),
(7,  '5400', 'San Juan'),
(8,  '8300', 'Neuquén'),
(9,  '8500', 'Viedma'),
(10, '9000', 'Rawson'),
(11, '3300', 'Posadas'),
(12, '3100', 'Paraná'),
(13, '6300', 'Santa Rosa'),
(14, '5700', 'San Luis');

-- =========================================================
-- USUARIO (15 filas)
-- =========================================================
INSERT INTO Usuario (nombre, apellido, email, contrasenia, rol) VALUES
('Ana',     'Pérez',    'ana@example.com',      'Password1',   'cliente_app'),
('Bruno',   'García',   'bruno@example.com',    'Password2',   'cliente_app'),
('Carla',   'López',    'carla@example.com',    'Password3',   'cliente_app'),
('Diego',   'Martínez', 'diego@example.com',    'Password4',   'cliente_app'),
('Elena',   'Suárez',   'elena@example.com',    'Password5',   'cliente_app'),
('Fernando','Rossi',    'fernando@example.com', 'Password6',   'operador_comercial'),
('Gabriela','Santos',   'gabriela@example.com', 'Password7',   'operador_comercial'),
('Hernán',  'Torres',   'hernan@example.com',   'Password8',   'operador_logistica'),
('Inés',    'Moreno',   'ines@example.com',     'Password9',   'operador_logistica'),
('Julián',  'Díaz',     'julian@example.com',   'Password10',  'admin_app'),
('Karen',   'Vega',     'karen@example.com',    'Password11',  'cliente_app'),
('Luis',    'Navarro',  'luis@example.com',     'Password12',  'cliente_app'),
('María',   'Castro',   'maria@example.com',    'Password13',  'cliente_app'),
('Nicolás', 'Ferrer',   'nicolas@example.com',  'Password14',  'cliente_app'),
('Olga',    'Silva',    'olga@example.com',     'Password15',  'cliente_app');
-- usuario_id = 1..15 en este orden

-- =========================================================
-- DIRECCION (15 filas)
-- =========================================================
INSERT INTO Direccion (id_usuario, id_ciudad, calle) VALUES
(1,  1,  'Av. Siempre Viva 123'),
(2,  2,  'Mitre 456'),
(3,  3,  'Colón 789'),
(4,  4,  'San Martín 101'),
(5,  5,  'Rivadavia 202'),
(6,  6,  'Belgrano 303'),
(7,  7,  'Sarmiento 404'),
(8,  8,  'Alsina 505'),
(9,  9,  'Urquiza 606'),
(10, 10, 'Lavalle 707'),
(11, 11, 'French 808'),
(12, 12, '25 de Mayo 909'),
(13, 13, 'España 1001'),
(14, 14, 'Italia 1102'),
(15, 15, 'Brasil 1203');
-- direccion_id = 1..15 en este orden

-- =========================================================
-- PRODUCTO (15 filas)
-- =========================================================
INSERT INTO Producto (nombre, stock, precio, descripcion) VALUES
('Producto 1',  1000, 100.00, 'Descripción producto 1'),
('Producto 2',  1000, 150.00, 'Descripción producto 2'),
('Producto 3',  1000, 200.00, 'Descripción producto 3'),
('Producto 4',  1000, 250.00, 'Descripción producto 4'),
('Producto 5',  1000, 300.00, 'Descripción producto 5'),
('Producto 6',  1000, 350.00, 'Descripción producto 6'),
('Producto 7',  1000, 400.00, 'Descripción producto 7'),
('Producto 8',  1000, 450.00, 'Descripción producto 8'),
('Producto 9',  1000, 500.00, 'Descripción producto 9'),
('Producto 10', 1000, 550.00, 'Descripción producto 10'),
('Producto 11', 1000, 600.00, 'Descripción producto 11'),
('Producto 12', 1000, 650.00, 'Descripción producto 12'),
('Producto 13', 1000, 700.00, 'Descripción producto 13'),
('Producto 14', 1000, 750.00, 'Descripción producto 14'),
('Producto 15', 1000, 800.00, 'Descripción producto 15');
-- producto_id = 1..15

-- =========================================================
-- PROMOCION (15 filas)
-- =========================================================
INSERT INTO Promocion (id_producto, fechaInicio, fechaFin, titulo, descripcion, descuento, activa) VALUES
(1,  '2025-01-01', '2025-12-31', 'Promo 1',  'Descuento producto 1', 10, true),
(2,  '2025-01-01', '2025-03-31', 'Promo 2',  'Descuento producto 2', 15, true),
(3,  '2025-02-01', '2025-05-31', 'Promo 3',  'Descuento producto 3', 5,  true),
(4,  '2025-03-01', '2025-06-30', 'Promo 4',  'Descuento producto 4', 20, false),
(5,  '2025-04-01', '2025-07-31', 'Promo 5',  'Descuento producto 5', 25, true),
(6,  '2025-05-01', '2025-08-31', 'Promo 6',  'Descuento producto 6', 30, true),
(7,  '2025-06-01', '2025-09-30', 'Promo 7',  'Descuento producto 7', 10, false),
(8,  '2025-07-01', '2025-10-31', 'Promo 8',  'Descuento producto 8', 5,  true),
(9,  '2025-08-01', '2025-11-30', 'Promo 9',  'Descuento producto 9', 15, true),
(10, '2025-01-15', '2025-04-15', 'Promo 10', 'Descuento producto 10',20, false),
(11, '2025-02-15', '2025-05-15', 'Promo 11', 'Descuento producto 11',10, true),
(12, '2025-03-15', '2025-06-15', 'Promo 12', 'Descuento producto 12',5,  true),
(13, '2025-04-15', '2025-07-15', 'Promo 13', 'Descuento producto 13',15, false),
(14, '2025-05-15', '2025-08-15', 'Promo 14', 'Descuento producto 14',10, true),
(15, '2025-06-15', '2025-09-15', 'Promo 15', 'Descuento producto 15',20, true);
-- promocion_id = 1..15

-- =========================================================
-- INGRESO PRODUCTO (15 filas) - actualiza stock por trigger
-- =========================================================
INSERT INTO ingresoProducto (id_producto, fecha, cant) VALUES
(1,  '2025-10-01', 100),
(2,  '2025-10-02', 100),
(3,  '2025-10-03', 100),
(4,  '2025-10-04', 100),
(5,  '2025-10-05', 100),
(6,  '2025-10-06', 100),
(7,  '2025-10-07', 100),
(8,  '2025-10-08', 100),
(9,  '2025-10-09', 100),
(10, '2025-10-10', 100),
(11, '2025-10-11', 100),
(12, '2025-10-12', 100),
(13, '2025-10-13', 100),
(14, '2025-10-14', 100),
(15, '2025-10-15', 100);
-- ingreso_id = 1..15

-- =========================================================
-- CARRITO (15 filas, 1 activo por usuario)
-- =========================================================
INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total) VALUES
(1,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(2,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(3,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(4,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(5,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(6,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(7,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(8,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(9,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(10, '2025-10-01', '2025-10-01', 'activo',   0.00),
(1,  '2025-09-01', '2025-09-15', 'cerrado',  500.00),
(2,  '2025-09-02', '2025-09-16', 'cerrado',  750.00),
(3,  '2025-09-03', '2025-09-17', 'cerrado',  900.00),
(4,  '2025-09-04', '2025-09-18', 'cerrado', 1200.00),
(5,  '2025-09-05', '2025-09-19', 'cerrado', 1500.00);
-- carrito_id = 1..15 en este orden

-- =========================================================
-- LINEA CARRITO (15 filas, solo carritos activos 1..10)
-- Ahora el trigger set_precio_y_subtotal_carrito setea precio_unitario y subtotal.
-- Por eso:
--   - NO insertamos precio_unitario
--   - SÍ insertamos subtotal (pero es NOT NULL), entonces lo seteamos dummy 0 y el trigger lo recalcula
--     (el trigger BEFORE INSERT pisa NEW.subtotal).
-- =========================================================
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal) VALUES
(1,  1,  '2025-10-02', 2, 0.00, 0.00),
(1,  2,  '2025-10-02', 1, 0.00, 0.00),
(2,  3,  '2025-10-03', 3, 0.00, 0.00),
(2,  4,  '2025-10-03', 1, 0.00, 0.00),
(3,  5,  '2025-10-04', 2, 0.00, 0.00),
(3,  6,  '2025-10-04', 1, 0.00, 0.00),
(4,  7,  '2025-10-05', 1, 0.00, 0.00),
(4,  8,  '2025-10-05', 2, 0.00, 0.00),
(5,  9,  '2025-10-06', 1, 0.00, 0.00),
(5,  10, '2025-10-06', 1, 0.00, 0.00),
(6,  11, '2025-10-07', 2, 0.00, 0.00),
(7,  12, '2025-10-08', 1, 0.00, 0.00),
(8,  13, '2025-10-09', 1, 0.00, 0.00),
(9,  14, '2025-10-10', 2, 0.00, 0.00),
(10, 15, '2025-10-11', 1, 0.00, 0.00);

-- =========================================================
-- FAVORITO (15 filas)
-- =========================================================
INSERT INTO Favorito (id_usuario, id_producto, fecha_creacion, fecha_eliminacion) VALUES
(1,  1,  '2025-09-01', NULL),
(1,  2,  '2025-09-02', NULL),
(2,  3,  '2025-09-03', NULL),
(2,  4,  '2025-09-04', '2025-09-20'),
(3,  5,  '2025-09-05', NULL),
(3,  6,  '2025-09-06', NULL),
(4,  7,  '2025-09-07', NULL),
(4,  8,  '2025-09-08', NULL),
(5,  9,  '2025-09-09', NULL),
(6,  10, '2025-09-10', NULL),
(7,  11, '2025-09-11', NULL),
(8,  12, '2025-09-12', NULL),
(9,  13, '2025-09-13', NULL),
(10, 14, '2025-09-14', NULL),
(11, 15, '2025-09-15', NULL);

-- =========================================================
-- RESEÑA (15 filas)
-- =========================================================
INSERT INTO Reseña (id_usuario, id_producto, calificacion, comentario, fecha) VALUES
(1,  1, 5, 'Excelente producto',           '2025-09-10'),
(1,  2, 4, 'Muy bueno',                    '2025-09-11'),
(2,  3, 3, 'Aceptable',                    '2025-09-12'),
(2,  4, 4, 'Cumple con lo esperado',       '2025-09-13'),
(3,  5, 5, 'Me encantó',                   '2025-09-14'),
(3,  6, 2, 'Podría ser mejor',             '2025-09-15'),
(4,  7, 4, 'Buen rendimiento',             '2025-09-16'),
(5,  8, 5, 'Lo volvería a comprar',        '2025-09-17'),
(6,  9, 3, 'Calidad promedio',             '2025-09-18'),
(7,  10,4, 'Buen precio-calidad',          '2025-09-19'),
(8,  11,5, 'Excelente relación calidad',   '2025-09-20'),
(9,  12,4, 'Muy conforme',                 '2025-09-21'),
(10, 13,5, 'Producto destacado',           '2025-09-22'),
(11, 14,3, 'Está bien',                    '2025-09-23'),
(12, 15,4, 'Recomendable',                 '2025-09-24');

-- =========================================================
-- FACTURA (15 filas)
-- Ahora Factura tiene estado (emitida/anulada).
-- Si no lo incluís, toma DEFAULT 'emitida'. Lo dejamos explícito.
-- monto_total comienza en 0 y se recalcula al insertar lineaFactura.
-- =========================================================
INSERT INTO Factura (id_usuario, fecha, monto_total, estado) VALUES
(1,  '2025-11-01', 0.00, 'emitida'),
(2,  '2025-11-01', 0.00, 'emitida'),
(3,  '2025-11-02', 0.00, 'emitida'),
(4,  '2025-11-02', 0.00, 'emitida'),
(5,  '2025-11-03', 0.00, 'emitida'),
(6,  '2025-11-03', 0.00, 'emitida'),
(7,  '2025-11-04', 0.00, 'emitida'),
(8,  '2025-11-04', 0.00, 'emitida'),
(9,  '2025-11-05', 0.00, 'emitida'),
(10, '2025-11-05', 0.00, 'emitida'),
(11, '2025-11-06', 0.00, 'emitida'),
(12, '2025-11-06', 0.00, 'emitida'),
(13, '2025-11-07', 0.00, 'emitida'),
(14, '2025-11-07', 0.00, 'emitida'),
(15, '2025-11-08', 0.00, 'emitida');
-- factura_id = 1..15

-- =========================================================
-- LINEA FACTURA (15 filas)
-- Ahora el trigger set_precio_y_subtotal_factura setea precio_unitario y subtotal.
-- Además, tu modelo exige NOT NULL en precio_unitario y subtotal.
-- Por eso:
--   - insertamos precio_unitario y subtotal como 0.00 (valores dummy)
--   - el trigger BEFORE INSERT los pisa con el precio real y el subtotal calculado
-- =========================================================
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal) VALUES
(1,  1,  0.00, 0,  2, 0.00),
(2,  2,  0.00, 10, 3, 0.00),
(3,  3,  0.00, 0,  1, 0.00),
(4,  4,  0.00, 15, 4, 0.00),
(5,  5,  0.00, 0,  2, 0.00),
(6,  6,  0.00, 5,  5, 0.00),
(7,  7,  0.00, 0,  3, 0.00),
(8,  8,  0.00, 20, 2, 0.00),
(9,  9,  0.00, 0,  1, 0.00),
(10, 10, 0.00, 0,  4, 0.00),
(11, 11, 0.00, 0,  2, 0.00),
(12, 12, 0.00, 0,  3, 0.00),
(13, 13, 0.00, 5,  1, 0.00),
(14, 14, 0.00, 0,  2, 0.00),
(15, 15, 0.00, 15, 3, 0.00);

-- =========================================================
-- PAGO (15 filas)
-- IMPORTANTE: validar_pago_total_factura exige que el pago sea EXACTAMENTE el monto_total.
-- Como monto_total lo recalcula el trigger en lineaFactura, NO hardcodeamos montos:
-- los insertamos desde la BD con un SELECT.
-- =========================================================
INSERT INTO Pago (id_factura, monto, metodo)
SELECT f.factura_id, f.monto_total, 'mercadopago'
FROM Factura f
ORDER BY f.factura_id;

-- =========================================================
-- ENVIO (15 filas, 1 por factura)
-- =========================================================
INSERT INTO Envio (id_direccion, id_factura, estado, fechaArribo, fechaEntrega, costoEnvio) VALUES
(1,  1,  'pendiente',     NULL,        NULL,        0.00),
(2,  2,  'enPreparacion', NULL,        NULL,        500.00),
(3,  3,  'enCamino',      '2025-11-03',NULL,        600.00),
(4,  4,  'entregado',     '2025-11-02','2025-11-05',700.00),
(5,  5,  'pendiente',     NULL,        NULL,        400.00),
(6,  6,  'enPreparacion', NULL,        NULL,        450.00),
(7,  7,  'enCamino',      '2025-11-04',NULL,        550.00),
(8,  8,  'entregado',     '2025-11-04','2025-11-06',650.00),
(9,  9,  'pendiente',     NULL,        NULL,        350.00),
(10, 10, 'enPreparacion', NULL,        NULL,        380.00),
(11, 11, 'enCamino',      '2025-11-06',NULL,        420.00),
(12, 12, 'entregado',     '2025-11-06','2025-11-08',460.00),
(13, 13, 'pendiente',     NULL,        NULL,        300.00),
(14, 14, 'enCamino',      '2025-11-07',NULL,        320.00),
(15, 15, 'entregado',     '2025-11-08','2025-11-10',500.00);

COMMIT;