-- =========================================================
-- CREACIÓN DE BASE DE DATOS (PostgreSQL / psql)
-- =========================================================
-- Ejecutar con: psql -f creacion_db.sql
-- Nota: CREATE/DROP DATABASE NO pueden correr dentro de una transacción.

\echo '-> Re-creando base de datos ecommerce_db'

-- 1) Cerrar conexiones y borrar DB si existe
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'ecommerce_db'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS ecommerce_db;

-- 2) Crear DB
CREATE DATABASE ecommerce_db;

-- 3) Conectarse
\c ecommerce_db;

-- (Opcional) Asegurar schema public. En Postgres ya existe por defecto.
-- CREATE SCHEMA IF NOT EXISTS public;
