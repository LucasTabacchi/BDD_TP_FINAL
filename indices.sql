BEGIN;
-- Indice para garantizar que cada factura solo puede tener asociado un envío
CREATE UNIQUE INDEX IF NOT EXISTS idx_envio_factura_unico 
ON Envio (id_factura);

COMMENT ON INDEX idx_envio_factura_unico IS 
'Garantiza que cada factura solo puede tener un envío asociado';

COMMIT;

BEGIN;

-- índice único para garantizar un solo pago por factura
CREATE UNIQUE INDEX IF NOT EXISTS idx_pago_factura_unico 
ON Pago (id_factura);

COMMENT ON INDEX idx_pago_factura_unico IS 
'Garantiza que cada factura solo puede tener un pago';

COMMIT;

BEGIN

-- Índice para filtrar por facturas por estado
CREATE INDEX IF NOT EXISTS idx_factura_estado ON Factura(estado);

COMMIT;