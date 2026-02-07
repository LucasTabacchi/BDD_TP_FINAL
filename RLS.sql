BEGIN;

-- =========================================================
-- IMPLEMENTACIÓN DE ROW LEVEL SECURITY (RLS)
-- =========================================================
-- Este script implementa RLS para garantizar que:
-- - cliente_app: solo puede acceder a sus propios datos
-- - admin_app: acceso completo a todos los datos
-- - operador_comercial: acceso según sus permisos (principalmente SELECT)
-- - operador_logistica: acceso según sus permisos (SELECT y CRUD donde aplique)
--
-- =========================================================
-- ACLARACIÓN SOBRE POLICIES (para el informe)
-- =========================================================
-- En PostgreSQL, cuando una tabla tiene RLS habilitado, los permisos GRANT por sí solos
-- NO alcanzan: el motor aplica además las POLICIES como filtros por fila.
--
-- La variable de sesión:
--   SET app.user_id = '123';
-- La función current_user_id() lee esa variable.
-- =========================================================


-- =========================================================
-- 1. FUNCIÓN PARA OBTENER EL USUARIO ACTUAL
-- =========================================================
-- CAMBIO:
-- - Quitado SECURITY DEFINER (no hace falta y puede ser riesgoso/confuso con RLS).
-- - Manejo explícito: si falta o es inválido, devuelve NULL (comportamiento seguro).
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_text text;
    v_user_id integer;
BEGIN
    v_text := current_setting('app.user_id', true);

    IF v_text IS NULL OR btrim(v_text) = '' THEN
        RETURN NULL;
    END IF;

    BEGIN
        v_user_id := v_text::integer;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN NULL;
    END;

    RETURN v_user_id;
END;
$$;

COMMENT ON FUNCTION current_user_id() IS
'Retorna el usuario_id del usuario autenticado desde la variable de sesión app.user_id. Debe establecerse antes de realizar operaciones. Si no está seteada o es inválida, retorna NULL (bloqueo seguro).';


-- =========================================================
-- 2. HABILITAR RLS EN LAS TABLAS CON DATOS PERSONALES
-- =========================================================
ALTER TABLE Usuario      ENABLE ROW LEVEL SECURITY;
ALTER TABLE Direccion    ENABLE ROW LEVEL SECURITY;
ALTER TABLE Carrito      ENABLE ROW LEVEL SECURITY;
ALTER TABLE lineaCarrito ENABLE ROW LEVEL SECURITY;
ALTER TABLE Favorito     ENABLE ROW LEVEL SECURITY;
ALTER TABLE Reseña       ENABLE ROW LEVEL SECURITY;
ALTER TABLE Factura      ENABLE ROW LEVEL SECURITY;
ALTER TABLE lineaFactura ENABLE ROW LEVEL SECURITY;
ALTER TABLE Pago         ENABLE ROW LEVEL SECURITY;
ALTER TABLE Envio        ENABLE ROW LEVEL SECURITY;


-- =========================================================
-- 3. POLÍTICAS RLS PARA TABLA Usuario
-- =========================================================
-- CAMBIO: hacerlo idempotente
DROP POLICY IF EXISTS usuario_select_own ON Usuario;
DROP POLICY IF EXISTS usuario_update_own ON Usuario;

CREATE POLICY usuario_select_own ON Usuario
    FOR SELECT
    TO cliente_app
    USING (usuario_id = current_user_id());

CREATE POLICY usuario_update_own ON Usuario
    FOR UPDATE
    TO cliente_app
    USING (usuario_id = current_user_id())
    WITH CHECK (
        usuario_id = current_user_id()
        AND rol = 'cliente_app'
    );

COMMENT ON POLICY usuario_select_own ON Usuario IS
'Permite a los clientes ver solo su propio registro de usuario.';

COMMENT ON POLICY usuario_update_own ON Usuario IS
'Permite a los clientes actualizar solo su propio registro, sin modificar usuario_id ni rol.';


-- =========================================================
-- 4. POLÍTICAS RLS PARA TABLA Direccion
-- =========================================================
DROP POLICY IF EXISTS direccion_select_own ON Direccion;
DROP POLICY IF EXISTS direccion_insert_own ON Direccion;
DROP POLICY IF EXISTS direccion_update_own ON Direccion;
DROP POLICY IF EXISTS direccion_delete_own ON Direccion;

CREATE POLICY direccion_select_own ON Direccion
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

CREATE POLICY direccion_insert_own ON Direccion
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

CREATE POLICY direccion_update_own ON Direccion
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

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
DROP POLICY IF EXISTS carrito_select_own ON Carrito;
DROP POLICY IF EXISTS carrito_insert_own ON Carrito;
DROP POLICY IF EXISTS carrito_update_own ON Carrito;
DROP POLICY IF EXISTS carrito_delete_own ON Carrito;

CREATE POLICY carrito_select_own ON Carrito
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

CREATE POLICY carrito_insert_own ON Carrito
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

CREATE POLICY carrito_update_own ON Carrito
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

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
DROP POLICY IF EXISTS lineacarrito_select_own ON lineaCarrito;
DROP POLICY IF EXISTS lineacarrito_insert_own ON lineaCarrito;
DROP POLICY IF EXISTS lineacarrito_update_own ON lineaCarrito;
DROP POLICY IF EXISTS lineacarrito_delete_own ON lineaCarrito;

CREATE POLICY lineacarrito_select_own ON lineaCarrito
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1
            FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    );

CREATE POLICY lineacarrito_insert_own ON lineaCarrito
    FOR INSERT
    TO cliente_app
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    );

CREATE POLICY lineacarrito_update_own ON lineaCarrito
    FOR UPDATE
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1
            FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    );

CREATE POLICY lineacarrito_delete_own ON lineaCarrito
    FOR DELETE
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1
            FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY lineacarrito_select_own ON lineaCarrito IS
'Permite a los clientes ver solo líneas de sus propios carritos.';

COMMENT ON POLICY lineacarrito_insert_own ON lineaCarrito IS
'Permite a los clientes crear líneas solo en sus propios carritos.';

COMMENT ON POLICY lineacarrito_update_own ON lineaCarrito IS
'Permite a los clientes actualizar solo líneas de sus propios carritos (sin cambiar la pertenencia).';

COMMENT ON POLICY lineacarrito_delete_own ON lineaCarrito IS
'Permite a los clientes eliminar solo líneas de sus propios carritos.';


-- =========================================================
-- 7. POLÍTICAS RLS PARA TABLA Favorito
-- =========================================================
DROP POLICY IF EXISTS favorito_select_own ON Favorito;
DROP POLICY IF EXISTS favorito_insert_own ON Favorito;
DROP POLICY IF EXISTS favorito_update_own ON Favorito;
DROP POLICY IF EXISTS favorito_delete_own ON Favorito;

CREATE POLICY favorito_select_own ON Favorito
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

CREATE POLICY favorito_insert_own ON Favorito
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

CREATE POLICY favorito_update_own ON Favorito
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

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
DROP POLICY IF EXISTS reseña_select_all ON Reseña;
DROP POLICY IF EXISTS reseña_insert_own ON Reseña;
DROP POLICY IF EXISTS reseña_update_own ON Reseña;
DROP POLICY IF EXISTS reseña_delete_own ON Reseña;

CREATE POLICY reseña_select_all ON Reseña
    FOR SELECT
    TO cliente_app
    USING (true);

CREATE POLICY reseña_insert_own ON Reseña
    FOR INSERT
    TO cliente_app
    WITH CHECK (id_usuario = current_user_id());

CREATE POLICY reseña_update_own ON Reseña
    FOR UPDATE
    TO cliente_app
    USING (id_usuario = current_user_id())
    WITH CHECK (id_usuario = current_user_id());

CREATE POLICY reseña_delete_own ON Reseña
    FOR DELETE
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY reseña_select_all ON Reseña IS
'Permite a los clientes ver todas las reseñas (opiniones por producto).';

COMMENT ON POLICY reseña_insert_own ON Reseña IS
'Permite a los clientes crear reseñas solo para sí mismos.';

COMMENT ON POLICY reseña_update_own ON Reseña IS
'Permite a los clientes actualizar solo sus propias reseñas.';

COMMENT ON POLICY reseña_delete_own ON Reseña IS
'Permite a los clientes eliminar solo sus propias reseñas.';


-- =========================================================
-- 9. POLÍTICAS RLS PARA TABLA Factura
-- =========================================================
DROP POLICY IF EXISTS factura_select_own ON Factura;

CREATE POLICY factura_select_own ON Factura
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY factura_select_own ON Factura IS
'Permite a los clientes ver solo sus propias facturas.';


-- =========================================================
-- 10. POLÍTICAS RLS PARA TABLA lineaFactura
-- =========================================================
DROP POLICY IF EXISTS lineafactura_select_own ON lineaFactura;

CREATE POLICY lineafactura_select_own ON lineaFactura
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1
            FROM Factura
            WHERE Factura.factura_id = lineaFactura.id_factura
              AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY lineafactura_select_own ON lineaFactura IS
'Permite a los clientes ver solo líneas de sus propias facturas.';


-- =========================================================
-- 11. POLÍTICAS RLS PARA TABLA Pago
-- =========================================================
DROP POLICY IF EXISTS pago_select_own ON Pago;

CREATE POLICY pago_select_own ON Pago
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1
            FROM Factura
            WHERE Factura.factura_id = Pago.id_factura
              AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY pago_select_own ON Pago IS
'Permite a los clientes ver solo pagos de sus propias facturas.';


-- =========================================================
-- 12. POLÍTICAS RLS PARA TABLA Envio
-- =========================================================
DROP POLICY IF EXISTS envio_select_own ON Envio;

CREATE POLICY envio_select_own ON Envio
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1
            FROM Factura
            WHERE Factura.factura_id = Envio.id_factura
              AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY envio_select_own ON Envio IS
'Permite a los clientes ver solo envíos de sus propias facturas.';


-- =========================================================
-- POLÍTICAS RLS PARA admin_app (ACCESO COMPLETO)
-- =========================================================
DROP POLICY IF EXISTS usuario_admin_all ON Usuario;
DROP POLICY IF EXISTS direccion_admin_all ON Direccion;
DROP POLICY IF EXISTS carrito_admin_all ON Carrito;
DROP POLICY IF EXISTS lineacarrito_admin_all ON lineaCarrito;
DROP POLICY IF EXISTS favorito_admin_all ON Favorito;
DROP POLICY IF EXISTS reseña_admin_all ON Reseña;
DROP POLICY IF EXISTS factura_admin_all ON Factura;
DROP POLICY IF EXISTS lineafactura_admin_all ON lineaFactura;
DROP POLICY IF EXISTS pago_admin_all ON Pago;
DROP POLICY IF EXISTS envio_admin_all ON Envio;

CREATE POLICY usuario_admin_all ON Usuario
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY direccion_admin_all ON Direccion
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY carrito_admin_all ON Carrito
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY lineacarrito_admin_all ON lineaCarrito
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY favorito_admin_all ON Favorito
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY reseña_admin_all ON Reseña
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY factura_admin_all ON Factura
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY lineafactura_admin_all ON lineaFactura
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY pago_admin_all ON Pago
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);

CREATE POLICY envio_admin_all ON Envio
    FOR ALL
    TO admin_app
    USING (true)
    WITH CHECK (true);


-- =========================================================
-- POLÍTICAS RLS PARA operador_comercial (SELECT en tablas con RLS)
-- =========================================================
DROP POLICY IF EXISTS usuario_operador_comercial_all ON Usuario;
DROP POLICY IF EXISTS carrito_operador_comercial_all ON Carrito;
DROP POLICY IF EXISTS lineacarrito_operador_comercial_all ON lineaCarrito;
DROP POLICY IF EXISTS favorito_operador_comercial_all ON Favorito;
DROP POLICY IF EXISTS reseña_operador_comercial_all ON Reseña;
DROP POLICY IF EXISTS factura_operador_comercial_all ON Factura;
DROP POLICY IF EXISTS lineafactura_operador_comercial_all ON lineaFactura;

CREATE POLICY usuario_operador_comercial_all ON Usuario
    FOR SELECT
    TO operador_comercial
    USING (true);

CREATE POLICY carrito_operador_comercial_all ON Carrito
    FOR SELECT
    TO operador_comercial
    USING (true);

CREATE POLICY lineacarrito_operador_comercial_all ON lineaCarrito
    FOR SELECT
    TO operador_comercial
    USING (true);

CREATE POLICY favorito_operador_comercial_all ON Favorito
    FOR SELECT
    TO operador_comercial
    USING (true);

CREATE POLICY reseña_operador_comercial_all ON Reseña
    FOR SELECT
    TO operador_comercial
    USING (true);

CREATE POLICY factura_operador_comercial_all ON Factura
    FOR SELECT
    TO operador_comercial
    USING (true);

CREATE POLICY lineafactura_operador_comercial_all ON lineaFactura
    FOR SELECT
    TO operador_comercial
    USING (true);


-- =========================================================
-- POLÍTICAS RLS PARA operador_logistica
-- =========================================================
DROP POLICY IF EXISTS usuario_operador_logistica_all ON Usuario;
DROP POLICY IF EXISTS direccion_operador_logistica_all ON Direccion;
DROP POLICY IF EXISTS carrito_operador_logistica_all ON Carrito;
DROP POLICY IF EXISTS lineacarrito_operador_logistica_all ON lineaCarrito;
DROP POLICY IF EXISTS factura_operador_logistica_all ON Factura;
DROP POLICY IF EXISTS lineafactura_operador_logistica_all ON lineaFactura;
DROP POLICY IF EXISTS envio_operador_logistica_all ON Envio;

CREATE POLICY usuario_operador_logistica_all ON Usuario
    FOR SELECT
    TO operador_logistica
    USING (true);

CREATE POLICY direccion_operador_logistica_all ON Direccion
    FOR SELECT
    TO operador_logistica
    USING (true);

CREATE POLICY carrito_operador_logistica_all ON Carrito
    FOR SELECT
    TO operador_logistica
    USING (true);

CREATE POLICY lineacarrito_operador_logistica_all ON lineaCarrito
    FOR SELECT
    TO operador_logistica
    USING (true);

CREATE POLICY factura_operador_logistica_all ON Factura
    FOR SELECT
    TO operador_logistica
    USING (true);

CREATE POLICY lineafactura_operador_logistica_all ON lineaFactura
    FOR SELECT
    TO operador_logistica
    USING (true);

CREATE POLICY envio_operador_logistica_all ON Envio
    FOR ALL
    TO operador_logistica
    USING (true)
    WITH CHECK (true);



-- 13. FORZAR RLS (incluso para el owner; superuser siempre bypass)

ALTER TABLE usuario      FORCE ROW LEVEL SECURITY;
ALTER TABLE direccion    FORCE ROW LEVEL SECURITY;
ALTER TABLE carrito      FORCE ROW LEVEL SECURITY;
ALTER TABLE lineacarrito FORCE ROW LEVEL SECURITY;
ALTER TABLE favorito     FORCE ROW LEVEL SECURITY;
ALTER TABLE reseña       FORCE ROW LEVEL SECURITY;
ALTER TABLE factura      FORCE ROW LEVEL SECURITY;
ALTER TABLE lineafactura FORCE ROW LEVEL SECURITY;
ALTER TABLE pago         FORCE ROW LEVEL SECURITY;
ALTER TABLE envio        FORCE ROW LEVEL SECURITY;

COMMIT;

