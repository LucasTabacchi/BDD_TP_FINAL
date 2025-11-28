-- Views
BEGIN;

-- =========================================================
-- VISTAS DE USUARIOS (Ocultar contraseñas)
-- =========================================================

-- Vista: Usuarios sin contraseña (para operadores y clientes)
CREATE OR REPLACE VIEW v_usuario_publico AS
SELECT 
    usuario_id,
    nombre,
    apellido,
    email,
    rol
FROM Usuario;

COMMENT ON VIEW v_usuario_publico IS 
'Vista de usuarios sin información sensible. Oculta la contraseña.';

-- Vista: Perfil de usuario completo (para que el cliente vea su propio perfil)
CREATE OR REPLACE VIEW v_perfil_usuario AS
SELECT 
    u.usuario_id,
    u.nombre,
    u.apellido,
    u.email,
    u.rol,
    COUNT(DISTINCT c.carrito_id) AS total_carritos,
    COUNT(DISTINCT f.factura_id) AS total_facturas,
    COUNT(DISTINCT fav.id_producto) AS total_favoritos,
    COUNT(DISTINCT r.id_producto) AS total_resenas
FROM Usuario u
LEFT JOIN Carrito c ON u.usuario_id = c.id_usuario
LEFT JOIN Factura f ON u.usuario_id = f.id_usuario
LEFT JOIN Favorito fav ON u.usuario_id = fav.id_usuario AND fav.fecha_eliminacion IS NULL
LEFT JOIN Reseña r ON u.usuario_id = r.id_usuario
GROUP BY u.usuario_id, u.nombre, u.apellido, u.email, u.rol;

COMMENT ON VIEW v_perfil_usuario IS 
'Vista con estadísticas del perfil de usuario. Sin contraseña.';

-- =========================================================
-- VISTAS DE PRODUCTOS
-- =========================================================

-- Vista: Catálogo de productos para clientes (con promociones activas)
CREATE OR REPLACE VIEW v_catalogo_productos AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    p.descripcion,
    p.stock,
    -- Precio con descuento (redondeado a 2 decimales)
    CASE 
        WHEN prom.activa = true 
             AND prom.fechaInicio <= CURRENT_DATE 
             AND prom.fechaFin >= CURRENT_DATE 
             AND prom.descuento IS NOT NULL
        THEN ROUND(p.precio * (1 - prom.descuento::NUMERIC / 100), 2)
        ELSE p.precio
    END AS precio_final,
    prom.promocion_id,
    prom.titulo AS promocion_titulo,
    prom.descuento AS promocion_descuento,
    prom.fechaFin AS promocion_fecha_fin,
    ROUND(COALESCE(AVG(r.calificacion), 0), 2) AS calificacion_promedio,
    COUNT(DISTINCT r.id_usuario) AS total_resenas
FROM Producto p
LEFT JOIN Promocion prom ON p.producto_id = prom.id_producto
LEFT JOIN Reseña r ON p.producto_id = r.id_producto
WHERE p.stock > 0
GROUP BY 
    p.producto_id, p.nombre, p.precio, p.descripcion, p.stock,
    prom.promocion_id, prom.titulo, prom.descuento, prom.fechaFin, prom.activa,
    prom.fechaInicio, prom.fechaFin;

COMMENT ON VIEW v_catalogo_productos IS 
'Catálogo de productos con promociones activas y calificaciones. Para clientes.';

-- Vista: Productos con información de stock para operadores
CREATE OR REPLACE VIEW v_productos_stock AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    p.stock,
    p.descripcion,
    -- Total de ingresos
    COALESCE(SUM(ip.cant), 0) AS total_ingresos,
    -- Último ingreso
    MAX(ip.fecha) AS ultimo_ingreso,
    -- Promociones activas
    COUNT(DISTINCT CASE 
        WHEN prom.activa = true 
             AND prom.fechaInicio <= CURRENT_DATE 
             AND prom.fechaFin >= CURRENT_DATE 
        THEN prom.promocion_id 
    END) AS promociones_activas,
    -- Total en carritos activos
    COALESCE(SUM(lc.cantidad), 0) AS cantidad_en_carritos
FROM Producto p
LEFT JOIN ingresoProducto ip ON p.producto_id = ip.id_producto
LEFT JOIN Promocion prom ON p.producto_id = prom.id_producto
LEFT JOIN lineaCarrito lc ON p.producto_id = lc.id_producto
LEFT JOIN Carrito c ON lc.id_carrito = c.carrito_id AND c.estado = 'activo'
GROUP BY p.producto_id, p.nombre, p.precio, p.stock, p.descripcion;

COMMENT ON VIEW v_productos_stock IS 
'Vista de productos con información detallada de stock e ingresos. Para operadores.';

-- Vista: Productos con stock bajo (alerta)
CREATE OR REPLACE VIEW v_productos_stock_bajo AS
SELECT 
    producto_id,
    nombre,
    stock,
    precio,
    CASE 
        WHEN stock = 0 THEN 'Sin stock'
        WHEN stock < 10 THEN 'Stock muy bajo'
        WHEN stock < 50 THEN 'Stock bajo'
    END AS nivel_alerta
FROM Producto
WHERE stock < 50
ORDER BY stock ASC;

COMMENT ON VIEW v_productos_stock_bajo IS 
'Productos con stock bajo o sin stock. Para alertas de inventario.';

-- =========================================================
-- VISTAS DE CARRITOS
-- =========================================================

-- Vista: Carritos activos con información del cliente
CREATE OR REPLACE VIEW v_carritos_activos AS
SELECT 
    c.carrito_id,
    c.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    u.email,
    c.fecha_creacion,
    c.fecha_actualizacion,
    c.total,
    COUNT(lc.id_producto) AS cantidad_productos,
    SUM(lc.cantidad) AS total_items
FROM Carrito c
JOIN Usuario u ON c.id_usuario = u.usuario_id
LEFT JOIN lineaCarrito lc ON c.carrito_id = lc.id_carrito
WHERE c.estado = 'activo'
GROUP BY c.carrito_id, c.id_usuario, u.nombre, u.apellido, u.email, 
         c.fecha_creacion, c.fecha_actualizacion, c.total;

COMMENT ON VIEW v_carritos_activos IS 
'Carritos activos con información del cliente. Para análisis comercial.';

-- Vista: Detalle de carrito con productos
CREATE OR REPLACE VIEW v_detalle_carrito AS
SELECT 
    c.carrito_id,
    c.id_usuario,
    c.estado,
    c.total AS total_carrito,
    lc.id_producto,
    p.nombre AS nombre_producto,
    lc.cantidad,
    lc.precio_unitario,
    lc.subtotal,
    lc.fecha_agregado
FROM Carrito c
JOIN lineaCarrito lc ON c.carrito_id = lc.id_carrito
JOIN Producto p ON lc.id_producto = p.producto_id;

COMMENT ON VIEW v_detalle_carrito IS 
'Detalle completo de carritos con información de productos.';

-- =========================================================
-- VISTAS DE FACTURAS
-- =========================================================

-- Vista: Facturas con información del cliente

CREATE OR REPLACE VIEW v_facturas_completas AS
SELECT 
    f.factura_id,
    f.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    u.email,
    f.fecha,
    f.monto_total,
    -- Cantidad de productos (subconsulta para evitar duplicación)
    COALESCE((
        SELECT COUNT(*)
        FROM lineaFactura lf
        WHERE lf.id_factura = f.factura_id
    ), 0) AS cantidad_productos,
    -- Información de pago (simplificado: solo hay un pago o ninguno)
    COALESCE(p.monto, 0) AS monto_pagado,
    -- Estado de pago: Pagado o Pendiente
    CASE 
        WHEN p.pago_id IS NOT NULL THEN 'Pagado'
        ELSE 'Pendiente'
    END AS estado_pago,
    -- Información del pago
    p.pago_id,
    p.metodo AS metodo_pago,
    -- Información de envío
    e.envio_id,
    e.estado AS estado_envio,
    e.fechaArribo,
    e.fechaEntrega
FROM Factura f
JOIN Usuario u ON f.id_usuario = u.usuario_id
LEFT JOIN Pago p ON f.factura_id = p.id_factura
LEFT JOIN Envio e ON f.factura_id = e.id_factura;

COMMENT ON VIEW v_facturas_completas IS 
'Facturas con información completa: cliente, pagos y envíos. Solo se permiten pagos del monto total completo.';


-- Vista: Detalle de factura con productos
CREATE OR REPLACE VIEW v_detalle_factura AS
SELECT 
    f.factura_id,
    f.id_usuario,
    f.fecha,
    f.monto_total,
    lf.id_producto,
    p.nombre AS nombre_producto,
    lf.cantidad,
    lf.precio_unitario,
    lf.descuento,
    lf.subtotal
FROM Factura f
JOIN lineaFactura lf ON f.factura_id = lf.id_factura
JOIN Producto p ON lf.id_producto = p.producto_id;

COMMENT ON VIEW v_detalle_factura IS 
'Detalle de facturas con información de productos y descuentos.';

-- =========================================================
-- VISTAS DE ENVÍOS
-- =========================================================

-- Vista: Envíos pendientes para logística
CREATE OR REPLACE VIEW v_envios_pendientes AS
SELECT 
    e.envio_id,
    e.estado,
    e.fechaArribo,
    e.fechaEntrega,
    e.costoEnvio,
    f.factura_id,
    f.fecha AS fecha_factura,
    f.monto_total,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    u.email,
    d.calle,
    ci.nombre AS ciudad,
    ci.cp,
    prov.nombre AS provincia
FROM Envio e
JOIN Factura f ON e.id_factura = f.factura_id
JOIN Usuario u ON f.id_usuario = u.usuario_id
JOIN Direccion d ON e.id_direccion = d.direccion_id
JOIN Ciudad ci ON d.id_ciudad = ci.ciudad_id
JOIN Provincia prov ON ci.id_provincia = prov.provincia_id
WHERE e.estado IN ('pendiente', 'enPreparacion', 'enCamino')
ORDER BY 
    CASE e.estado
        WHEN 'pendiente' THEN 1
        WHEN 'enPreparacion' THEN 2
        WHEN 'enCamino' THEN 3
    END,
    f.fecha ASC;

COMMENT ON VIEW v_envios_pendientes IS 
'Envíos pendientes con información completa de cliente y dirección. Para logística.';

-- Vista: Envíos del cliente (sin información sensible de otros)
CREATE OR REPLACE VIEW v_mis_envios AS
SELECT 
    e.envio_id,
    e.estado,
    e.fechaArribo,
    e.fechaEntrega,
    e.costoEnvio,
    f.factura_id,
    f.fecha AS fecha_factura,
    f.monto_total,
    d.calle,
    ci.nombre AS ciudad,
    ci.cp,
    prov.nombre AS provincia
FROM Envio e
JOIN Factura f ON e.id_factura = f.factura_id
JOIN Direccion d ON e.id_direccion = d.direccion_id
JOIN Ciudad ci ON d.id_ciudad = ci.ciudad_id
JOIN Provincia prov ON ci.id_provincia = prov.provincia_id;

COMMENT ON VIEW v_mis_envios IS 
'Envíos del cliente. Usar con RLS para filtrar por usuario.';

-- =========================================================
-- VISTAS DE REPORTES Y ANÁLISIS
-- =========================================================

-- Vista: Ventas por producto
CREATE OR REPLACE VIEW v_ventas_producto AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    COUNT(DISTINCT lf.id_factura) AS total_ventas,
    SUM(lf.cantidad) AS unidades_vendidas,
    SUM(lf.subtotal) AS ingresos_totales,
    ROUND(AVG(lf.precio_unitario), 2) AS precio_promedio
FROM Producto p
JOIN lineaFactura lf ON p.producto_id = lf.id_producto
JOIN Factura f ON lf.id_factura = f.factura_id
GROUP BY p.producto_id, p.nombre, p.precio
ORDER BY ingresos_totales DESC;

COMMENT ON VIEW v_ventas_producto IS 
'Reporte de ventas por producto. Para análisis comercial.';

-- Vista: Reseñas con información del producto
CREATE OR REPLACE VIEW v_resenas_productos AS
SELECT 
    r.id_producto,
    p.nombre AS nombre_producto,
    r.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    r.calificacion,
    r.comentario,
    r.fecha,
    -- Calificación promedio del producto (redondeada a 2 decimales)
    ROUND(AVG(r.calificacion) OVER (PARTITION BY r.id_producto), 2) AS calificacion_promedio
FROM Reseña r
JOIN Producto p ON r.id_producto = p.producto_id
JOIN Usuario u ON r.id_usuario = u.usuario_id
ORDER BY r.fecha DESC;

COMMENT ON VIEW v_resenas_productos IS 
'Reseñas con información del producto y cliente.';

-- Vista: Productos más favoritos
CREATE OR REPLACE VIEW v_productos_populares AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    COUNT(DISTINCT fav.id_usuario) AS total_favoritos,
    COUNT(DISTINCT CASE WHEN fav.fecha_eliminacion IS NULL THEN fav.id_usuario END) AS favoritos_activos
FROM Producto p
LEFT JOIN Favorito fav ON p.producto_id = fav.id_producto
GROUP BY p.producto_id, p.nombre, p.precio
HAVING COUNT(DISTINCT CASE WHEN fav.fecha_eliminacion IS NULL THEN fav.id_usuario END) > 0
ORDER BY favoritos_activos DESC;

COMMENT ON VIEW v_productos_populares IS 
'Productos más agregados a favoritos. Para análisis comercial.';

-- =========================================================
-- OTORGAR PERMISOS EN VISTAS
-- =========================================================

-- Clientes: Solo vistas públicas
GRANT SELECT ON v_usuario_publico TO cliente_app;
GRANT SELECT ON v_perfil_usuario TO cliente_app;
GRANT SELECT ON v_catalogo_productos TO cliente_app;
GRANT SELECT ON v_detalle_carrito TO cliente_app;
GRANT SELECT ON v_detalle_factura TO cliente_app;
GRANT SELECT ON v_mis_envios TO cliente_app;
GRANT SELECT ON v_resenas_productos TO cliente_app;

-- Operador Comercial: Vistas de análisis y productos
GRANT SELECT ON v_usuario_publico TO operador_comercial;
GRANT SELECT ON v_perfil_usuario TO operador_comercial;
GRANT SELECT ON v_catalogo_productos TO operador_comercial;
GRANT SELECT ON v_productos_stock TO operador_comercial;
GRANT SELECT ON v_productos_stock_bajo TO operador_comercial;
GRANT SELECT ON v_carritos_activos TO operador_comercial;
GRANT SELECT ON v_detalle_carrito TO operador_comercial;
GRANT SELECT ON v_facturas_completas TO operador_comercial;
GRANT SELECT ON v_detalle_factura TO operador_comercial;
GRANT SELECT ON v_ventas_producto TO operador_comercial;
GRANT SELECT ON v_resenas_productos TO operador_comercial;
GRANT SELECT ON v_productos_populares TO operador_comercial;

-- Operador Logística: Vistas de stock y envíos
GRANT SELECT ON v_usuario_publico TO operador_logistica;
GRANT SELECT ON v_productos_stock TO operador_logistica;
GRANT SELECT ON v_productos_stock_bajo TO operador_logistica;
GRANT SELECT ON v_envios_pendientes TO operador_logistica;
GRANT SELECT ON v_facturas_completas TO operador_logistica;

-- Administrador: Todas las vistas
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_app;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_app;

COMMIT;