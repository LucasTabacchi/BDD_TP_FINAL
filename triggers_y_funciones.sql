BEGIN;

-- =========================================================
-- TRIGGERS PARA GESTIÓN DE STOCK (INGRESOS)
-- =========================================================

CREATE OR REPLACE FUNCTION actualizar_stock_ingreso()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE producto
  SET stock = stock + NEW.cant
  WHERE producto_id = NEW.id_producto;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_actualizar_stock_ingreso ON ingresoproducto;
CREATE TRIGGER trigger_actualizar_stock_ingreso
AFTER INSERT ON ingresoproducto
FOR EACH ROW
EXECUTE FUNCTION actualizar_stock_ingreso();

-- =========================================================
-- TRIGGERS PARA CARRITO DE COMPRAS
-- =========================================================

-- Setear precio_unitario desde Producto y calcular subtotal (carrito es "estimativo")
CREATE OR REPLACE FUNCTION set_precio_y_subtotal_carrito()
RETURNS TRIGGER AS $$
DECLARE
  v_precio NUMERIC(10,2);
BEGIN
  SELECT precio INTO v_precio
  FROM Producto
  WHERE producto_id = NEW.id_producto;

  IF v_precio IS NULL THEN
    RAISE EXCEPTION 'Producto inexistente: %', NEW.id_producto;
  END IF;

  NEW.precio_unitario := v_precio;
  NEW.subtotal := ROUND(NEW.cantidad * NEW.precio_unitario, 2);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_precio_y_subtotal_carrito ON lineacarrito;
CREATE TRIGGER trigger_set_precio_y_subtotal_carrito
BEFORE INSERT OR UPDATE ON lineacarrito
FOR EACH ROW
EXECUTE FUNCTION set_precio_y_subtotal_carrito();

-- Validar que el carrito exista y esté activo
CREATE OR REPLACE FUNCTION validar_carrito_activo()
RETURNS TRIGGER AS $$
DECLARE
  estado_carrito VARCHAR(15);
BEGIN
  SELECT estado INTO estado_carrito
  FROM carrito
  WHERE carrito_id = NEW.id_carrito;

  IF estado_carrito IS NULL THEN
    RAISE EXCEPTION 'No existe el carrito (carrito_id=%)', NEW.id_carrito;
  END IF;

  IF estado_carrito <> 'activo' THEN
    RAISE EXCEPTION 'No se pueden modificar líneas: el carrito % está %', NEW.id_carrito, estado_carrito;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_carrito_activo ON lineacarrito;
CREATE TRIGGER trigger_validar_carrito_activo
BEFORE INSERT OR UPDATE ON lineacarrito
FOR EACH ROW
EXECUTE FUNCTION validar_carrito_activo();

-- Validar stock suficiente antes de agregar al carrito (considera el total que quedaría en carrito)
CREATE OR REPLACE FUNCTION validar_stock_carrito()
RETURNS TRIGGER AS $$
DECLARE
  stock_disponible INT;
  cantidad_total INT;
BEGIN
  SELECT stock INTO stock_disponible
  FROM Producto
  WHERE producto_id = NEW.id_producto;

  IF stock_disponible IS NULL THEN
    RAISE EXCEPTION 'Producto inexistente: %', NEW.id_producto;
  END IF;

  -- En tu modelo la PK es (id_carrito, id_producto): hay 1 sola fila por producto en el carrito,
  -- pero igual dejamos la lógica robusta.
  IF TG_OP = 'UPDATE' THEN
    SELECT COALESCE(SUM(cantidad), 0) INTO cantidad_total
    FROM lineaCarrito
    WHERE id_carrito = NEW.id_carrito
      AND id_producto = NEW.id_producto
      AND (id_carrito, id_producto) <> (OLD.id_carrito, OLD.id_producto);

    cantidad_total := cantidad_total + NEW.cantidad;
  ELSE
    SELECT COALESCE(SUM(cantidad), 0) INTO cantidad_total
    FROM lineaCarrito
    WHERE id_carrito = NEW.id_carrito
      AND id_producto = NEW.id_producto;

    cantidad_total := cantidad_total + NEW.cantidad;
  END IF;

  IF cantidad_total > stock_disponible THEN
    RAISE EXCEPTION
      'Stock insuficiente. Stock disponible: %, cantidad solicitada: %',
      stock_disponible, cantidad_total;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_stock_carrito ON lineacarrito;
CREATE TRIGGER trigger_validar_stock_carrito
BEFORE INSERT OR UPDATE ON lineacarrito
FOR EACH ROW
EXECUTE FUNCTION validar_stock_carrito();

-- Actualizar total y fecha_actualizacion del carrito
CREATE OR REPLACE FUNCTION actualizar_total_carrito()
RETURNS TRIGGER AS $$
DECLARE
  nuevo_total NUMERIC(10,2);
  v_carrito_id INT;
  v_estado VARCHAR(15);
BEGIN
  v_carrito_id := COALESCE(NEW.id_carrito, OLD.id_carrito);

  SELECT estado INTO v_estado
  FROM Carrito
  WHERE carrito_id = v_carrito_id;

  -- Si está cerrado, no tocar el total (queda histórico)
  IF v_estado = 'cerrado' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT COALESCE(SUM(subtotal), 0) INTO nuevo_total
  FROM lineacarrito
  WHERE id_carrito = v_carrito_id;

  UPDATE carrito
  SET total = nuevo_total,
      fecha_actualizacion = CURRENT_DATE
  WHERE carrito_id = v_carrito_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_actualizar_total_carrito ON lineacarrito;
CREATE TRIGGER trigger_actualizar_total_carrito
AFTER INSERT OR UPDATE OR DELETE ON lineacarrito
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_carrito();

-- =========================================================
-- TRIGGERS PARA FACTURACIÓN
-- =========================================================

-- Setear precio_unitario desde Producto y calcular subtotal con descuento.
-- Además: si NEW.descuento viene NULL, lo calcula desde Promocion activa en la fecha de la factura.
CREATE OR REPLACE FUNCTION set_precio_descuento_y_subtotal_factura()
RETURNS TRIGGER AS $$
DECLARE
  v_precio NUMERIC(10,2);
  v_desc INT;
  v_precio_final NUMERIC(10,2);
  v_fecha DATE;
BEGIN
  -- Precio desde producto
  SELECT precio INTO v_precio
  FROM Producto
  WHERE producto_id = NEW.id_producto;

  IF v_precio IS NULL THEN
    RAISE EXCEPTION 'Producto inexistente: %', NEW.id_producto;
  END IF;

  NEW.precio_unitario := v_precio;

  -- Fecha de la factura (para evaluar promo)
  SELECT fecha INTO v_fecha
  FROM Factura
  WHERE factura_id = NEW.id_factura;

  IF v_fecha IS NULL THEN
    v_fecha := CURRENT_DATE;
  END IF;

  -- Descuento desde promoción activa (si no viene seteado)
  IF NEW.descuento IS NULL THEN
    SELECT MAX(p.descuento) INTO v_desc
    FROM Promocion p
    WHERE p.id_producto = NEW.id_producto
      AND p.activa = TRUE
      AND v_fecha BETWEEN p.fechaInicio AND p.fechaFin;

    NEW.descuento := COALESCE(v_desc, 0);
  END IF;

  v_precio_final := NEW.precio_unitario * (1 - COALESCE(NEW.descuento, 0)::NUMERIC / 100);
  NEW.subtotal := ROUND(v_precio_final * NEW.cantidad, 2);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_precio_y_subtotal_factura ON lineafactura;
CREATE TRIGGER trigger_set_precio_y_subtotal_factura
BEFORE INSERT ON lineafactura
FOR EACH ROW
EXECUTE FUNCTION set_precio_descuento_y_subtotal_factura();

-- Validar stock suficiente para facturar (UPDATE por diferencia)
CREATE OR REPLACE FUNCTION validar_stock_factura()
RETURNS TRIGGER AS $$
DECLARE
  stock_disponible INT;
  delta INT;
BEGIN
  SELECT stock INTO stock_disponible
  FROM producto
  WHERE producto_id = NEW.id_producto;

  IF stock_disponible IS NULL THEN
    RAISE EXCEPTION 'Producto inexistente: %', NEW.id_producto;
  END IF;

  IF TG_OP = 'INSERT' THEN
    delta := NEW.cantidad;
  ELSE
    IF OLD.id_producto <> NEW.id_producto THEN
      delta := NEW.cantidad;
    ELSE
      delta := NEW.cantidad - OLD.cantidad;
    END IF;
  END IF;

  IF delta > 0 AND stock_disponible < delta THEN
    RAISE EXCEPTION
      'Stock insuficiente para facturar. Stock disponible: %, cantidad requerida adicional: %',
      stock_disponible, delta;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_stock_factura ON lineafactura;
CREATE TRIGGER trigger_validar_stock_factura
BEFORE INSERT OR UPDATE ON lineafactura
FOR EACH ROW
EXECUTE FUNCTION validar_stock_factura();

-- Reducir stock cuando se crea/actualiza una línea de factura
CREATE OR REPLACE FUNCTION reducir_stock_factura()
RETURNS TRIGGER AS $$
DECLARE
  diferencia_cantidad INT;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.id_producto <> NEW.id_producto THEN
      UPDATE producto
      SET stock = stock + OLD.cantidad
      WHERE producto_id = OLD.id_producto;

      UPDATE producto
      SET stock = stock - NEW.cantidad
      WHERE producto_id = NEW.id_producto;
    ELSE
      diferencia_cantidad := NEW.cantidad - OLD.cantidad;

      UPDATE producto
      SET stock = stock - diferencia_cantidad
      WHERE producto_id = NEW.id_producto;
    END IF;
  ELSE
    UPDATE producto
    SET stock = stock - NEW.cantidad
    WHERE producto_id = NEW.id_producto;
  END IF;

  IF (SELECT stock FROM producto WHERE producto_id = NEW.id_producto) < 0 THEN
    RAISE EXCEPTION 'Error: El stock no puede ser negativo';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_reducir_stock_factura ON lineafactura;
CREATE TRIGGER trigger_reducir_stock_factura
AFTER INSERT OR UPDATE ON lineafactura
FOR EACH ROW
EXECUTE FUNCTION reducir_stock_factura();

-- Revertir stock al borrar una línea de factura
CREATE OR REPLACE FUNCTION revertir_stock_factura_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE producto
  SET stock = stock + OLD.cantidad
  WHERE producto_id = OLD.id_producto;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_revertir_stock_factura_del ON lineafactura;
CREATE TRIGGER trigger_revertir_stock_factura_del
AFTER DELETE ON lineafactura
FOR EACH ROW
EXECUTE FUNCTION revertir_stock_factura_delete();

-- Actualizar monto_total de factura
CREATE OR REPLACE FUNCTION actualizar_monto_total_factura()
RETURNS TRIGGER AS $$
DECLARE
  nuevo_monto_total NUMERIC(10,2);
  v_factura_id INT;
BEGIN
  v_factura_id := COALESCE(NEW.id_factura, OLD.id_factura);

  SELECT COALESCE(ROUND(SUM(subtotal), 2), 0) INTO nuevo_monto_total
  FROM lineafactura
  WHERE id_factura = v_factura_id;

  UPDATE factura
  SET monto_total = nuevo_monto_total
  WHERE factura_id = v_factura_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_actualizar_monto_total_factura ON lineafactura;
CREATE TRIGGER trigger_actualizar_monto_total_factura
AFTER INSERT OR UPDATE OR DELETE ON lineafactura
FOR EACH ROW
EXECUTE FUNCTION actualizar_monto_total_factura();

-- Validar pago total (sin pagos parciales)
CREATE OR REPLACE FUNCTION validar_pago_total_factura()
RETURNS TRIGGER AS $$
DECLARE
  v_monto_total NUMERIC(10,2);
  v_monto_pagado NUMERIC(10,2);
BEGIN
  SELECT monto_total INTO v_monto_total
  FROM Factura
  WHERE factura_id = NEW.id_factura;

  IF TG_OP = 'UPDATE' THEN
    SELECT COALESCE(SUM(monto), 0) INTO v_monto_pagado
    FROM Pago
    WHERE id_factura = NEW.id_factura
      AND pago_id != NEW.pago_id;
  ELSE
    v_monto_pagado := 0;
  END IF;

  v_monto_pagado := v_monto_pagado + NEW.monto;

  IF v_monto_pagado <> v_monto_total THEN
    RAISE EXCEPTION
      'El monto del pago (%) debe ser exactamente igual al monto_total de la factura (%). No se permiten pagos parciales.',
      v_monto_pagado, v_monto_total;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_pago_total_factura ON Pago;
CREATE TRIGGER trigger_validar_pago_total_factura
BEFORE INSERT OR UPDATE ON Pago
FOR EACH ROW
EXECUTE FUNCTION validar_pago_total_factura();

COMMENT ON FUNCTION validar_pago_total_factura() IS
'Valida que el monto del pago sea exactamente igual al monto_total de la factura';

-- Bloqueo UPDATE/DELETE de Factura (mantengo tu lógica original)
CREATE OR REPLACE FUNCTION bloquear_update_factura()
RETURNS trigger AS $$
BEGIN
  IF OLD.estado = 'emitida' AND NEW.estado = 'anulada' THEN
    RETURN NEW;
  END IF;

  IF OLD.estado = 'emitida'
     AND NEW.estado = OLD.estado
     AND NEW.id_usuario = OLD.id_usuario
     AND NEW.fecha = OLD.fecha
     AND NEW.monto_total IS DISTINCT FROM OLD.monto_total
  THEN
    RETURN NEW;
  END IF;

  IF OLD.estado IN ('emitida', 'anulada') THEN
    RAISE EXCEPTION
      'No se permite modificar facturas conformadas. Use anulación.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bloquear_delete_factura()
RETURNS trigger AS $$
BEGIN
  IF OLD.estado IN ('emitida', 'anulada') THEN
    RAISE EXCEPTION
      'No se permite eliminar facturas conformadas. Use anulación.';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_factura_no_update ON Factura;
CREATE TRIGGER trg_factura_no_update
BEFORE UPDATE ON Factura
FOR EACH ROW
EXECUTE FUNCTION bloquear_update_factura();

DROP TRIGGER IF EXISTS trg_factura_no_delete ON Factura;
CREATE TRIGGER trg_factura_no_delete
BEFORE DELETE ON Factura
FOR EACH ROW
EXECUTE FUNCTION bloquear_delete_factura();

-- OPCIÓN B: AL CREAR FACTURA, COPIAR CANTIDADES DEL CARRITO ACTIVO,
-- RECALCULAR PRECIO/DESCUENTO/SUBTOTAL EN LINEAFACTURA (desde Producto/Promocion),
-- CERRAR Y LIMPIAR CARRITO, Y CREAR NUEVO CARRITO ACTIVO.

CREATE OR REPLACE FUNCTION fn_factura_desde_carrito_activo_recalcula()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_carrito_id INT;
  v_cant_lineas INT;
BEGIN
  -- Obtener carrito activo único del usuario
  SELECT carrito_id INTO v_carrito_id
  FROM Carrito
  WHERE id_usuario = NEW.id_usuario
    AND estado = 'activo'
  LIMIT 1;

  IF v_carrito_id IS NULL THEN
    RAISE EXCEPTION 'No existe carrito activo para usuario_id=%', NEW.id_usuario;
  END IF;

  -- Evitar facturar carrito vacío
  SELECT COUNT(*) INTO v_cant_lineas
  FROM lineaCarrito
  WHERE id_carrito = v_carrito_id;

  IF v_cant_lineas = 0 THEN
    RAISE EXCEPTION 'El carrito activo (carrito_id=%) está vacío; no se puede emitir factura', v_carrito_id;
  END IF;

  -- Insertar líneas de factura SOLO con producto y cantidad.
  -- Precio/descuento/subtotal se calcularán por trigger BEFORE INSERT en lineafactura
  INSERT INTO lineaFactura (id_factura, id_producto, descuento, cantidad, precio_unitario, subtotal)
  SELECT
    NEW.factura_id,
    lc.id_producto,
    NULL,           -- descuento lo calcula desde Promocion
    lc.cantidad,
    NULL,           -- precio_unitario lo calcula desde Producto
    NULL            -- subtotal lo calcula desde precio/desc
  FROM lineaCarrito lc
  WHERE lc.id_carrito = v_carrito_id;

  -- Cerrar carrito
  UPDATE Carrito
  SET estado = 'cerrado',
      fecha_actualizacion = CURRENT_DATE
  WHERE carrito_id = v_carrito_id;

  -- Limpiar líneas del carrito
  DELETE FROM lineaCarrito WHERE id_carrito = v_carrito_id;

  -- Crear nuevo carrito activo (índice parcial garantiza unicidad)
  INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total)
  VALUES (NEW.id_usuario, CURRENT_DATE, CURRENT_DATE, 'activo', 0);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_factura_desde_carrito_activo ON Factura;
CREATE TRIGGER trg_factura_desde_carrito_activo
AFTER INSERT ON Factura
FOR EACH ROW
EXECUTE FUNCTION fn_factura_desde_carrito_activo_recalcula();

-- =========================================================
-- TRIGGERS PARA ENVÍOS
-- =========================================================
CREATE OR REPLACE FUNCTION validar_transicion_estado_envio()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.estado = 'entregado' AND NEW.estado <> 'entregado' THEN
    RAISE EXCEPTION 'No se puede cambiar el estado de un envío ya entregado';
  END IF;

  IF NEW.estado = 'entregado' AND NEW.fechaEntrega IS NULL THEN
    NEW.fechaEntrega := CURRENT_DATE;
  END IF;

  IF NEW.estado = 'enCamino' AND NEW.fechaArribo IS NULL THEN
    NEW.fechaArribo := CURRENT_DATE;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_transicion_estado_envio ON envio;
CREATE TRIGGER trigger_validar_transicion_estado_envio
BEFORE UPDATE ON envio
FOR EACH ROW
EXECUTE FUNCTION validar_transicion_estado_envio();

-- =========================================================
-- FUNCIÓN: ANULAR FACTURA (mantengo tu implementación)
-- =========================================================
CREATE OR REPLACE FUNCTION anular_factura(p_factura_id INT, p_motivo TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
  v_estado VARCHAR(10);
BEGIN
  SELECT estado INTO v_estado
  FROM Factura
  WHERE factura_id = p_factura_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Factura % no existe', p_factura_id;
  END IF;

  IF v_estado = 'anulada' THEN
    RAISE EXCEPTION 'Factura % ya está anulada', p_factura_id;
  END IF;

  UPDATE Producto p
  SET stock = p.stock + lf.cantidad
  FROM lineaFactura lf
  WHERE lf.id_factura = p_factura_id
    AND p.producto_id = lf.id_producto;

  UPDATE Factura
  SET estado = 'anulada'
  WHERE factura_id = p_factura_id;

  IF p_motivo IS NOT NULL THEN
    RAISE NOTICE 'Factura % anulada. Motivo: %', p_factura_id, p_motivo;
  END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION anular_factura(INT, TEXT) IS
'Anula una factura sin borrarla: restaura stock según lineaFactura y marca estado=anulada. No elimina líneas.';

COMMIT;

