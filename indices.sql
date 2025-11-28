BEGIN;
-- Indice para garantizar que cada factura solo puede tener asociado un envío
CREATE UNIQUE INDEX IF NOT EXISTS idx_envio_factura_unico 
ON Envio (id_factura);

COMMENT ON INDEX idx_envio_factura_unico IS 
'Garantiza que cada factura solo puede tener un envío asociado';ç

COMMIT;

BEGIN;
-- índice único para garantizar un solo pago por factura
CREATE UNIQUE INDEX IF NOT EXISTS idx_pago_factura_unico 
ON Pago (id_factura);

COMMENT ON INDEX idx_pago_factura_unico IS 
'Garantiza que cada factura solo puede tener un pago';

COMMIT;