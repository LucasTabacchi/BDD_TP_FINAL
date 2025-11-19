BEGIN;

-- ============================
-- 1) PROVINCIA / CIUDAD
-- ============================
INSERT INTO Provincia (nombre) VALUES
('Buenos Aires'),
('Córdoba');

INSERT INTO Ciudad (id_provincia, cp, nombre) VALUES
(1, '1000', 'CABA'),
(1, '1704', 'Ramos Mejía'),
(2, '5000', 'Córdoba Capital');

-- ============================
-- 2) USUARIOS / DIRECCIONES
-- ============================
INSERT INTO Usuario (nombre, apellido, email, contrasenia, rol) VALUES
('Ana',   'Pérez', 'ana@example.com',   'password1', 'cliente_app'),
('Bruno', 'Gómez', 'bruno@example.com', 'password2', 'cliente_app'),
('Lucía', 'Rivas', 'lucia@example.com', 'password3', 'admin_app'),
('Carlos','López', 'carlos@example.com','password4', 'operador_logistica');

INSERT INTO Direccion (id_usuario, id_ciudad, calle) VALUES
(1, 1, 'Av. Siempre Viva 123'),
(1, 2, 'San Martín 456'),
(2, 3, 'Bv. Central 789');

-- ============================
-- 3) PRODUCTOS / PROMOCIONES
-- ============================
INSERT INTO Producto (nombre, stock, precio, descripcion) VALUES
('Auriculares Bluetooth', 10, 15000.00, 'Auriculares inalámbricos con micrófono'),
('Mouse Gamer',            5,  8000.00, 'Mouse óptico RGB'),
('Teclado Mecánico',       0, 20000.00, 'Teclado mecánico switch rojo');


INSERT INTO Promocion (id_producto, fechaInicio, fechaFin, titulo, descripcion, descuento, activa) VALUES
(1, '2025-11-01', '2025-11-30', 'Promo Auris',   'Descuento en auriculares', 15, TRUE),
(3, '2025-12-01', '2025-12-31', 'Promo Teclado', 'Promo navideña teclado',   20, FALSE);

-- ============================
-- 4) INGRESO DE PRODUCTOS
--     (Prueba triggers:
--      establecer_fecha_ingreso + actualizar_stock_ingreso)
-- ============================
-- Uno con fecha explícita
INSERT INTO ingresoProducto (id_producto, fecha, cant) VALUES
(1, '2025-11-10', 5);

-- Uno SIN fecha (debe completarse con CURRENT_DATE)
INSERT INTO ingresoProducto (id_producto, fecha, cant) VALUES
(3, NULL, 20);

-- En este punto, el stock esperado (si todo OK) es:
--  producto 1: 10 + 5 = 15
--  producto 2: 5
--  producto 3: 0 + 20 = 20

-- ============================
-- 5) CARRITOS
-- ============================
INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total) VALUES
(1, '2025-11-15', '2025-11-15', 'activo',  0),
(1, '2025-10-01', '2025-10-05', 'cerrado', 30000.00);

-- IDs esperados:
--  carrito_id 1 -> activo
--  carrito_id 2 -> cerrado

-- ============================
-- 6) LINEAS DE CARRITO
--     (Prueba triggers:
--      establecer_fecha_agregado_carrito,
--      validar_carrito_activo,
--      validar_stock_carrito,
--      calcular_subtotal_carrito,
--      actualizar_total_carrito)
-- ============================

-- Líneas válidas en carrito ACTIVO (id 1)
-- fecha_agregado NULL -> trigger pone CURRENT_DATE
-- subtotal = 0 -> trigger lo recalcula (cantidad * precio_unitario)
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal) VALUES
(1, 1, NULL, 2, 15000.00, 0),  -- 2 auriculares
(1, 3, NULL, 3, 20000.00, 0);  -- 3 teclados

-- Después de esto:
--  - trigger_calcular_subtotal_carrito: calcula subtotales
--  - trigger_establecer_fecha_agregado_carrito: fecha_agregado = CURRENT_DATE
--  - trigger_validar_carrito_activo: solo permite carrito 1 (activo)
--  - trigger_validar_stock_carrito: suma cantidades y las compara con stock
--  - trigger_actualizar_total_carrito: actualiza total y fecha_actualizacion del carrito

-- PRUEBAS DE ERROR (para probar validaciones)
-- DESCOMENTAR una por una para probar:

-- 1) Carrito cerrado -> DEBE FALLAR por trigger_validar_carrito_activo
-- INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
-- VALUES (2, 1, NULL, 1, 15000.00, 0);

-- 2) Stock insuficiente en carrito -> DEBE FALLAR por trigger_validar_stock_carrito
-- (p.ej. intentar poner 100 teclados en carrito 1)
-- INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
-- VALUES (1, 3, NULL, 100, 20000.00, 0);

-- ============================
-- 7) FACTURA
--     (Prueba: establecer_fecha_factura)
-- ============================
INSERT INTO Factura (id_usuario, fecha, monto_total) VALUES
(1, NULL, 0);  -- fecha se completa con CURRENT_DATE

-- factura_id esperado = 1

-- ============================
-- 8) LINEAS DE FACTURA
--     (Prueba triggers:
--      calcular_subtotal_factura,
--      validar_stock_factura,
--      reducir_stock_factura,
--      actualizar_monto_total_factura,
--      restaurar_stock_factura con DELETE)
-- ============================
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal) VALUES
(1, 1, 15000.00, 10, 4, 0),   -- 4 auriculares con 10% descuento
(1, 3, 20000.00, NULL, 5, 0); -- 5 teclados sin descuento

-- Efectos esperados:
--  - validar_stock_factura: verifica que 4 <= stock(1) y 5 <= stock(3)
--  - calcular_subtotal_factura:
--        linea 1: 15000 * (1 - 0.10) * 4 = 13500 * 4 = 54000
--        linea 2: 20000 * 5 = 100000
--  - reducir_stock_factura:
--        producto 1: 15 - 4 = 11
--        producto 3: 20 - 5 = 15
--  - actualizar_monto_total_factura:
--        factura.monto_total = 54000 + 100000 = 154000

-- Para probar RESTAURAR STOCK:
-- DESCOMENTAR:
-- DELETE FROM lineaFactura
-- WHERE id_factura = 1 AND id_producto = 3;
-- Esto debería:
--   - devolver al stock los 5 teclados (15 + 5 = 20)
--   - recalcular el monto_total de la factura

-- ============================
-- 9) PAGO
-- ============================
INSERT INTO pago (id_factura, monto, metodo) VALUES
(1, 417200.00, 'mercadopago');

-- ============================
-- 10) ENVÍO
--      (Prueba trigger_validar_transicion_estado_envio)
-- ============================
INSERT INTO Envio (id_direccion, id_factura, estado, fechaArribo, fechaEntrega, costoEnvio) VALUES
(1, 1, 'pendiente', NULL, NULL, 1500.00);

-- envio_id esperado = 1

-- Transiciones de estado para probar:
-- (la función completa fechaArribo/fechaEntrega y evita retroceder desde 'entregado')

-- En preparación
UPDATE Envio
SET estado = 'enPreparacion'
WHERE envio_id = 1;

-- En camino (si fechaArribo es NULL, se setea a CURRENT_DATE)
UPDATE Envio
SET estado = 'enCamino'
WHERE envio_id = 1;

-- Entregado (si fechaEntrega es NULL, se setea a CURRENT_DATE)
UPDATE Envio
SET estado = 'entregado'
WHERE envio_id = 1;

-- Intentar retroceder DEBE FALLAR:
-- UPDATE Envio
-- SET estado = 'enCamino'
-- WHERE envio_id = 1;

-- ============================
-- 11) FAVORITOS
--      (Prueba establecer_fecha_creacion_favorito)
-- ============================
INSERT INTO Favorito (id_usuario, id_producto, fecha_creacion, fecha_eliminacion) VALUES
(1, 1, NULL, NULL),                      -- fecha_creacion se completa con CURRENT_DATE
(1, 2, '2025-10-01', NULL),
(2, 3, '2025-10-05', '2025-10-20');      -- ejemplo con fecha_eliminacion

-- ============================
-- 12) RESEÑAS
--      (Prueba establecer_fecha_resena)
-- ============================
INSERT INTO Reseña (id_usuario, id_producto, calificacion, comentario, fecha) VALUES
(1, 1, 5, 'Excelente producto', NULL),       -- fecha se completa con CURRENT_DATE
(1, 3, 4, 'Muy bueno, recomendado', '2025-11-10');

COMMIT;

SELECT * FROM Producto ORDER BY producto_id;
SELECT * FROM Carrito ORDER BY carrito_id;
SELECT * FROM lineaCarrito ORDER BY id_carrito, id_producto;
SELECT * FROM Factura ORDER BY factura_id;
SELECT * FROM lineaFactura ORDER BY id_factura, id_producto;
SELECT * FROM Envio ORDER BY envio_id;

--PRUEBAS TRIGGERS

--1) ACTUALIZAR STOCK INGRESO
INSERT INTO ingresoProducto (id_producto, fecha, cant) VALUES (1, CURRENT_DATE, 10);
SELECT stock FROM Producto WHERE producto_id = 1;

--2) CALCULAR SUBTOTAL CARRITO
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
VALUES (1, 2, NULL, 3, 8000, 0); --8 X 3 = 24000
SELECT subtotal FROM lineaCarrito WHERE id_carrito = 1 AND id_producto = 2;

-- 3) VALIDAR CARRITO ACTIVO (FALLA)
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
VALUES (2, 1, NULL, 1, 15000, 0);

-- 4) VALIDAR STOCK CARRITO (FALLA)
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
VALUES (1, 3, NULL, 999, 20000, 0);

-- 5) ACTUALIZAR TOTAL CARRITO
UPDATE lineaCarrito
SET cantidad = 6
WHERE id_carrito = 1 AND id_producto = 1; -- ahora 6 X 15000 = 90000
SELECT total, fecha_actualizacion FROM Carrito WHERE carrito_id = 1;

-- 6) CALCULAR SUBTOTAL FACTURA
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (1, 1, 15000, 10, 5, 0);

UPDATE lineaFactura  -- calcular subtotal y actualiza stock
SET cantidad = 2
WHERE id_factura = 1 AND id_producto = 1; -- ahora 2 X 15000 X 0.9 = 27000    

SELECT subtotal FROM lineaFactura WHERE id_factura = 1 AND id_producto = 1;

-- 7) VALIDAR STOCK FACTURA (FALLA) (el stock se reduce  )
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (1, 1, 15000, NULL, 999, 0);


-- 8) REDUCIR STOCK FACTURA
SELECT stock FROM Producto WHERE producto_id = 3;
-- luego insertás:
UPDATE lineaFactura 
SET cantidad = 14
WHERE id_factura = 1 AND id_producto = 3; 
SELECT stock FROM Producto WHERE producto_id = 3;  -- antes 15, ahora 1

INSERT INTO producto (nombre, stock, precio, descripcion) VALUES
('Mousepad', 50, 30000.00, 'Descripcion test');

-- 9) RESTAURAR STOCK FACTURA
SELECT stock FROM Producto WHERE producto_id = 4; -- debe ser 50

INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (1, 4, 30000, NULL, 10, 0);

DELETE FROM lineaFactura
WHERE id_factura = 1 AND id_producto = 4;

-- 10) CALCULAR MONTO TOTAL FACTURA
SELECT * FROM lineafactura;
SELECT monto_total FROM factura WHERE factura_id = 1;


INSERT INTO producto (nombre, stock, precio, descripcion) VALUES
('Webcam', 20, 50000.00, 'Descripcion test 2');

SELECT * FROM producto;

INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (1, 5, 50000, 5, 2, 0);

--11) VALIDAR TRANSICION ESTADO ENVIO (FALLA)
UPDATE Envio
SET estado = 'enCamino' 
WHERE envio_id = 1; -- ya estaba en 'entregado', no puede retroceder

SELECT * FROM ingresoProducto;
SELECT * FROM factura;
SELECT * FROM carrito;
SELECT * FROM lineaCarrito;
SELECT * FROM envio;

-- falla ya que el usuario puede tener solo un carrito activo
INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total) VALUES
(1, '2025-11-17', '2025-11-17', 'activo',  0)

-- VIEWS TESTING

SELECT * FROM v_carritos_activos;

SELECT * FROM v_catalogo_productos;

SELECT * FROM v_detalle_carrito;

SELECT * FROM v_detalle_factura WHERE factura_id = 1;

SELECT * FROM v_envios_pendientes;

SELECT * FROM v_facturas_completas WHERE factura_id = 1;

SELECT * FROM v_mis_envios WHERE envio_id = 1;

SELECT * FROM v_perfil_usuario WHERE usuario_id = 1;

SELECT * FROM v_productos_populares;

SELECT * FROM v_productos_stock;

SELECT * FROM v_productos_stock_bajo;

SELECT * FROM v_resenas_productos WHERE id_producto = 1;

SELECT * FROM v_usuario_publico WHERE usuario_id = 3;

SELECT * FROM v_ventas_producto;


BEGIN;
-- Usuarios de prueba
CREATE USER usr_admin_app       PASSWORD 'admin123';
CREATE USER usr_op_comercial    PASSWORD 'comercial123';
CREATE USER usr_op_logistica    PASSWORD 'logistica123';
CREATE USER usr_cliente_app     PASSWORD 'cliente123';

-- Asignar roles
GRANT admin_app         TO usr_admin_app;
GRANT operador_comercial TO usr_op_comercial;
GRANT operador_logistica TO usr_op_logistica;
GRANT cliente_app        TO usr_cliente_app;
COMMIT;

-- SET ROLE usr_op_comercial;
-- -- o
-- SET ROLE usr_admin_app;  -- según cómo lo manejes


-- admin_app: puede todo
SET ROLE admin_app;

-- Favorables (deberían funcionar todas), no tiene casos desfavorables

-- Insertar producto
INSERT INTO Producto (nombre, stock, precio, descripcion)
VALUES ('Producto admin', 10, 9999.99, 'Creado por admin_app');

-- Actualizar producto
UPDATE Producto
SET precio = 12345.67
WHERE nombre = 'Producto admin';

-- Borrar producto
DELETE FROM Producto
WHERE nombre = 'Producto admin';

-- Insertar usuario
INSERT INTO Usuario (nombre, apellido, email, contrasenia, rol)
VALUES ('Admin', 'Test', 'admin_test@example.com', 'password1', 'admin_app');

-- Borrar factura
INSERT INTO FACTURA (id_usuario, fecha, monto_total) VALUES
(2, CURRENT_DATE, 5000.00);

DELETE FROM Factura
WHERE factura_id = 2;  -- si existe

-- Insertar envío
INSERT INTO Envio (id_direccion, id_factura, estado, costoEnvio)
VALUES (1, 1, 'pendiente', 1000.00);


-- operador_comercial: puede gestionar productos y facturas

SET ROLE operador_comercial;

-- Casos favorables

-- 1) Ver provincias (solo lectura)
SELECT * FROM Provincia;

-- 2) CRUD de Producto
INSERT INTO Producto (nombre, stock, precio, descripcion)
VALUES ('Prod Comercial', 5, 5000.00, 'Creado por operador_comercial');

UPDATE Producto
SET precio = 5500.00
WHERE nombre = 'Prod Comercial';

DELETE FROM Producto
WHERE nombre = 'Prod Comercial';

-- 3) CRUD de Promocion
INSERT INTO Promocion (id_producto, fechaInicio, fechaFin, titulo, descripcion, descuento, activa)
VALUES (1, CURRENT_DATE, CURRENT_DATE + 10, 'Promo test', 'desc', 10, TRUE);

UPDATE Promocion
SET descuento = 15
WHERE titulo = 'Promo test';

DELETE FROM Promocion
WHERE titulo = 'Promo test';

-- 4) Ver reseñas (lectura)
SELECT * FROM Reseña;

-- 5) Ver carritos y facturas (lectura)
SELECT * FROM Carrito;
SELECT * FROM Factura;
SELECT * FROM lineaFactura;

-- Casos no favorables (deben FALLAR)

-- 6) Intentar insertar ingreso de producto (no tiene INSERT en ingresoProducto)
INSERT INTO ingresoProducto (id_producto, cant)
VALUES (1, 10);
-- Esperado: ERROR: permission denied for table ingresoproducto

-- 7) Intentar borrar reseñas (solo tiene SELECT sobre Reseña)
DELETE FROM Reseña
WHERE id_usuario = 1 AND id_producto = 1;
-- Esperado: ERROR: permission denied for table reseña

-- 8) Intentar insertar envío (no tiene permisos sobre Envio)
INSERT INTO Envio (id_direccion, id_factura, estado, costoEnvio)
VALUES (1, 1, 'pendiente', 500);
-- Esperado: ERROR: permission denied for table envio

-- 9) Intentar insertar usuario (no tiene INSERT sobre Usuario)
INSERT INTO Usuario (nombre, apellido, email, contrasenia, rol)
VALUES ('Test', 'OP_COM', 'op_com@example.com', 'password1', 'cliente_app');
-- Esperado: ERROR: permission denied for table usuario


-- operador_logistica: puede gestionar envíos

SET ROLE operador_logistica;

-- Casos favorables

-- 1) Ver provincias y ciudades
SELECT * FROM Provincia;
SELECT * FROM Ciudad;

-- 2) Ver productos
SELECT producto_id, nombre, stock FROM Producto;

-- 3) Actualizar SOLO stock de un producto
UPDATE Producto
SET stock = stock + 50
WHERE producto_id = 5;
-- (Tiene GRANT UPDATE (stock) ON Producto)

-- 4) CRUD completo de ingresoProducto
INSERT INTO ingresoProducto (id_producto, fecha, cant)
VALUES (5, CURRENT_DATE, 20);

UPDATE ingresoProducto
SET cant = 25
WHERE ingreso_id = 1;  -- ajustá a un id real

-- DELETE FROM ingresoProducto
-- WHERE ingreso_id = 1;  -- ajustá a un id real

-- 5) CRUD de Envio
INSERT INTO FACTURA (id_usuario, fecha, monto_total) VALUES
(2, CURRENT_DATE, 5000.00);

INSERT INTO Envio (id_direccion, id_factura, estado, costoEnvio)
VALUES (1, 3, 'pendiente', 1500.00);

UPDATE Envio
SET estado = 'enCamino'
WHERE envio_id = 5;    -- ajustá a un id real

DELETE FROM Envio
WHERE envio_id = 5;    -- ajustá a un id real

-- 6) Ver direcciones, facturas, usuarios, carritos
SELECT * FROM Direccion;
SELECT * FROM Factura;
SELECT * FROM Usuario;
SELECT * FROM Carrito;

-- SELECT * FROM envio;

-- Casos no favorables (deben FALLAR)

-- 7) Intentar cambiar el precio del producto (solo tiene UPDATE(stock))
UPDATE Producto
SET precio = 9999.99
WHERE producto_id = 5;
-- Esperado: ERROR: permission denied for relation producto (columna precio)

-- 8) Intentar insertar producto (no tiene INSERT en Producto)
INSERT INTO Producto (nombre, stock, precio, descripcion)
VALUES ('Prod Logistica', 5, 2000.00, 'Prueba');
-- Esperado: ERROR: permission denied for table producto

-- 9) Intentar insertar promoción (no tiene permisos en Promocion)
INSERT INTO Promocion (id_producto, fechaInicio, fechaFin, titulo, descripcion, descuento, activa)
VALUES (1, CURRENT_DATE, CURRENT_DATE + 5, 'Promo Log', 'desc', 5, TRUE);
-- Esperado: ERROR: permission denied for table promocion

-- 10) Intentar insertar reseña (no tiene permisos en Reseña)
INSERT INTO Reseña (id_usuario, id_producto, calificacion, comentario)
VALUES (1, 1, 5, 'Excelente');
-- Esperado: ERROR: permission denied for table reseña


-- cliente_app: puede gestionar su perfil, carritos, facturas, reseñas y favoritos

-- Casos favorables

SET ROLE cliente_app;

-- 1) Ver catálogo y promociones
SELECT * FROM Producto;
SELECT * FROM Promocion;

-- 2) Insertar una dirección
INSERT INTO Direccion (id_usuario, id_ciudad, calle)
VALUES (2, 1, 'Direccion cliente_app');

-- 3) Actualizar una dirección
UPDATE Direccion
SET calle = 'Direccion cliente_app MODIFICADA'
WHERE direccion_id = 4;  -- ajustá a un id que exista

-- 4) Crear un carrito
INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total)
VALUES (2, CURRENT_DATE, CURRENT_DATE, 'activo', 0);

-- 5) Insertar línea de carrito
INSERT INTO lineaCarrito (id_carrito, id_producto, cantidad, precio_unitario, subtotal)
VALUES (5, 1, 2, 15000, 0);

-- 6) Crear favorito
INSERT INTO Favorito (id_usuario, id_producto, fecha_creacion)
VALUES (2, 1, CURRENT_DATE);

-- 7) Crear reseña
INSERT INTO Reseña (id_usuario, id_producto, calificacion, comentario, fecha)
VALUES (2, 1, 5, 'Muy bueno', CURRENT_DATE);

-- 8) Ver facturas
SELECT * FROM Factura;
SELECT * FROM lineaFactura;

-- 9) Ver pagos
SELECT * FROM Pago;

-- 10) Ver envíos
SELECT * FROM Envio;


-- Casos no favorables (deben FALLAR)

-- 11) Intentar insertar producto (solo debería ver, no administrar catálogo)
INSERT INTO Producto (nombre, stock, precio, descripcion)
VALUES ('Prod Cliente', 1, 1000, 'No debería poder');
-- Esperado: ERROR: permission denied for table producto

-- 12) Intentar borrar producto
DELETE FROM Producto
WHERE producto_id = 1;
-- Esperado: ERROR: permission denied for table producto

-- 13) Intentar insertar factura (en la vida real esto lo haría el backend, no el cliente)
INSERT INTO Factura (id_usuario, monto_total)
VALUES (1, 99999);
-- Esperado: ERROR: permission denied for table factura (no tiene INSERT)

-- 14) Intentar insertar ingreso de producto (no debería poder tocar stock)
INSERT INTO ingresoProducto (id_producto, cant)
VALUES (1, 100);
-- Esperado: ERROR: permission denied for table ingresoproducto

-- 15) Intentar administración de envíos (insertar)
INSERT INTO Envio (id_direccion, id_factura, estado, costoEnvio)
VALUES (1, 1, 'pendiente', 1000);
-- Esperado: ERROR: permission denied for table envio

SET ROLE postgres;  -- volver a superusuario