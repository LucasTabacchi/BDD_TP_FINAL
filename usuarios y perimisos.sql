-- =========================================================
-- USUARIOS Y PERMISOS (PostgreSQL) - Versión corregida
-- =========================================================
-- Correcciones principales:
-- - CREATE USER ... WITH PASSWORD (forma estándar)
-- - Usuarios con LOGIN (por defecto) y roles de permisos asignados
-- - Opcional: SET ROLE en sesión lo hace la app, no acá
-- - Transacción OK (BEGIN/COMMIT) mantenida

BEGIN;

-- Crear usuarios si no existen (evita error al re-ejecutar)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ana_perez') THEN
        CREATE USER ana_perez WITH PASSWORD 'Password1';        -- cliente_app
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fernando_rossi') THEN
        CREATE USER fernando_rossi WITH PASSWORD 'Password6';   -- operador_comercial
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hernan_torres') THEN
        CREATE USER hernan_torres WITH PASSWORD 'Password8';    -- operador_logistica
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'julian_diaz') THEN
        CREATE USER julian_diaz WITH PASSWORD 'Password10';     -- admin_app
    END IF;
END $$;

-- Asignar roles (permisos) a los usuarios
GRANT cliente_app          TO ana_perez;
GRANT operador_comercial   TO fernando_rossi;
GRANT operador_logistica   TO hernan_torres;
GRANT admin_app            TO julian_diaz;

-- (Opcional, recomendado) Hacer que el rol asignado sea el rol por defecto al conectar
-- Si no lo ponés, igual pueden usar SET ROLE manualmente (o la app hacerlo).
ALTER USER ana_perez        SET ROLE cliente_app;
ALTER USER fernando_rossi   SET ROLE operador_comercial;
ALTER USER hernan_torres    SET ROLE operador_logistica;
ALTER USER julian_diaz      SET ROLE admin_app;

COMMIT;
