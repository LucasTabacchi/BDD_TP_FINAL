-- =========================================================
-- ROLES Y PERMISOS (PostgreSQL) - Versión corregida + permiso anular_factura()
-- =========================================================
-- Nota: el permiso EXECUTE sobre anular_factura se restringe solo a admin_app
--       (se revoca de PUBLIC por seguridad).
--
-- IMPORTANTE: este bloque asume que la función ya existe:
--   CREATE OR REPLACE FUNCTION anular_factura(p_factura_id INT, p_motivo TEXT DEFAULT NULL)

-- =========================================================
-- 1) ADMIN_APP - Administrador de la aplicación
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_app') THEN
        CREATE ROLE admin_app NOLOGIN;
    END IF;
END $$;

GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES    TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO admin_app;

-- =========================================================
-- 2) OPERADOR_COMERCIAL - Catálogo / promociones / análisis
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operador_comercial') THEN
        CREATE ROLE operador_comercial NOLOGIN;
    END IF;
END $$;

GRANT SELECT ON Provincia TO operador_comercial;
GRANT SELECT ON Ciudad    TO operador_comercial;

GRANT SELECT, INSERT, UPDATE, DELETE ON Producto TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE producto_producto_id_seq TO operador_comercial;

GRANT SELECT, INSERT, UPDATE, DELETE ON Promocion TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE promocion_promocion_id_seq TO operador_comercial;

GRANT SELECT ON ingresoProducto TO operador_comercial;
GRANT SELECT ON Reseña          TO operador_comercial;
GRANT SELECT ON Usuario         TO operador_comercial;
GRANT SELECT ON Carrito         TO operador_comercial;
GRANT SELECT ON lineaCarrito    TO operador_comercial;
GRANT SELECT ON Factura         TO operador_comercial;
GRANT SELECT ON lineaFactura    TO operador_comercial;
GRANT SELECT ON Favorito        TO operador_comercial;
GRANT SELECT ON Pago            TO operador_comercial;
GRANT SELECT ON Envio           TO operador_comercial;

-- =========================================================
-- 3) OPERADOR_LOGISTICA - Stock / ingresos / envíos
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operador_logistica') THEN
        CREATE ROLE operador_logistica NOLOGIN;
    END IF;
END $$;

GRANT SELECT ON Provincia TO operador_logistica;
GRANT SELECT ON Ciudad    TO operador_logistica;

GRANT SELECT        ON Producto TO operador_logistica;
GRANT UPDATE(stock) ON Producto TO operador_logistica;

GRANT SELECT, INSERT, UPDATE, DELETE ON ingresoProducto TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE ingresoproducto_ingreso_id_seq TO operador_logistica;

GRANT SELECT, INSERT, UPDATE, DELETE ON Envio TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE envio_envio_id_seq TO operador_logistica;

GRANT SELECT ON Direccion   TO operador_logistica;
GRANT SELECT ON Factura     TO operador_logistica;
GRANT SELECT ON lineaFactura TO operador_logistica;
GRANT SELECT ON Usuario     TO operador_logistica;
GRANT SELECT ON Carrito     TO operador_logistica;
GRANT SELECT ON lineaCarrito TO operador_logistica;
GRANT SELECT ON Producto TO operador_logistica;
GRANT UPDATE (stock) ON Producto TO operador_logistica;
GRANT SELECT ON v_detalle_factura TO operador_logistica;
GRANT SELECT ON Factura, Usuario, Pago, Envio TO operador_logistica;
GRANT SELECT ON Direccion, Ciudad, Provincia TO operador_logistica;
GRANT SELECT ON lineaFactura TO operador_logistica;

-- =========================================================
-- 4) CLIENTE_APP - Cliente de la aplicación
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cliente_app') THEN
        CREATE ROLE cliente_app NOLOGIN;
    END IF;
END $$;

GRANT SELECT ON Provincia TO cliente_app;
GRANT SELECT ON Ciudad    TO cliente_app;

GRANT SELECT, UPDATE ON Usuario TO cliente_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON Direccion TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE direccion_direccion_id_seq TO cliente_app;

GRANT SELECT ON Producto  TO cliente_app;
GRANT SELECT ON Promocion TO cliente_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON Carrito TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE carrito_carrito_id_seq TO cliente_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON lineaCarrito TO cliente_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON Favorito    TO cliente_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON Reseña      TO cliente_app;

GRANT SELECT ON Factura      TO cliente_app;
GRANT SELECT ON lineaFactura TO cliente_app;

GRANT SELECT ON Pago  TO cliente_app;
GRANT SELECT ON Envio TO cliente_app;


-- PERMISOS ESPECÍFICOS PARA FUNCIÓN DE NEGOCIO: anular_factura()
-- Seguridad: por defecto, cualquiera podría ejecutar funciones si tiene USAGE/EXECUTE heredado.
-- Restringimos explícitamente esta función: solo admin_app puede anular facturas.

REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM cliente_app;
REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM operador_comercial;
REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM operador_logistica;

GRANT EXECUTE ON FUNCTION anular_factura(INT, TEXT) TO admin_app;



