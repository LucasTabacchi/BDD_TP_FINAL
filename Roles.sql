-- =========================================================
-- 1. ADMIN_APP - Administrador de la aplicación
-- =========================================================
-- Permisos: Acceso completo a todas las tablas
-- Responsabilidades: Gestión total del sistema

-- Crear rol si no existe (PostgreSQL)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_app') THEN
        CREATE ROLE admin_app;
    END IF;
END $$;

-- Permisos completos en todas las tablas
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_app;

-- Permisos futuros
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO admin_app;

-- =========================================================
-- 2. OPERADOR_COMERCIAL - Operador comercial
-- =========================================================
-- Permisos: Gestión de productos, promociones, reseñas
-- Responsabilidades: Catálogo, precios, promociones

-- Crear rol si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'operador_comercial') THEN
        CREATE ROLE operador_comercial;
    END IF;
END $$;

-- Tablas maestras de ubicación (solo lectura)
GRANT SELECT ON Provincia TO operador_comercial;
GRANT SELECT ON Ciudad TO operador_comercial;

-- Productos: CRUD completo
GRANT SELECT, INSERT, UPDATE, DELETE ON Producto TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE producto_producto_id_seq TO operador_comercial;

-- Promociones: CRUD completo
GRANT SELECT, INSERT, UPDATE, DELETE ON Promocion TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE promocion_promocion_id_seq TO operador_comercial;

-- Ingresos de producto: Solo lectura (para consultar stock)
GRANT SELECT ON ingresoProducto TO operador_comercial;

-- Reseñas: Lectura y moderación (puede ver pero no eliminar)
GRANT SELECT ON Reseña TO operador_comercial;
-- Nota: Si necesitas que puedan eliminar reseñas inapropiadas, agregar DELETE

-- Usuarios: Solo lectura (para consultas)
GRANT SELECT ON Usuario TO operador_comercial;

-- Carritos: Solo lectura (para análisis)
GRANT SELECT ON Carrito TO operador_comercial;
GRANT SELECT ON lineaCarrito TO operador_comercial;

-- Facturas: Solo lectura (para reportes)
GRANT SELECT ON Factura TO operador_comercial;
GRANT SELECT ON lineaFactura TO operador_comercial;

-- Favoritos: Solo lectura (para análisis)
GRANT SELECT ON Favorito TO operador_comercial;

-- =========================================================
-- 3. OPERADOR_LOGISTICA - Operador de logística
-- =========================================================
-- Permisos: Gestión de stock, ingresos, envíos
-- Responsabilidades: Inventario, recepción de mercadería, envíos

-- Crear rol si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'operador_logistica') THEN
        CREATE ROLE operador_logistica;
    END IF;
END $$;

-- Tablas maestras de ubicación (solo lectura)
GRANT SELECT ON Provincia TO operador_logistica;
GRANT SELECT ON Ciudad TO operador_logistica;

-- Productos: Solo lectura de stock y actualización de stock
-- Nota: Para actualizar solo stock, necesitaríamos una función o vista
GRANT SELECT ON Producto TO operador_logistica;
-- Permitir actualizar solo la columna stock
GRANT UPDATE (stock) ON Producto TO operador_logistica;

-- Ingresos de producto: CRUD completo
GRANT SELECT, INSERT, UPDATE, DELETE ON ingresoProducto TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE ingresoproducto_ingreso_id_seq TO operador_logistica;

-- Envíos: CRUD completo (gestión de estados de envío)
GRANT SELECT, INSERT, UPDATE, DELETE ON Envio TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE envio_envio_id_seq TO operador_logistica;

-- Direcciones: Solo lectura (para ver direcciones de envío)
GRANT SELECT ON Direccion TO operador_logistica;

-- Facturas: Solo lectura (para ver qué facturar)
GRANT SELECT ON Factura TO operador_logistica;
GRANT SELECT ON lineaFactura TO operador_logistica;

-- Usuarios: Solo lectura (para ver datos del cliente)
GRANT SELECT ON Usuario TO operador_logistica;

-- Carritos: Solo lectura (para consultas)
GRANT SELECT ON Carrito TO operador_logistica;
GRANT SELECT ON lineaCarrito TO operador_logistica;

-- =========================================================
-- 4. CLIENTE_APP - Cliente de la aplicación
-- =========================================================
-- Permisos: Solo sus propios datos, carrito, favoritos, reseñas
-- Responsabilidades: Compras, gestión de cuenta

-- Crear rol si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'cliente_app') THEN
        CREATE ROLE cliente_app;
    END IF;
END $$;

-- Tablas maestras de ubicación (solo lectura)
GRANT SELECT ON Provincia TO cliente_app;
GRANT SELECT ON Ciudad TO cliente_app;

-- Usuario: Solo lectura y actualización de sus propios datos
-- Nota: Esto requiere políticas RLS (Row Level Security) o funciones
-- Por ahora, damos permisos limitados
GRANT SELECT, UPDATE ON Usuario TO cliente_app;
-- Restricción: Solo puede actualizar sus propios datos (implementar con RLS o funciones)

-- Direcciones: CRUD solo de sus propias direcciones
GRANT SELECT, INSERT, UPDATE, DELETE ON Direccion TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE direccion_direccion_id_seq TO cliente_app;
-- Restricción: Solo puede gestionar sus propias direcciones (implementar con RLS)

-- Productos: Solo lectura (catálogo)
GRANT SELECT ON Producto TO cliente_app;

-- Promociones: Solo lectura (ver promociones activas)
GRANT SELECT ON Promocion TO cliente_app;

-- Carrito: CRUD solo de sus propios carritos
GRANT SELECT, INSERT, UPDATE, DELETE ON Carrito TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE carrito_carrito_id_seq TO cliente_app;
-- Restricción: Solo puede gestionar sus propios carritos (implementar con RLS)

-- Líneas de carrito: CRUD solo de sus propios carritos
GRANT SELECT, INSERT, UPDATE, DELETE ON lineaCarrito TO cliente_app;
-- Restricción: Solo puede gestionar líneas de sus propios carritos (implementar con RLS)

-- Favoritos: CRUD solo de sus propios favoritos
GRANT SELECT, INSERT, UPDATE, DELETE ON Favorito TO cliente_app;
-- Restricción: Solo puede gestionar sus propios favoritos (implementar con RLS)

-- Reseñas: CRUD solo de sus propias reseñas
GRANT SELECT, INSERT, UPDATE, DELETE ON Reseña TO cliente_app;
-- Restricción: Solo puede gestionar sus propias reseñas (implementar con RLS)

-- Facturas: Solo lectura de sus propias facturas
GRANT SELECT ON Factura TO cliente_app;
GRANT SELECT ON lineaFactura TO cliente_app;
-- Restricción: Solo puede ver sus propias facturas (implementar con RLS)

-- Pagos: Solo lectura de sus propios pagos
GRANT SELECT ON Pago TO cliente_app;
-- Restricción: Solo puede ver sus propios pagos (implementar con RLS)

-- Envíos: Solo lectura de sus propios envíos
GRANT SELECT ON Envio TO cliente_app;

COMMIT;