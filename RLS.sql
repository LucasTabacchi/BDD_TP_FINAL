BEGIN;

-- =========================================================
-- IMPLEMENTACIÓN DE ROW LEVEL SECURITY (RLS)
-- =========================================================
-- Este script implementa RLS para garantizar que:
-- - cliente_app: solo puede acceder a sus propios datos
-- - admin_app: acceso completo a todos los datos
-- - operador_comercial: acceso completo según sus permisos
-- - operador_logistica: acceso completo según sus permisos

-- =========================================================
-- 1. FUNCIÓN PARA OBTENER EL USUARIO ACTUAL
-- =========================================================
-- Esta función obtiene el usuario_id del usuario autenticado
-- desde una variable de sesión que debe establecerse antes de
-- que el cliente realice operaciones.
--
-- Uso: SET app.user_id = '1'; (donde 1 es el usuario_id)
-- La aplicación debe establecer esta variable al autenticar al usuario

CREATE OR REPLACE FUNCTION current_user_id()
RETURNS INTEGER AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    -- Intentar obtener el usuario_id desde la variable de sesión
    BEGIN
        v_user_id := current_setting('app.user_id', true)::INTEGER;
    EXCEPTION
        WHEN OTHERS THEN
            -- Si no se puede obtener, retornar NULL
            -- Esto causará que las políticas RLS rechacen el acceso
            RETURN NULL;
    END;
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION current_user_id() IS 
'Retorna el usuario_id del usuario autenticado desde la variable de sesión app.user_id. Debe establecerse antes de realizar operaciones.';

-- =========================================================
-- 2. HABILITAR RLS EN LAS TABLAS
-- =========================================================
-- El sistema tiene 15 tablas en total:
-- 1. Provincia (tabla maestra - NO tiene RLS)
-- 2. Ciudad (tabla maestra - NO tiene RLS)
-- 3. Usuario (datos personales - SÍ tiene RLS)
-- 4. Direccion (datos personales - SÍ tiene RLS)
-- 5. Producto (catálogo - NO tiene RLS)
-- 6. Promocion (catálogo - NO tiene RLS)
-- 7. ingresoProducto (gestión stock - NO tiene RLS)
-- 8. Carrito (datos personales - SÍ tiene RLS)
-- 9. lineaCarrito (datos personales - SÍ tiene RLS)
-- 10. Favorito (datos personales - SÍ tiene RLS)
-- 11. Reseña (datos personales - SÍ tiene RLS)
-- 12. Factura (datos personales - SÍ tiene RLS)
-- 13. lineaFactura (datos personales - SÍ tiene RLS)
-- 14. Pago (datos personales - SÍ tiene RLS)
-- 15. Envio (datos personales - SÍ tiene RLS)
--
-- RLS está habilitado solo en las 10 tablas que contienen datos personales
-- de clientes (Usuario, Direccion, Carrito, lineaCarrito, Favorito, Reseña,
-- Factura, lineaFactura, Pago, Envio).
--
-- Las tablas maestras (Provincia, Ciudad) y de catálogo (Producto, Promocion,
-- ingresoProducto) NO tienen RLS porque no contienen datos personales.

ALTER TABLE Usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE Direccion ENABLE ROW LEVEL SECURITY;
ALTER TABLE Carrito ENABLE ROW LEVEL SECURITY;
ALTER TABLE lineaCarrito ENABLE ROW LEVEL SECURITY;
ALTER TABLE Favorito ENABLE ROW LEVEL SECURITY;
ALTER TABLE Reseña ENABLE ROW LEVEL SECURITY;
ALTER TABLE Factura ENABLE ROW LEVEL SECURITY;
ALTER TABLE lineaFactura ENABLE ROW LEVEL SECURITY;
ALTER TABLE Pago ENABLE ROW LEVEL SECURITY;
ALTER TABLE Envio ENABLE ROW LEVEL SECURITY;

-- =========================================================
-- 3. POLÍTICAS RLS PARA TABLA Usuario
-- =========================================================

-- Política SELECT: Solo puede ver su propio registro
CREATE POLICY usuario_select_own ON Usuario
    FOR SELECT
    TO cliente_app
    USING (usuario_id = current_user_id());

-- Política UPDATE: Solo puede actualizar su propio registro
-- y no puede modificar el usuario_id ni el rol
CREATE POLICY usuario_update_own ON Usuario
    FOR UPDATE
    TO cliente_app
    USING (usuario_id = current_user_id())
    WITH CHECK (
        usuario_id = current_user_id() 
        AND rol = 'cliente_app'  -- No puede cambiar su rol (debe seguir siendo cliente_app)
    );

COMMENT ON POLICY usuario_select_own ON Usuario IS 
'Permite a los clientes ver solo su propio registro de usuario.';

COMMENT ON POLICY usuario_update_own ON Usuario IS 
'Permite a los clientes actualizar solo su propio registro, sin modificar usuario_id ni rol.';

-- =========================================================
-- 4. POLÍTICAS RLS PARA TABLA Direccion
-- =========================================================

-- Política SELECT: Solo puede ver sus propias direcciones
CREATE POLICY direccion_select_own ON Direccion
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

-- Política INSERT: Solo puede crear direcciones para sí mismo
CREATE POLICY direccion_insert_own ON Direccion
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

-- Política UPDATE: Solo puede actualizar sus propias direcciones
-- y no puede cambiar el id_usuario
CREATE POLICY direccion_update_own ON Direccion
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

-- Política DELETE: Solo puede eliminar sus propias direcciones
CREATE POLICY direccion_delete_own ON Direccion
    FOR DELETE
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY direccion_select_own ON Direccion IS 
'Permite a los clientes ver solo sus propias direcciones.';

COMMENT ON POLICY direccion_insert_own ON Direccion IS 
'Permite a los clientes crear direcciones solo para sí mismos.';

COMMENT ON POLICY direccion_update_own ON Direccion IS 
'Permite a los clientes actualizar solo sus propias direcciones, sin cambiar el id_usuario.';

COMMENT ON POLICY direccion_delete_own ON Direccion IS 
'Permite a los clientes eliminar solo sus propias direcciones.';

-- =========================================================
-- 5. POLÍTICAS RLS PARA TABLA Carrito
-- =========================================================

-- Política SELECT: Solo puede ver sus propios carritos
CREATE POLICY carrito_select_own ON Carrito
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

-- Política INSERT: Solo puede crear carritos para sí mismo
CREATE POLICY carrito_insert_own ON Carrito
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

-- Política UPDATE: Solo puede actualizar sus propios carritos
-- y no puede cambiar el id_usuario
CREATE POLICY carrito_update_own ON Carrito
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

-- Política DELETE: Solo puede eliminar sus propios carritos
CREATE POLICY carrito_delete_own ON Carrito
    FOR DELETE
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY carrito_select_own ON Carrito IS 
'Permite a los clientes ver solo sus propios carritos.';

COMMENT ON POLICY carrito_insert_own ON Carrito IS 
'Permite a los clientes crear carritos solo para sí mismos.';

COMMENT ON POLICY carrito_update_own ON Carrito IS 
'Permite a los clientes actualizar solo sus propios carritos, sin cambiar el id_usuario.';

COMMENT ON POLICY carrito_delete_own ON Carrito IS 
'Permite a los clientes eliminar solo sus propios carritos.';

-- =========================================================
-- 6. POLÍTICAS RLS PARA TABLA lineaCarrito
-- =========================================================

-- Política SELECT: Solo puede ver líneas de sus propios carritos
CREATE POLICY lineacarrito_select_own ON lineaCarrito
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Carrito 
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito 
            AND Carrito.id_usuario = current_user_id()
        )
    );

-- Política INSERT: Solo puede crear líneas en sus propios carritos
CREATE POLICY lineacarrito_insert_own ON lineaCarrito
    FOR INSERT
    TO cliente_app
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM Carrito 
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito 
            AND Carrito.id_usuario = current_user_id()
        )
    );

-- Política UPDATE: Solo puede actualizar líneas de sus propios carritos
-- y no puede cambiar el id_carrito
CREATE POLICY lineacarrito_update_own ON lineaCarrito
    FOR UPDATE
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Carrito 
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito 
            AND Carrito.id_usuario = current_user_id()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM Carrito 
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito 
            AND Carrito.id_usuario = current_user_id()
        )
    );

-- Política DELETE: Solo puede eliminar líneas de sus propios carritos
CREATE POLICY lineacarrito_delete_own ON lineaCarrito
    FOR DELETE
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Carrito 
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito 
            AND Carrito.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY lineacarrito_select_own ON lineaCarrito IS 
'Permite a los clientes ver solo líneas de sus propios carritos.';

COMMENT ON POLICY lineacarrito_insert_own ON lineaCarrito IS 
'Permite a los clientes crear líneas solo en sus propios carritos.';

COMMENT ON POLICY lineacarrito_update_own ON lineaCarrito IS 
'Permite a los clientes actualizar solo líneas de sus propios carritos, sin cambiar el id_carrito.';

COMMENT ON POLICY lineacarrito_delete_own ON lineaCarrito IS 
'Permite a los clientes eliminar solo líneas de sus propios carritos.';

-- =========================================================
-- 7. POLÍTICAS RLS PARA TABLA Favorito
-- =========================================================

-- Política SELECT: Solo puede ver sus propios favoritos
CREATE POLICY favorito_select_own ON Favorito
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

-- Política INSERT: Solo puede crear favoritos para sí mismo
CREATE POLICY favorito_insert_own ON Favorito
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

-- Política UPDATE: Solo puede actualizar sus propios favoritos
-- y no puede cambiar el id_usuario
CREATE POLICY favorito_update_own ON Favorito
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

-- Política DELETE: Solo puede eliminar sus propios favoritos
CREATE POLICY favorito_delete_own ON Favorito
    FOR DELETE
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY favorito_select_own ON Favorito IS 
'Permite a los clientes ver solo sus propios favoritos.';

COMMENT ON POLICY favorito_insert_own ON Favorito IS 
'Permite a los clientes crear favoritos solo para sí mismos.';

COMMENT ON POLICY favorito_update_own ON Favorito IS 
'Permite a los clientes actualizar solo sus propios favoritos, sin cambiar el id_usuario.';

COMMENT ON POLICY favorito_delete_own ON Favorito IS 
'Permite a los clientes eliminar solo sus propios favoritos.';

-- =========================================================
-- 8. POLÍTICAS RLS PARA TABLA Reseña
-- =========================================================

-- Política SELECT: Puede ver todas las reseñas (para ver reseñas de productos)
-- pero solo puede modificar las propias
-- Nota: Esta política permite SELECT de todas las reseñas para que los clientes
-- puedan ver las reseñas de otros usuarios sobre productos
CREATE POLICY reseña_select_all ON Reseña
    FOR SELECT
    TO cliente_app
    USING (true);  -- Permite ver todas las reseñas

-- Política INSERT: Solo puede crear reseñas para sí mismo
CREATE POLICY reseña_insert_own ON Reseña
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

-- Política UPDATE: Solo puede actualizar sus propias reseñas
-- y no puede cambiar el id_usuario
CREATE POLICY reseña_update_own ON Reseña
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

-- Política DELETE: Solo puede eliminar sus propias reseñas
CREATE POLICY reseña_delete_own ON Reseña
    FOR DELETE
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY reseña_select_all ON Reseña IS 
'Permite a los clientes ver todas las reseñas (para ver opiniones de otros usuarios sobre productos).';

COMMENT ON POLICY reseña_insert_own ON Reseña IS 
'Permite a los clientes crear reseñas solo para sí mismos.';

COMMENT ON POLICY reseña_update_own ON Reseña IS 
'Permite a los clientes actualizar solo sus propias reseñas, sin cambiar el id_usuario.';

COMMENT ON POLICY reseña_delete_own ON Reseña IS 
'Permite a los clientes eliminar solo sus propias reseñas.';

-- =========================================================
-- 9. POLÍTICAS RLS PARA TABLA Factura
-- =========================================================

-- Política SELECT: Solo puede ver sus propias facturas
CREATE POLICY factura_select_own ON Factura
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY factura_select_own ON Factura IS 
'Permite a los clientes ver solo sus propias facturas.';

-- Nota: Los clientes no tienen permisos INSERT, UPDATE, DELETE en Factura
-- (solo SELECT), por lo que no se necesitan más políticas

-- =========================================================
-- 10. POLÍTICAS RLS PARA TABLA lineaFactura
-- =========================================================

-- Política SELECT: Solo puede ver líneas de sus propias facturas
CREATE POLICY lineafactura_select_own ON lineaFactura
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Factura 
            WHERE Factura.factura_id = lineaFactura.id_factura 
            AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY lineafactura_select_own ON lineaFactura IS 
'Permite a los clientes ver solo líneas de sus propias facturas.';

-- Nota: Los clientes no tienen permisos INSERT, UPDATE, DELETE en lineaFactura
-- (solo SELECT), por lo que no se necesitan más políticas

-- =========================================================
-- 11. POLÍTICAS RLS PARA TABLA Pago
-- =========================================================

-- Política SELECT: Solo puede ver pagos de sus propias facturas
CREATE POLICY pago_select_own ON Pago
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Factura 
            WHERE Factura.factura_id = Pago.id_factura 
            AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY pago_select_own ON Pago IS 
'Permite a los clientes ver solo pagos de sus propias facturas.';

-- Nota: Los clientes no tienen permisos INSERT, UPDATE, DELETE en Pago
-- (solo SELECT), por lo que no se necesitan más políticas

-- =========================================================
-- 12. POLÍTICAS RLS PARA TABLA Envio
-- =========================================================

-- Política SELECT: Solo puede ver envíos de sus propias facturas
CREATE POLICY envio_select_own ON Envio
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Factura 
            WHERE Factura.factura_id = Envio.id_factura 
            AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY envio_select_own ON Envio IS 
'Permite a los clientes ver solo envíos de sus propias facturas.';

-- Nota: Los clientes no tienen permisos INSERT, UPDATE, DELETE en Envio
-- (solo SELECT), por lo que no se necesitan más políticas

-- =========================================================
-- POLÍTICAS RLS PARA admin_app (ACCESO COMPLETO)
-- =========================================================
-- IMPORTANTE: Cuando RLS está habilitado, PostgreSQL bloquea
-- todos los accesos por defecto, incluso para roles con permisos GRANT.
-- Por eso necesitamos políticas explícitas para admin_app que permitan
-- acceso completo sin restricciones.

-- Política para Usuario
CREATE POLICY usuario_admin_all ON Usuario
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para Direccion
CREATE POLICY direccion_admin_all ON Direccion
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para Carrito
CREATE POLICY carrito_admin_all ON Carrito
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para lineaCarrito
CREATE POLICY lineacarrito_admin_all ON lineaCarrito
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para Favorito
CREATE POLICY favorito_admin_all ON Favorito
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para Reseña
CREATE POLICY reseña_admin_all ON Reseña
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para Factura
CREATE POLICY factura_admin_all ON Factura
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para lineaFactura
CREATE POLICY lineafactura_admin_all ON lineaFactura
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para Pago
CREATE POLICY pago_admin_all ON Pago
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- Política para Envio
CREATE POLICY envio_admin_all ON Envio
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

-- =========================================================
-- POLÍTICAS RLS PARA operador_comercial
-- =========================================================
-- operador_comercial tiene permisos SELECT en varias tablas para análisis
-- y CRUD completo en Producto y Promocion
-- Las políticas permiten acceso según los permisos GRANT

-- Política para Usuario (solo SELECT - para análisis)
CREATE POLICY usuario_operador_comercial_all ON Usuario
    FOR SELECT
    TO operador_comercial
    USING (true);

-- Política para Carrito (solo SELECT - para análisis)
CREATE POLICY carrito_operador_comercial_all ON Carrito
    FOR SELECT
    TO operador_comercial
    USING (true);

-- Política para lineaCarrito (solo SELECT - para análisis)
CREATE POLICY lineacarrito_operador_comercial_all ON lineaCarrito
    FOR SELECT
    TO operador_comercial
    USING (true);

-- Política para Favorito (solo SELECT - para análisis)
CREATE POLICY favorito_operador_comercial_all ON Favorito
    FOR SELECT
    TO operador_comercial
    USING (true);

-- Política para Reseña (solo SELECT - para moderación)
CREATE POLICY reseña_operador_comercial_all ON Reseña
    FOR SELECT
    TO operador_comercial
    USING (true);

-- Política para Factura (solo SELECT - para reportes)
CREATE POLICY factura_operador_comercial_all ON Factura
    FOR SELECT
    TO operador_comercial
    USING (true);

-- Política para lineaFactura (solo SELECT - para reportes)
CREATE POLICY lineafactura_operador_comercial_all ON lineaFactura
    FOR SELECT
    TO operador_comercial
    USING (true);

-- Nota: Producto y Promocion no tienen RLS habilitado (no están en la lista)
-- por lo que operador_comercial puede hacer CRUD completo según sus permisos GRANT

-- =========================================================
-- POLÍTICAS RLS PARA operador_logistica
-- =========================================================
-- operador_logistica tiene permisos SELECT en varias tablas
-- y CRUD completo en Envio e ingresoProducto
-- Las políticas permiten acceso según los permisos GRANT

-- Política para Usuario (solo SELECT - para ver datos de clientes)
CREATE POLICY usuario_operador_logistica_all ON Usuario
    FOR SELECT
    TO operador_logistica
    USING (true);

-- Política para Direccion (solo SELECT - para ver direcciones de envío)
CREATE POLICY direccion_operador_logistica_all ON Direccion
    FOR SELECT
    TO operador_logistica
    USING (true);

-- Política para Carrito (solo SELECT)
CREATE POLICY carrito_operador_logistica_all ON Carrito
    FOR SELECT
    TO operador_logistica
    USING (true);

-- Política para lineaCarrito (solo SELECT)
CREATE POLICY lineacarrito_operador_logistica_all ON lineaCarrito
    FOR SELECT
    TO operador_logistica
    USING (true);

-- Política para Factura (solo SELECT - para ver qué facturar)
CREATE POLICY factura_operador_logistica_all ON Factura
    FOR SELECT
    TO operador_logistica
    USING (true);

-- Política para lineaFactura (solo SELECT)
CREATE POLICY lineafactura_operador_logistica_all ON lineaFactura
    FOR SELECT
    TO operador_logistica
    USING (true);

-- Política para Envio (CRUD completo - gestión de envíos)
CREATE POLICY envio_operador_logistica_all ON Envio
    FOR ALL
    TO operador_logistica
    USING (true)
    WITH CHECK (true);

-- Nota: ingresoProducto y Producto (UPDATE stock) no tienen RLS habilitado
-- por lo que operador_logistica puede hacer CRUD completo según sus permisos GRANT

COMMIT;