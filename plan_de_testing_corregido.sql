/* ============================================================
   PLAN DE TESTING "SOLO SQL" - ecommerce_db
   Cubre: Permisos + RLS + Triggers + Vistas
   Ejecutar en DBeaver/pgAdmin/DataGrip (sin \c ni \echo)

   INSTRUCCIONES:
   - Abrí 4 conexiones separadas (una por usuario):
       1) julian_diaz     (admin_app)
       2) ana_perez       (cliente_app)
       3) fernando_rossi  (operador_comercial)
       4) hernan_torres   (operador_logistica)
   - Pegá y ejecutá el bloque correspondiente a cada usuario.
   - Ajustá app.user_id en el bloque del cliente (Ana).
   ============================================================ */


/* ============================================================
   0) PRE-CHECK (EJECUTAR COMO: julian_diaz)
   ============================================================ */

-- Rol
SET ROLE admin_app;

-- IDs base
SELECT usuario_id, email, rol
FROM Usuario
ORDER BY usuario_id;

-- Productos
SELECT producto_id, nombre, precio, stock
FROM Producto
ORDER BY producto_id
LIMIT 15;

-- Carritos
SELECT carrito_id, id_usuario, estado, total, fecha_creacion, fecha_actualizacion
FROM Carrito
ORDER BY carrito_id;

-- Facturas
SELECT factura_id, id_usuario, estado, monto_total, fecha
FROM Factura
ORDER BY factura_id;

-- Pagos
SELECT pago_id, id_factura, monto, metodo
FROM Pago
ORDER BY pago_id;

-- Envíos
SELECT envio_id, id_factura, id_direccion, estado, fechaArribo, fechaEntrega, costoEnvio
FROM Envio
ORDER BY envio_id;

-- Vistas existentes (deberían aparecer las 14 de tu captura)
SELECT schemaname, viewname
FROM pg_views
WHERE schemaname='public'
ORDER BY viewname;


/* ============================================================
   1) CLIENTE (EJECUTAR COMO: ana_perez)
   ============================================================ */

-- Contexto RLS
SET ROLE cliente_app;

-- Ajustar: poner el usuario_id real de Ana
-- (si no sabés, consultalo en el bloque de pre-check)
SET app.user_id = '1';

SELECT current_user, current_role, current_setting('app.user_id', true);

-- 1.1 RLS Usuario: debe ver SOLO su fila
SELECT usuario_id, email, rol
FROM Usuario
ORDER BY usuario_id;                  -- esperado: 1 fila

SELECT *
FROM Usuario
WHERE usuario_id = 2;                 -- esperado: 0 filas

-- 1.2 Update propio OK / cambiar rol FAIL (WITH CHECK)
UPDATE Usuario
SET nombre = 'Ana Test'
WHERE usuario_id = 1;                 -- esperado: OK

UPDATE Usuario
SET rol = 'admin_app'
WHERE usuario_id = 1;                 -- esperado: FAIL

-- 1.3 Direcciones: solo propias
SELECT *
FROM Direccion
ORDER BY direccion_id;                -- esperado: solo filas de Ana

DELETE FROM Direccion
WHERE id_usuario = 2;                 -- esperado: FAIL o 0 filas

-- 1.4 Catálogo: SELECT permitido
SELECT producto_id, nombre, precio, stock
FROM Producto
ORDER BY producto_id
LIMIT 10;                             -- OK

SELECT *
FROM Promocion
ORDER BY promocion_id
LIMIT 10;                             -- OK

-- 1.5 Triggers carrito:
-- - precio/subtotal se setean desde Producto
-- - stock se valida
-- - total del carrito se recalcula
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
SELECT c.carrito_id, p.producto_id, CURRENT_DATE, 2, 0.00, 0.00
FROM Carrito c
JOIN Producto p ON TRUE
WHERE c.id_usuario=1 AND c.estado='activo'
  AND NOT EXISTS (
    SELECT 1 FROM lineaCarrito lc
    WHERE lc.id_carrito=c.carrito_id AND lc.id_producto=p.producto_id
  )
ORDER BY p.producto_id
LIMIT 1;

-- Verificar que trigger seteo precio_unitario=subida de Producto.precio y subtotal correcto
SELECT lc.id_carrito, lc.id_producto, lc.cantidad, lc.precio_unitario, lc.subtotal,
       p.precio AS precio_producto
FROM lineaCarrito lc
JOIN Producto p ON p.producto_id = lc.id_producto
WHERE lc.id_carrito = (SELECT carrito_id FROM Carrito WHERE id_usuario=1 AND estado='activo' LIMIT 1)
ORDER BY lc.id_producto;

-- Verificar total del carrito actualizado
SELECT carrito_id, total, fecha_actualizacion
FROM Carrito
WHERE carrito_id = (SELECT carrito_id FROM Carrito WHERE id_usuario=1 AND estado='activo' LIMIT 1);

-- 1.6 Trigger carrito: no permite insertar en carrito cerrado
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
VALUES (
  (SELECT carrito_id FROM Carrito WHERE id_usuario=1 AND estado='cerrado' LIMIT 1),
  2,
  CURRENT_DATE,
  1,
  0.00,
  0.00
);                                     -- esperado: FAIL (carrito cerrado)

-- 1.7 Trigger stock carrito: cantidad > stock falla
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal)
VALUES (
  (SELECT carrito_id FROM Carrito WHERE id_usuario=1 AND estado='activo' LIMIT 1),
  1,
  CURRENT_DATE,
  999999,
  0.00,
  0.00
);                                     -- esperado: FAIL (stock insuficiente)

-- 1.8 Facturas/pagos/envíos: solo lectura (por permisos + RLS)
SELECT factura_id, id_usuario, estado, monto_total
FROM Factura
ORDER BY factura_id;                   -- esperado: solo facturas propias

SELECT *
FROM lineaFactura
ORDER BY id_factura, id_producto;      -- esperado: solo líneas propias

SELECT *
FROM Pago
ORDER BY pago_id;                      -- esperado: solo pagos propios

SELECT *
FROM Envio
ORDER BY envio_id;                     -- esperado: solo envíos propios

-- Operaciones prohibidas sobre Factura/lineaFactura
UPDATE Factura
SET estado='anulada'
WHERE factura_id=1;                    -- esperado: FAIL

UPDATE lineaFactura
SET cantidad=2
WHERE id_factura=1 AND id_producto=1;  -- esperado: FAIL

DELETE FROM lineaFactura
WHERE id_factura=1 AND id_producto=1;  -- esperado: FAIL

-- 1.9 VISTAS (cliente)
SELECT * FROM v_catalogo_productos LIMIT 50;
SELECT * FROM v_usuario_publico LIMIT 50;
SELECT * FROM v_resenas_productos LIMIT 50;

SELECT * FROM v_perfil_usuario LIMIT 50;       -- esperado: solo Ana
SELECT * FROM v_carritos_activos LIMIT 50;     -- esperado: solo carritos de Ana
SELECT * FROM v_detalle_carrito LIMIT 200;     -- esperado: solo detalle de carritos de Ana
SELECT * FROM v_mis_envios LIMIT 200;          -- esperado: solo envíos de Ana

SELECT * FROM v_detalle_factura LIMIT 200;     -- esperado: solo facturas de Ana
SELECT * FROM v_facturas_completas LIMIT 200;  -- esperado: solo facturas de Ana

SELECT * FROM v_productos_populares LIMIT 50;  -- esperado: OK


-- restringidas según diseño
SELECT * FROM v_productos_stock LIMIT 50;
SELECT * FROM v_productos_stock_bajo LIMIT 50;
SELECT * FROM v_ventas_producto LIMIT 50;
SELECT * FROM v_envios_pendientes LIMIT 50;

-- 1.10 RLS sin app.user_id (debe perder acceso personal)
RESET app.user_id;
SELECT * FROM Usuario;                 -- esperado: 0 filas
SELECT * FROM Direccion;               -- esperado: 0 filas
SELECT * FROM v_perfil_usuario;        -- esperado: 0 filas


/* ============================================================
   2) OPERADOR COMERCIAL (EJECUTAR COMO: fernando_rossi)
   ============================================================ */

SET ROLE operador_comercial;

-- 2.1 CRUD Producto OK
INSERT INTO Producto (nombre, stock, precio, descripcion)
VALUES ('Producto Comercial', 10, 123.45, 'Alta por comercial'); -- OK

UPDATE Producto
SET precio = 150.00
WHERE nombre='Producto Comercial';                               -- OK

DELETE FROM Producto
WHERE nombre='Producto Comercial';                               -- OK

-- 2.2 CRUD Promoción OK
INSERT INTO Promocion (id_producto, fechaInicio, fechaFin, titulo, descripcion, descuento, activa)
VALUES (1, CURRENT_DATE, CURRENT_DATE + INTERVAL '10 day', 'Promo Test', 'desc', 10, true); -- OK

-- 2.3 Prohibido tocar datos críticos
UPDATE Usuario SET nombre='X' WHERE usuario_id=1;                -- esperado: FAIL
DELETE FROM Factura WHERE factura_id=1;                          -- esperado: FAIL
INSERT INTO Pago (id_factura, monto, metodo) VALUES (1, 1.00, 'mercadopago'); -- esperado: FAIL

-- 2.4 VISTAS (comercial)
SELECT * FROM v_catalogo_productos LIMIT 50;
SELECT * FROM v_productos_populares LIMIT 50;
SELECT * FROM v_resenas_productos LIMIT 50;
SELECT * FROM v_ventas_producto LIMIT 50;
SELECT * FROM v_usuario_publico LIMIT 50;

SELECT * FROM v_detalle_factura LIMIT 100;
SELECT * FROM v_facturas_completas LIMIT 100;
SELECT * FROM v_envios_pendientes LIMIT 100;

-- Si existen también deberían poder mirar stock (según tus grants)
SELECT * FROM v_productos_stock LIMIT 50;
SELECT * FROM v_productos_stock_bajo LIMIT 50;

/* ============================================================
   3) OPERADOR LOGISTICA (EJECUTAR COMO: hernan_torres)
   ============================================================ */

SET ROLE operador_logistica;

-- 3.1 Producto: solo UPDATE(stock)
UPDATE Producto SET stock = stock + 5 WHERE producto_id=1;       -- OK
UPDATE Producto SET precio = precio + 1 WHERE producto_id=1;     -- esperado: FAIL

-- 3.2 Trigger ingresoProducto -> actualiza stock
SELECT stock FROM Producto WHERE producto_id=1;
INSERT INTO ingresoProducto (id_producto, cant) VALUES (1, 10);  -- OK
SELECT stock FROM Producto WHERE producto_id=1;                  -- debe aumentar +10

-- 3.3 Trigger transición de estados de envío
SELECT envio_id, estado, fechaArribo, fechaEntrega
FROM Envio
ORDER BY envio_id
LIMIT 10;

UPDATE Envio
SET estado='enCamino', fechaArribo=NULL
WHERE envio_id=1;                                                -- OK (setea fechaArribo)

SELECT envio_id, estado, fechaArribo, fechaEntrega
FROM Envio
WHERE envio_id=1;

UPDATE Envio
SET estado='entregado', fechaEntrega=NULL
WHERE envio_id=1;                                                -- OK (setea fechaEntrega)

SELECT envio_id, estado, fechaArribo, fechaEntrega
FROM Envio
WHERE envio_id=1;

UPDATE Envio
SET estado='enCamino'
WHERE envio_id=1;                                                -- esperado: FAIL (retroceso)

-- 3.4 Prohibido tocar Factura/lineaFactura
UPDATE Factura SET estado='anulada' WHERE factura_id=1;          -- esperado: FAIL
UPDATE lineaFactura SET cantidad=2 WHERE id_factura=1 AND id_producto=1; -- esperado: FAIL
DELETE FROM lineaFactura WHERE id_factura=1 AND id_producto=1;   -- esperado: FAIL

-- 3.5 VISTAS (logística)
SELECT * FROM v_productos_stock LIMIT 50;
SELECT * FROM v_productos_stock_bajo LIMIT 50;
SELECT * FROM v_envios_pendientes LIMIT 100;
SELECT * FROM v_facturas_completas LIMIT 100;
SELECT * FROM v_detalle_factura LIMIT 100;


/* ============================================================
   4) ADMIN (EJECUTAR COMO: julian_diaz)
   ============================================================ */

SET ROLE admin_app;

-- 4.1 Inmutabilidad Factura: no UPDATE/DELETE directo
UPDATE Factura SET monto_total=999 WHERE factura_id=1;           -- esperado: FAIL
DELETE FROM Factura WHERE factura_id=1;                          -- esperado: FAIL

-- 4.2 anular_factura() OK
SELECT anular_factura(1, 'Prueba de anulación');                 -- OK
SELECT factura_id, estado FROM Factura WHERE factura_id=1;

-- 4.3 No permitir líneas en factura anulada
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (1, 2, 0.00, 0, 1, 0.00);                                 -- esperado: FAIL

-- 4.4 Triggers factura (precio/subtotal + stock + monto_total + pago exacto)
-- Buscar factura emitida
SELECT factura_id
FROM Factura
WHERE estado='emitida'
ORDER BY factura_id
LIMIT 5;

-- Ejemplo: usar factura_id=2 (ajustar si hace falta)
SELECT producto_id, precio, stock FROM Producto WHERE producto_id=3;

INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (2, 3, 0.00, 0, 2, 0.00);                                 -- esperado: OK (si factura 2 emitida)

-- Verificar precio/subtotal calculado
SELECT lf.*, p.precio AS precio_producto
FROM lineaFactura lf
JOIN Producto p ON p.producto_id = lf.id_producto
WHERE lf.id_factura=2 AND lf.id_producto=3;

-- Verificar stock descontado
SELECT producto_id, stock FROM Producto WHERE producto_id=3;

-- Verificar monto_total actualizado
SELECT factura_id, monto_total FROM Factura WHERE factura_id=2;

-- Pago exacto: FAIL si no coincide
INSERT INTO Pago (id_factura, monto, metodo)
VALUES (2, 1.00, 'mercadopago');                                 -- esperado: FAIL

-- Pago exacto: OK
INSERT INTO Pago (id_factura, monto, metodo)
SELECT factura_id, monto_total, 'mercadopago'
FROM Factura
WHERE factura_id=2;                                              -- esperado: OK

-- 4.5 Bloqueo de UPDATE/DELETE en lineaFactura
UPDATE lineaFactura SET cantidad=9 WHERE id_factura=2 AND id_producto=3; -- esperado: FAIL
DELETE FROM lineaFactura WHERE id_factura=2 AND id_producto=3;           -- esperado: FAIL

-- 4.6 VISTAS (admin)
SELECT * FROM v_carritos_activos LIMIT 100;
SELECT * FROM v_catalogo_productos LIMIT 100;
SELECT * FROM v_detalle_carrito LIMIT 200;
SELECT * FROM v_detalle_factura LIMIT 200;
SELECT * FROM v_envios_pendientes LIMIT 200;
SELECT * FROM v_facturas_completas LIMIT 200;
SELECT * FROM v_mis_envios LIMIT 200;
SELECT * FROM v_perfil_usuario LIMIT 200;
SELECT * FROM v_productos_populares LIMIT 200;
SELECT * FROM v_productos_stock LIMIT 200;
SELECT * FROM v_productos_stock_bajo LIMIT 200;
SELECT * FROM v_resenas_productos LIMIT 200;
SELECT * FROM v_usuario_publico LIMIT 200;
SELECT * FROM v_ventas_producto LIMIT 200;
