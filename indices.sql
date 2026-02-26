BEGIN;

-- =========================================================
-- ÍNDICES
-- =========================================================

-- Un solo carrito activo por usuario
CREATE UNIQUE INDEX IF NOT EXISTS ux_carrito_un_activo_por_usuario
ON Carrito(id_usuario)
WHERE estado = 'activo';

COMMENT ON INDEX ux_carrito_un_activo_por_usuario IS
'Garantiza que cada usuario solo puede tener un carrito activo';

-- Un solo envío por factura
CREATE UNIQUE INDEX IF NOT EXISTS idx_envio_factura_unico
ON Envio (id_factura);

COMMENT ON INDEX idx_envio_factura_unico IS
'Garantiza que cada factura solo puede tener un envío asociado';

-- Un solo pago por factura
CREATE UNIQUE INDEX IF NOT EXISTS idx_pago_factura_unico
ON Pago (id_factura);

COMMENT ON INDEX idx_pago_factura_unico IS
'Garantiza que cada factura solo puede tener un pago';

-- Facturas por estado
CREATE INDEX IF NOT EXISTS idx_factura_estado
ON Factura (estado);

COMMIT;
