BEGIN;
-- =========================================================
-- TRIGGERS PARA GESTIÓN DE STOCK
-- =========================================================

-- Trigger: Actualizar stock automáticamente cuando hay un ingreso de producto
CREATE OR REPLACE FUNCTION actualizar_stock_ingreso()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE producto
    SET stock = stock + NEW.cant
    WHERE producto_id = NEW.id_producto;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_stock_ingreso
    AFTER INSERT ON ingresoproducto
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_stock_ingreso();

-- =========================================================
-- TRIGGERS PARA CARRITO DE COMPRAS
-- =========================================================

-- Trigger: Calcular subtotal automáticamente en lineaCarrito
CREATE OR REPLACE FUNCTION calcular_subtotal_carrito()
RETURNS TRIGGER AS $$
BEGIN
    NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calcular_subtotal_carrito
    BEFORE INSERT OR UPDATE ON lineacarrito
    FOR EACH ROW
    EXECUTE FUNCTION calcular_subtotal_carrito();

-- Trigger: Validar que el carrito esté activo antes de agregar líneas
CREATE OR REPLACE FUNCTION validar_carrito_activo()
RETURNS TRIGGER AS $$
DECLARE
    estado_carrito VARCHAR(15);
BEGIN
    SELECT estado INTO estado_carrito
    FROM carrito
    WHERE carrito_id = NEW.id_carrito;
    
    IF estado_carrito != 'activo' THEN
        RAISE EXCEPTION 'No se pueden agregar productos a un carrito cerrado';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_carrito_activo
    BEFORE INSERT OR UPDATE ON lineacarrito
    FOR EACH ROW
    EXECUTE FUNCTION validar_carrito_activo();

-- Trigger: Validar stock suficiente antes de agregar al carrito
-- Ejecuta solo la función corregida
CREATE OR REPLACE FUNCTION validar_stock_carrito()
RETURNS TRIGGER AS $$
DECLARE
    stock_disponible INT;
    cantidad_en_carrito INT;
BEGIN
    -- Obtener stock disponible del producto
    SELECT stock INTO stock_disponible
    FROM Producto
    WHERE producto_id = NEW.id_producto;
    
    -- Si es una actualización, considerar la cantidad anterior
    IF TG_OP = 'UPDATE' THEN
        SELECT COALESCE(SUM(cantidad), 0) INTO cantidad_en_carrito
        FROM lineaCarrito
        WHERE id_carrito = NEW.id_carrito
          AND id_producto = NEW.id_producto
          AND (id_carrito, id_producto) != (OLD.id_carrito, OLD.id_producto);
        
        cantidad_en_carrito := cantidad_en_carrito + NEW.cantidad;
    ELSE
        -- Para INSERT, sumar todas las cantidades existentes del mismo producto en el carrito
        -- más la cantidad que se está intentando insertar
        SELECT COALESCE(SUM(cantidad), 0) INTO cantidad_en_carrito
        FROM lineaCarrito
        WHERE id_carrito = NEW.id_carrito
          AND id_producto = NEW.id_producto;
        
        -- Sumar la cantidad que se está intentando insertar
        cantidad_en_carrito := cantidad_en_carrito + NEW.cantidad;
    END IF;
    
    IF cantidad_en_carrito > stock_disponible THEN
        RAISE EXCEPTION 'Stock insuficiente. Stock disponible: %, cantidad solicitada: %', 
            stock_disponible, cantidad_en_carrito;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_stock_carrito
    BEFORE INSERT OR UPDATE ON lineacarrito
    FOR EACH ROW
    EXECUTE FUNCTION validar_stock_carrito();

-- Trigger: Actualizar total y fecha_actualizacion del carrito
CREATE OR REPLACE FUNCTION actualizar_total_carrito()
RETURNS TRIGGER AS $$
DECLARE
    nuevo_total NUMERIC(10,2);
BEGIN
    -- Calcular el nuevo total sumando todos los subtotales
    SELECT COALESCE(SUM(subtotal), 0) INTO nuevo_total
    FROM lineacarrito
    WHERE id_carrito = COALESCE(NEW.id_carrito, OLD.id_carrito);
    
    -- Actualizar el carrito
    UPDATE carrito
    SET total = nuevo_total,
        fecha_actualizacion = CURRENT_DATE
    WHERE carrito_id = COALESCE(NEW.id_carrito, OLD.id_carrito);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_total_carrito
    AFTER INSERT OR UPDATE OR DELETE ON lineacarrito
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_total_carrito();

-- =========================================================
-- TRIGGERS PARA FACTURACIÓN
-- =========================================================

-- Trigger: Calcular subtotal automáticamente en lineaFactura
CREATE OR REPLACE FUNCTION calcular_subtotal_factura()
RETURNS TRIGGER AS $$
DECLARE
    precio_con_descuento NUMERIC(10,2);
BEGIN
    -- Calcular precio con descuento
    IF NEW.descuento IS NOT NULL AND NEW.descuento > 0 THEN
        precio_con_descuento := NEW.precio_unitario * (1 - NEW.descuento::NUMERIC / 100);
    ELSE
        precio_con_descuento := NEW.precio_unitario;
    END IF;
    
    NEW.subtotal := precio_con_descuento * NEW.cantidad;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calcular_subtotal_factura
    BEFORE INSERT OR UPDATE ON lineafactura
    FOR EACH ROW
    EXECUTE FUNCTION calcular_subtotal_factura();

-- Trigger: Validar stock suficiente antes de crear línea de factura
CREATE OR REPLACE FUNCTION validar_stock_factura()
RETURNS TRIGGER AS $$
DECLARE
    stock_disponible INT;
BEGIN
    SELECT stock INTO stock_disponible
    FROM producto
    WHERE producto_id = NEW.id_producto;
    
    IF stock_disponible < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para facturar. Stock disponible: %, cantidad solicitada: %', 
            stock_disponible, NEW.cantidad;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_stock_factura
    BEFORE INSERT OR UPDATE ON lineafactura
    FOR EACH ROW
    EXECUTE FUNCTION validar_stock_factura();

-- Trigger: Reducir stock cuando se crea una línea de factura
CREATE OR REPLACE FUNCTION reducir_stock_factura()
RETURNS TRIGGER AS $$
DECLARE
    diferencia_cantidad INT;
BEGIN
    -- Si es un UPDATE
    IF TG_OP = 'UPDATE' THEN
        -- Si cambió el producto, restaurar stock del producto anterior y restar del nuevo
        IF OLD.id_producto != NEW.id_producto THEN
            -- Restaurar stock del producto anterior
            UPDATE producto
            SET stock = stock + OLD.cantidad
            WHERE producto_id = OLD.id_producto;
            
            -- Restar stock del producto nuevo
            UPDATE producto
            SET stock = stock - NEW.cantidad
            WHERE producto_id = NEW.id_producto;
        ELSE
            -- Mismo producto, calcular la diferencia
            diferencia_cantidad := NEW.cantidad - OLD.cantidad;
            
            -- Actualizar el stock con la diferencia
            UPDATE producto
            SET stock = stock - diferencia_cantidad
            WHERE producto_id = NEW.id_producto;
        END IF;
    ELSE
        -- INSERT: restar la cantidad nueva
        UPDATE producto
        SET stock = stock - NEW.cantidad
        WHERE producto_id = NEW.id_producto;
    END IF;
    
    -- Validar que el stock no sea negativo
    IF (SELECT stock FROM producto WHERE producto_id = NEW.id_producto) < 0 THEN
        RAISE EXCEPTION 'Error: El stock no puede ser negativo';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_reducir_stock_factura
    AFTER INSERT OR UPDATE ON lineafactura
    FOR EACH ROW
    EXECUTE FUNCTION reducir_stock_factura();

-- Trigger: Restaurar stock cuando se elimina una línea de factura
CREATE OR REPLACE FUNCTION restaurar_stock_factura()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE producto
    SET stock = stock + OLD.cantidad
    WHERE producto_id = OLD.id_producto;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_restaurar_stock_factura
    AFTER DELETE ON lineafactura
    FOR EACH ROW
    EXECUTE FUNCTION restaurar_stock_factura();

-- Trigger: Actualizar monto_total de factura
CREATE OR REPLACE FUNCTION actualizar_monto_total_factura()
RETURNS TRIGGER AS $$
DECLARE
    nuevo_monto_total NUMERIC(10,2);
BEGIN
    -- Calcular el nuevo monto total sumando todos los subtotales
    SELECT COALESCE(SUM(subtotal), 0) INTO nuevo_monto_total
    FROM lineafactura
    WHERE id_factura = COALESCE(NEW.id_factura, OLD.id_factura);
    
    -- Actualizar la factura
    UPDATE factura
    SET monto_total = nuevo_monto_total
    WHERE factura_id = COALESCE(NEW.id_factura, OLD.id_factura);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_monto_total_factura
    AFTER INSERT OR UPDATE OR DELETE ON lineafactura
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_monto_total_factura();

-- Trigger: Validar que el monto del pago sea exactamente el monto_total
CREATE OR REPLACE FUNCTION validar_pago_total_factura()
RETURNS TRIGGER AS $$
DECLARE
    v_monto_total NUMERIC(10,2);
    v_monto_pagado NUMERIC(10,2);
BEGIN
    -- Obtener el monto_total de la factura
    SELECT monto_total INTO v_monto_total
    FROM Factura
    WHERE factura_id = NEW.id_factura;
    
    -- Si es un UPDATE, calcular el monto que ya está pagado (excluyendo el pago actual)
    IF TG_OP = 'UPDATE' THEN
        SELECT COALESCE(SUM(monto), 0) INTO v_monto_pagado
        FROM Pago
        WHERE id_factura = NEW.id_factura
          AND pago_id != NEW.pago_id;
    ELSE
        -- Para INSERT, no hay pagos previos
        v_monto_pagado := 0;
    END IF;
    
    -- Calcular el monto total que quedaría pagado
    v_monto_pagado := v_monto_pagado + NEW.monto;
    
    -- Validar que el monto del pago sea exactamente igual al monto_total
    IF v_monto_pagado != v_monto_total THEN
        RAISE EXCEPTION 
            'El monto del pago (%) debe ser exactamente igual al monto_total de la factura (%). No se permiten pagos parciales.', 
            v_monto_pagado, v_monto_total;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_pago_total_factura
    BEFORE INSERT OR UPDATE ON Pago
    FOR EACH ROW
    EXECUTE FUNCTION validar_pago_total_factura();

COMMENT ON FUNCTION validar_pago_total_factura() IS 
'Valida que el monto del pago sea exactamente igual al monto_total de la factura';

COMMIT;

-- =========================================================
-- TRIGGERS PARA ENVÍOS
-- =========================================================

-- Trigger: Validar transición de estados de envío
CREATE OR REPLACE FUNCTION validar_transicion_estado_envio()
RETURNS TRIGGER AS $$
BEGIN
    -- Validar que no se retroceda en el flujo de estados
    IF OLD.estado = 'entregado' AND NEW.estado != 'entregado' THEN
        RAISE EXCEPTION 'No se puede cambiar el estado de un envío ya entregado';
    END IF;
    
    -- Si se marca como entregado, establecer fechaEntrega si no existe
    IF NEW.estado = 'entregado' AND NEW.fechaEntrega IS NULL THEN
        NEW.fechaEntrega := CURRENT_DATE;
    END IF;
    
    -- Si se marca como enCamino, establecer fechaArribo si no existe
    IF NEW.estado = 'enCamino' AND NEW.fechaArribo IS NULL THEN
        NEW.fechaArribo := CURRENT_DATE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_transicion_estado_envio
    BEFORE UPDATE ON envio
    FOR EACH ROW
    EXECUTE FUNCTION validar_transicion_estado_envio();


COMMIT;