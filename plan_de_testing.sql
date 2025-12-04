--- PRUEBAS TRIGGERS

--1) ACTUALIZAR STOCK INGRESO
INSERT INTO ingresoProducto (id_producto, fecha, cant) VALUES (1, CURRENT_DATE, 10);
SELECT stock FROM Producto WHERE producto_id = 1;

--2) CALCULAR SUBTOTAL CARRITO
INSERT INTO lineaCarrito (id_carrito, id_producto, cantidad, precio_unitario, subtotal)
VALUES (1, 3, 3, 200.00, 0); --200.00 X 3 = 600.00
SELECT subtotal FROM lineaCarrito WHERE id_carrito = 1 AND id_producto = 3;

UPDATE lineaCarrito  -- calcular subtotal
SET cantidad = 5
WHERE id_carrito = 1 AND id_producto = 3; -- ahora 5 X 200.00 = 1000.00

SELECT subtotal FROM lineaCarrito WHERE id_carrito = 1 AND id_producto = 3;

-- 3) VALIDAR CARRITO ACTIVO (FALLA)
INSERT INTO lineaCarrito (id_carrito, id_producto, cantidad, precio_unitario, subtotal)
VALUES (15, 1, 1, 200.000, 0);

-- 4) VALIDAR STOCK CARRITO (FALLA)
INSERT INTO lineaCarrito (id_carrito, id_producto, cantidad, precio_unitario, subtotal)
VALUES (1, 4, 10000, 250.00, 0);

-- 5) ACTUALIZAR TOTAL CARRITO
UPDATE lineaCarrito
SET cantidad = 6
WHERE id_carrito = 1 AND id_producto = 2; -- ahora 150.00 X 6 = 90000
SELECT total, fecha_actualizacion FROM Carrito WHERE carrito_id = 1; --antes 1100.00, ahora 2100.00

-- 6) CALCULAR SUBTOTAL FACTURA
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (1, 2, 150.00, 10, 5, 0); -- antes 200.00, ahora (200 + 675=875.00). Actualiza monto_total factura

UPDATE lineaFactura  -- calcular subtotal y actualiza stock
SET cantidad = 8
WHERE id_factura = 1 AND id_producto = 2; -- antes 200.00, ahora (200 + 1080=1280.00)

SELECT subtotal FROM lineaFactura WHERE id_factura = 1 AND id_producto = 2;

-- 7) VALIDAR STOCK FACTURA (FALLA)
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (1, 3, 200.00, NULL, 30000, 0);


-- 8) REDUCIR STOCK FACTURA
SELECT stock FROM Producto WHERE producto_id = 3; -- antes 1099
-- luego insertás:
UPDATE lineaFactura 
SET cantidad = 3
WHERE id_factura = 9 AND id_producto = 9; 
SELECT stock FROM Producto WHERE producto_id = 9;  -- ahora 1096

-- 9) RESTAURAR STOCK FACTURA
SELECT stock FROM Producto WHERE producto_id = 5; -- acá 1098

INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (6, 5, 300.00, NULL, 5, 0);

SELECT stock FROM Producto WHERE producto_id = 5;  -- acá 1093

DELETE FROM lineaFactura
WHERE id_factura = 6 AND id_producto = 5;

SELECT stock FROM Producto WHERE producto_id = 5;  -- acá 1098

-- 10) CALCULAR MONTO TOTAL FACTURA
SELECT monto_total FROM factura WHERE factura_id = 7; -- acá 1200

INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal)
VALUES (7, 8, 450.00, 5, 2, 0); -- 427.5 X 2 = 855.00

SELECT monto_total FROM factura WHERE factura_id = 7; -- ahora 2055.00

-- 11) VALIDAR PAGO TOTAL FACTURA
-- FALLA: monto menor al monto_total
INSERT INTO pago (id_factura, monto, metodo) VALUES
(15, 1000.00, 'mercadopago');

-- CORRECTO: monto igual al monto_total
INSERT INTO pago (id_factura, monto, metodo) VALUES
(15, 2040.00, 'mercadopago');

--12) VALIDAR TRANSICION ESTADO ENVIO (FALLA)

UPDATE Envio
SET estado = 'enPreparacion'
WHERE envio_id = 9;

UPDATE Envio
SET estado = 'enCamino'
WHERE envio_id = 9;

UPDATE Envio
SET estado = 'entregado'
WHERE envio_id = 9;

UPDATE Envio
SET estado = 'enCamino' 
WHERE envio_id = 9; -- falla, el envío ya fue entregado

-- 13) un usuario puede tener solo un carrito activo (FALLA)
INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total) VALUES
(1, '2025-11-17', '2025-11-17', 'activo',  0)


-- VIEWS TESTING

SELECT * FROM v_carritos_activos;

SELECT * FROM v_catalogo_productos;

SELECT * FROM v_detalle_carrito;

SELECT * FROM v_detalle_factura WHERE factura_id = 1;

SELECT * FROM v_envios_pendientes;

SELECT * FROM v_facturas_completas;

SELECT * FROM v_mis_envios WHERE envio_id = 1;

SELECT * FROM v_perfil_usuario WHERE usuario_id = 1;

SELECT * FROM v_productos_populares;

SELECT * FROM v_productos_stock;

SELECT * FROM v_productos_stock_bajo;

SELECT * FROM v_resenas_productos WHERE id_producto = 1;

SELECT * FROM v_usuario_publico WHERE usuario_id = 3;

SELECT * FROM v_ventas_producto;

-- PRUEBAS ROLES Y PERMISOS
BEGIN;

CREATE USER ana_perez      PASSWORD 'Password1';   -- cliente_app
CREATE USER fernando_rossi PASSWORD 'Password6';   -- operador_comercial
CREATE USER hernan_torres  PASSWORD 'Password8';   -- operador_logistica
CREATE USER julian_diaz    PASSWORD 'Password10';  -- admin_app

-- Asignar roles a los usuarios
GRANT admin_app         TO julian_diaz;
GRANT operador_comercial TO fernando_rossi;
GRANT operador_logistica TO hernan_torres;
GRANT cliente_app        TO ana_perez;

COMMIT;

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
INSERT INTO FACTURA (id_usuario, monto_total) VALUES
(10, 5000.00);

DELETE FROM Factura
WHERE factura_id = 16;  -- si existe

-- Insertar envío
INSERT INTO Envio (id_direccion, id_factura, estado, costoEnvio)
VALUES (1, 16, 'pendiente', 1000.00);


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
VALUES (18, CURRENT_DATE, CURRENT_DATE + 10, 'Promo test', 'desc', 10, TRUE);

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
INSERT INTO ingresoProducto (id_producto, cant)
VALUES (5, 20);

UPDATE ingresoProducto
SET cant = 30
WHERE ingreso_id = 19;  -- ajustá a un id real

-- DELETE FROM ingresoProducto
-- WHERE ingreso_id = 1;  -- ajustá a un id real

-- 5) CRUD de Envio
INSERT INTO FACTURA (id_usuario, monto_total) VALUES
(2, 100000.00);

INSERT INTO Envio (id_direccion, id_factura, estado, costoEnvio)
VALUES (1, 18, 'pendiente', 1500.00);

select envio_id from envio where id_factura = 18;

UPDATE Envio
SET estado = 'enCamino'
WHERE envio_id = 17;    -- ajustá a un id real

DELETE FROM Envio
WHERE envio_id = 17;    -- ajustá a un id real

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

select direccion_id from Direccion where calle = 'Direccion cliente_app';

-- 3) Actualizar una dirección
UPDATE Direccion
SET calle = 'Direccion cliente_app MODIFICADA'
WHERE direccion_id = 17;  -- ajustá a un id que exista

-- 4) Crear un carrito
INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total)
VALUES (6, CURRENT_DATE, CURRENT_DATE, 'cerrado', 0);

-- 5) Insertar línea de carrito
INSERT INTO lineaCarrito (id_carrito, id_producto, cantidad, precio_unitario, subtotal)
VALUES (5, 1, 7, 100.00, 0);

-- 6) Crear favorito
INSERT INTO Favorito (id_usuario, id_producto, fecha_creacion)
VALUES (2, 10, CURRENT_DATE);

-- 7) Crear reseña
INSERT INTO Reseña (id_usuario, id_producto, calificacion, comentario, fecha)
VALUES (10, 1, 5, 'Muy bueno', CURRENT_DATE);

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


--- PRUEBAS RLS

-- =========================================================
-- PASO 1: Verificar correspondencia entre usuarios PostgreSQL y tabla Usuario
-- =========================================================

SELECT '========================================' AS separador;
SELECT 'VERIFICACIÓN DE USUARIOS' AS titulo;
SELECT '========================================' AS separador;

-- Verificar que existe Ana Pérez en la tabla Usuario
SELECT 
    usuario_id,
    nombre,
    apellido,
    email,
    rol
FROM Usuario
WHERE nombre = 'Ana' AND apellido = 'Pérez'
   OR email LIKE '%ana%'
ORDER BY usuario_id;

-- Mostrar todos los usuarios cliente_app disponibles
SELECT 
    usuario_id,
    nombre || ' ' || apellido AS nombre_completo,
    email,
    rol
FROM Usuario
WHERE rol = 'cliente_app'
ORDER BY usuario_id;

-- =========================================================
-- PASO 2: PRUEBA CON ana_perez (usuario_id = 1)
-- =========================================================

SELECT '========================================' AS separador;
SELECT 'PRUEBA 1: ana_perez (usuario_id = 1)' AS titulo;
SELECT '========================================' AS separador;

-- Establecer el usuario_id en la variable de sesión
-- IMPORTANTE: Esto debe hacerse ANTES de cambiar al rol cliente_app
SET app.user_id = '1';

-- Cambiar al rol cliente_app
SET ROLE cliente_app;

-- Verificar que puede ver su propio usuario
SELECT 'PRUEBA 1.1: Ver su propio usuario' AS prueba;
SELECT usuario_id, nombre, apellido, email, rol 
FROM Usuario 
WHERE usuario_id = 1;
-- Debe retornar 1 fila

-- Verificar que NO puede ver otros usuarios
SELECT 'PRUEBA 1.2: Intentar ver otro usuario (debe estar bloqueado por RLS)' AS prueba;
SELECT usuario_id, nombre, apellido, email 
FROM Usuario 
WHERE usuario_id = 2;
-- Debe retornar 0 filas (RLS bloquea)

-- Verificar que puede ver sus propias direcciones
SELECT 'PRUEBA 1.3: Ver sus propias direcciones' AS prueba;
SELECT direccion_id, id_usuario, calle 
FROM Direccion 
WHERE id_usuario = 1;
-- Debe retornar solo direcciones del usuario 1

-- Verificar que NO puede ver direcciones de otros usuarios
SELECT 'PRUEBA 1.4: Intentar ver direcciones de otro usuario (debe estar bloqueado)' AS prueba;
SELECT direccion_id, id_usuario, calle 
FROM Direccion 
WHERE id_usuario = 2;
-- Debe retornar 0 filas (RLS bloquea)

-- Verificar que puede ver sus propias facturas
SELECT 'PRUEBA 1.5: Ver sus propias facturas' AS prueba;
SELECT factura_id, id_usuario, fecha, monto_total 
FROM Factura 
WHERE id_usuario = 1;
-- Debe retornar solo facturas del usuario 1

-- Verificar que NO puede ver facturas de otros usuarios
SELECT 'PRUEBA 1.6: Intentar ver facturas de otro usuario (debe estar bloqueado)' AS prueba;
SELECT factura_id, id_usuario, fecha, monto_total 
FROM Factura 
WHERE id_usuario = 2;
-- Debe retornar 0 filas (RLS bloquea)

-- Verificar que puede ver todas las reseñas (política especial)
SELECT 'PRUEBA 1.7: Ver todas las reseñas (política permite ver todas)' AS prueba;
SELECT COUNT(*) AS total_resenas FROM Reseña;
-- Debe retornar todas las reseñas

-- Intentar crear una dirección para sí mismo (debe funcionar)
SELECT 'PRUEBA 1.8: Crear dirección para sí mismo' AS prueba;
DO $$
DECLARE
    v_ciudad_id INTEGER;
BEGIN
    -- Obtener una ciudad existente
    SELECT MIN(ciudad_id) INTO v_ciudad_id FROM Ciudad;
    
    IF v_ciudad_id IS NOT NULL THEN
        INSERT INTO Direccion (id_usuario, id_ciudad, calle)
        VALUES (1, v_ciudad_id, 'Calle de Prueba RLS - Ana Pérez')
        ON CONFLICT DO NOTHING;
        
        RAISE NOTICE 'ÉXITO: Dirección creada correctamente';
    ELSE
        RAISE NOTICE 'ADVERTENCIA: No hay ciudades disponibles para la prueba';
    END IF;
END $$;

-- Verificar que la dirección se creó
SELECT direccion_id, id_usuario, calle 
FROM Direccion 
WHERE calle = 'Calle de Prueba RLS - Ana Pérez';

-- Intentar crear una dirección para otro usuario (debe fallar)
SELECT 'PRUEBA 1.9: Intentar crear dirección para otro usuario (debe fallar)' AS prueba;
DO $$
DECLARE
    v_ciudad_id INTEGER;
BEGIN
    -- Obtener una ciudad existente
    SELECT MIN(ciudad_id) INTO v_ciudad_id FROM Ciudad;
    
    IF v_ciudad_id IS NOT NULL THEN
        BEGIN
            INSERT INTO Direccion (id_usuario, id_ciudad, calle)
            VALUES (2, v_ciudad_id, 'Calle Hackeada - No debería funcionar');
            
            RAISE NOTICE 'ERROR: La inserción debería haber fallado';
        EXCEPTION
            WHEN insufficient_privilege THEN
                RAISE NOTICE 'ÉXITO: RLS bloqueó correctamente la inserción';
            WHEN OTHERS THEN
                RAISE NOTICE 'ERROR: %', SQLERRM;
        END;
    END IF;
END $$;

-- Volver al rol original
RESET ROLE;

-- =========================================================
-- PASO 3: PRUEBA CON OTRO CLIENTE (si existe)
-- =========================================================

-- Buscar otro usuario cliente_app
DO $$
DECLARE
    v_otro_usuario_id INTEGER;
    v_otro_nombre TEXT;
BEGIN
    -- Buscar otro cliente_app (diferente de usuario_id = 1)
    SELECT usuario_id, nombre || ' ' || apellido
    INTO v_otro_usuario_id, v_otro_nombre
    FROM Usuario
    WHERE rol = 'cliente_app' AND usuario_id != 1
    LIMIT 1;
    
    IF v_otro_usuario_id IS NOT NULL THEN
        RAISE NOTICE '========================================';
        RAISE NOTICE 'PRUEBA 2: Otro cliente (usuario_id = %)', v_otro_usuario_id;
        RAISE NOTICE '========================================';
        
        -- Establecer el usuario_id del otro cliente
        EXECUTE format('SET app.user_id = %s', v_otro_usuario_id);
        SET ROLE cliente_app;
        
        -- Verificar que solo ve sus propios datos
        RAISE NOTICE 'Verificando que solo ve sus propios datos...';
        
        -- Verificar que NO puede ver datos del usuario 1
        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE usuario_id = 1) THEN
            RAISE NOTICE 'ÉXITO: No puede ver datos del usuario 1 (RLS funciona)';
        ELSE
            RAISE NOTICE 'ERROR: Puede ver datos del usuario 1 (RLS no funciona)';
        END IF;
        
        -- Verificar que puede ver sus propios datos
        IF EXISTS (SELECT 1 FROM Usuario WHERE usuario_id = v_otro_usuario_id) THEN
            RAISE NOTICE 'ÉXITO: Puede ver sus propios datos';
        ELSE
            RAISE NOTICE 'ERROR: No puede ver sus propios datos';
        END IF;
        
        RESET ROLE;
    ELSE
        RAISE NOTICE 'No se encontró otro usuario cliente_app para la prueba';
    END IF;
END $$;

-- =========================================================
-- PASO 4: VERIFICAR QUE ADMIN NO ESTÁ AFECTADO POR RLS
-- =========================================================

-- Cambiar a admin_app
SET ROLE admin_app;

-- Verificar que puede ver todos los usuarios
SELECT 'PRUEBA 3.1: Admin puede ver todos los usuarios' AS prueba;
SELECT COUNT(*) AS total_usuarios FROM usuario;
-- Debe retornar todos los usuarios

-- Verificar que puede ver todas las facturas
SELECT 'PRUEBA 3.2: Admin puede ver todas las facturas' AS prueba;
SELECT COUNT(*) AS total_facturas FROM Factura;
-- Debe retornar todas las facturas

-- Eliminar la dirección de prueba creada
DELETE FROM Direccion WHERE calle = 'Calle de Prueba RLS - Ana Pérez';

set role postgres;  -- volver a superusuario