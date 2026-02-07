-- Crear base de datos
CREATE DATABASE ecommerce_db;

-- Conectarse a la base de datos
\c ecommerce_db;

-- Crear esquema (opcional, pero recomendable)
CREATE SCHEMA public;

-- Eliminar la base de datos si existe
DROP DATABASE IF EXISTS ecommerce_db;

ROLLBACK;