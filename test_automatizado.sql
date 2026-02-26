-- =========================================================
-- TEST SCRIPT (PostgreSQL) - Ecommerce DB
-- Prueba: carrito único activo, triggers de carrito,
-- facturación desde carrito, precio/promo al facturar,
-- cierre/limpieza de carrito, stock, pagos, anulación y envíos.
--
-- =========================================================

BEGIN;

DO $$
DECLARE
  -- IDs base
  v_provincia_id  INT;
  v_ciudad_id     INT;
  v_usuario_id    INT;
  v_direccion_id  INT;

  v_p1            INT;  -- producto 1
  v_p2            INT;  -- producto 2
  v_carrito_id    INT;  -- carrito activo inicial
  v_factura_id    INT;  -- factura emitida
  v_envio_id      INT;

  -- Aux
  v_total_carrito NUMERIC(10,2);
  v_total_lineas  NUMERIC(10,2);
  v_monto_factura NUMERIC(10,2);
  v_sum_factura   NUMERIC(10,2);

  v_stock_p1_before INT;
  v_stock_p2_before INT;
  v_stock_p1_after  INT;
  v_stock_p2_after  INT;

  v_failed BOOLEAN;
BEGIN
  RAISE NOTICE '=================================================';
  RAISE NOTICE 'SETUP: creando datos mínimos';
  RAISE NOTICE '=================================================';

  -- Ubicación
  INSERT INTO Provincia(nombre) VALUES ('TEST_PROV') RETURNING provincia_id INTO v_provincia_id;
  INSERT INTO Ciudad(id_provincia, cp, nombre)
  VALUES (v_provincia_id, '0000', 'TEST_CIUDAD') RETURNING ciudad_id INTO v_ciudad_id;

  -- Usuario + dirección
  INSERT INTO Usuario(nombre, apellido, email, contrasenia, db_login, rol)
  VALUES ('Test', 'User', 'test_user@example.com', 'password123', 'test_login', 'cliente_app')
  RETURNING usuario_id INTO v_usuario_id;

  INSERT INTO Direccion(id_usuario, id_ciudad, calle)
  VALUES (v_usuario_id, v_ciudad_id, 'Calle Falsa 123')
  RETURNING direccion_id INTO v_direccion_id;

  -- Productos
  INSERT INTO Producto(nombre, stock, precio, descripcion)
  VALUES ('Prod 1', 10, 100, 'P1') RETURNING producto_id INTO v_p1;

  INSERT INTO Producto(nombre, stock, precio, descripcion)
  VALUES ('Prod 2', 5,  50,  'P2') RETURNING producto_id INTO v_p2;

  -- Promo para P1 (activa hoy)
  INSERT INTO Promocion(id_producto, fechaInicio, fechaFin, titulo, descripcion, descuento, activa)
  VALUES (v_p1, CURRENT_DATE - 1, CURRENT_DATE + 10, 'PROMO P1', 'desc 20', 20, TRUE);

  -- Carrito activo inicial
  INSERT INTO Carrito(id_usuario, fecha_creacion, fecha_actualizacion, estado, total)
  VALUES (v_usuario_id, CURRENT_DATE, CURRENT_DATE, 'activo', 0)
  RETURNING carrito_id INTO v_carrito_id;

  RAISE NOTICE 'SETUP OK: usuario_id=%, carrito_id=%, p1=%, p2=%', v_usuario_id, v_carrito_id, v_p1, v_p2;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 1: único carrito activo por usuario (debe FALLAR el segundo)';
  RAISE NOTICE '=================================================';

  v_failed := FALSE;
  BEGIN
    INSERT INTO Carrito(id_usuario, fecha_creacion, fecha_actualizacion, estado, total)
    VALUES (v_usuario_id, CURRENT_DATE, CURRENT_DATE, 'activo', 0);
  EXCEPTION WHEN OTHERS THEN
    v_failed := TRUE;
    RAISE NOTICE 'OK (falló como se esperaba): %', SQLERRM;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'FAIL: se pudo crear un 2do carrito activo (debería bloquearlo el índice parcial).';
  END IF;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 2: carrito - precio/subtotal no hardcodeado + total actualizado';
  RAISE NOTICE '=================================================';

  -- Insertar líneas con precio_unitario/subtotal "basura" para verificar que trigger los corrige
  INSERT INTO lineaCarrito(id_carrito, id_producto, cantidad, precio_unitario, subtotal)
  VALUES (v_carrito_id, v_p1, 2, 0, 1);

  INSERT INTO lineaCarrito(id_carrito, id_producto, cantidad, precio_unitario, subtotal)
  VALUES (v_carrito_id, v_p2, 1, 0, 1);

  -- Verificar que precio_unitario/subtotal se setearon desde Producto
  IF (SELECT precio_unitario FROM lineaCarrito WHERE id_carrito=v_carrito_id AND id_producto=v_p1) <> 100 THEN
    RAISE EXCEPTION 'FAIL: carrito P1 precio_unitario no coincide con Producto.precio';
  END IF;

  IF (SELECT subtotal FROM lineaCarrito WHERE id_carrito=v_carrito_id AND id_producto=v_p1) <> 200 THEN
    RAISE EXCEPTION 'FAIL: carrito P1 subtotal esperado 200';
  END IF;

  SELECT total INTO v_total_carrito FROM Carrito WHERE carrito_id=v_carrito_id;
  SELECT COALESCE(SUM(subtotal),0) INTO v_total_lineas FROM lineaCarrito WHERE id_carrito=v_carrito_id;

  IF v_total_carrito <> v_total_lineas THEN
    RAISE EXCEPTION 'FAIL: Carrito.total (%) != SUM(lineaCarrito.subtotal) (%)', v_total_carrito, v_total_lineas;
  END IF;

  RAISE NOTICE 'OK: total carrito=%', v_total_carrito;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 3: no permitir agregar líneas en carrito cerrado (debe FALLAR)';
  RAISE NOTICE '=================================================';

  -- Cerrar carrito
  UPDATE Carrito SET estado='cerrado' WHERE carrito_id=v_carrito_id;

  v_failed := FALSE;
  BEGIN
    INSERT INTO lineaCarrito(id_carrito, id_producto, cantidad, precio_unitario, subtotal)
    VALUES (v_carrito_id, v_p1, 1, 0, 1);
  EXCEPTION WHEN OTHERS THEN
    v_failed := TRUE;
    RAISE NOTICE 'OK (falló como se esperaba): %', SQLERRM;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'FAIL: se pudo insertar línea en carrito cerrado';
  END IF;

  -- Reabrir para seguir test (si tu CHECK permite solo activo/cerrado, vuelve a activo)
  UPDATE Carrito SET estado='activo' WHERE carrito_id=v_carrito_id;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 4: validar stock en carrito (pedir más que stock -> FALLA)';
  RAISE NOTICE '=================================================';

  v_failed := FALSE;
  BEGIN
    -- P2 tiene stock 5, ya hay 1 en carrito (cantidad=1). Intentamos subir a 6 total.
    UPDATE lineaCarrito
    SET cantidad = 6
    WHERE id_carrito=v_carrito_id AND id_producto=v_p2;
  EXCEPTION WHEN OTHERS THEN
    v_failed := TRUE;
    RAISE NOTICE 'OK (falló como se esperaba): %', SQLERRM;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'FAIL: se pudo exceder stock en carrito';
  END IF;

  -- Volvemos cantidad a 1 (si el update falló, ya quedó en 1 igual; lo dejamos consistente)
  UPDATE lineaCarrito
  SET cantidad = 1
  WHERE id_carrito=v_carrito_id AND id_producto=v_p2;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 5: facturar desde carrito (opción B) + promo/precio al facturar';
  RAISE NOTICE '=================================================';

  SELECT stock INTO v_stock_p1_before FROM Producto WHERE producto_id=v_p1;
  SELECT stock INTO v_stock_p2_before FROM Producto WHERE producto_id=v_p2;

  -- Crear factura (monto_total se recalcula por triggers de lineafactura)
  INSERT INTO Factura(id_usuario, fecha, monto_total, estado)
  VALUES (v_usuario_id, CURRENT_DATE, 0, 'emitida')
  RETURNING factura_id INTO v_factura_id;

  RAISE NOTICE 'Factura creada: factura_id=%', v_factura_id;

  -- Verificar líneas creadas
  IF NOT EXISTS (SELECT 1 FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p1) THEN
    RAISE EXCEPTION 'FAIL: no se creó línea de factura para P1';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p2) THEN
    RAISE EXCEPTION 'FAIL: no se creó línea de factura para P2';
  END IF;

  -- Verificar promo aplicada (P1 descuento 20) y P2 descuento 0 o NULL->0
  IF (SELECT COALESCE(descuento,0) FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p1) <> 20 THEN
    RAISE EXCEPTION 'FAIL: descuento P1 no es 20';
  END IF;

  IF (SELECT COALESCE(descuento,0) FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p2) <> 0 THEN
    RAISE EXCEPTION 'FAIL: descuento P2 no es 0';
  END IF;

  -- Verificar precios tomados de Producto al facturar
  IF (SELECT precio_unitario FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p1) <> 100 THEN
    RAISE EXCEPTION 'FAIL: precio_unitario P1 en factura no es 100';
  END IF;

  IF (SELECT precio_unitario FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p2) <> 50 THEN
    RAISE EXCEPTION 'FAIL: precio_unitario P2 en factura no es 50';
  END IF;

  -- Verificar subtotales: P1=2*100*(1-0.2)=160, P2=1*50=50 total=210
  IF (SELECT subtotal FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p1) <> 160 THEN
    RAISE EXCEPTION 'FAIL: subtotal P1 esperado 160';
  END IF;

  IF (SELECT subtotal FROM lineaFactura WHERE id_factura=v_factura_id AND id_producto=v_p2) <> 50 THEN
    RAISE EXCEPTION 'FAIL: subtotal P2 esperado 50';
  END IF;

  SELECT monto_total INTO v_monto_factura FROM Factura WHERE factura_id=v_factura_id;
  SELECT COALESCE(SUM(subtotal),0) INTO v_sum_factura FROM lineaFactura WHERE id_factura=v_factura_id;

  IF v_monto_factura <> v_sum_factura OR v_monto_factura <> 210 THEN
    RAISE EXCEPTION 'FAIL: monto_total factura (%) != sum líneas (%) o != 210', v_monto_factura, v_sum_factura;
  END IF;

  RAISE NOTICE 'OK: monto_total factura=%', v_monto_factura;

  -- Verificar stock descontado: P1 10->8, P2 5->4
  SELECT stock INTO v_stock_p1_after FROM Producto WHERE producto_id=v_p1;
  SELECT stock INTO v_stock_p2_after FROM Producto WHERE producto_id=v_p2;

  IF v_stock_p1_after <> (v_stock_p1_before - 2) THEN
    RAISE EXCEPTION 'FAIL: stock P1 no descontó correctamente (before %, after %)', v_stock_p1_before, v_stock_p1_after;
  END IF;

  IF v_stock_p2_after <> (v_stock_p2_before - 1) THEN
    RAISE EXCEPTION 'FAIL: stock P2 no descontó correctamente (before %, after %)', v_stock_p2_before, v_stock_p2_after;
  END IF;

  RAISE NOTICE 'OK: stock después P1=% P2=%', v_stock_p1_after, v_stock_p2_after;

  -- Verificar carrito viejo cerrado y limpio, y nuevo carrito activo creado
  IF (SELECT estado FROM Carrito WHERE carrito_id=v_carrito_id) <> 'cerrado' THEN
    RAISE EXCEPTION 'FAIL: carrito viejo no quedó cerrado';
  END IF;

  IF (SELECT COUNT(*) FROM lineaCarrito WHERE id_carrito=v_carrito_id) <> 0 THEN
    RAISE EXCEPTION 'FAIL: carrito viejo no quedó limpio (lineas != 0)';
  END IF;

  -- Buscar último carrito activo
  SELECT carrito_id INTO v_carrito_id
  FROM Carrito
  WHERE id_usuario=v_usuario_id AND estado='activo'
  ORDER BY carrito_id DESC
  LIMIT 1;

  IF v_carrito_id IS NULL THEN
    RAISE EXCEPTION 'FAIL: no se creó nuevo carrito activo';
  END IF;

  IF (SELECT total FROM Carrito WHERE carrito_id=v_carrito_id) <> 0 THEN
    RAISE EXCEPTION 'FAIL: carrito nuevo debería tener total 0';
  END IF;

  RAISE NOTICE 'OK: nuevo carrito activo=%', v_carrito_id;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 6: congelamiento - NO permitir modificar líneas de factura emitida';
  RAISE NOTICE '=================================================';

  v_failed := FALSE;
  BEGIN
    UPDATE lineaFactura
    SET cantidad = cantidad + 1
    WHERE id_factura=v_factura_id AND id_producto=v_p1;
  EXCEPTION WHEN OTHERS THEN
    v_failed := TRUE;
    RAISE NOTICE 'OK (falló como se esperaba): %', SQLERRM;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'FAIL: se pudo modificar línea de factura emitida (debería estar congelada)';
  END IF;

  v_failed := FALSE;
  BEGIN
    DELETE FROM lineaFactura
    WHERE id_factura=v_factura_id AND id_producto=v_p2;
  EXCEPTION WHEN OTHERS THEN
    v_failed := TRUE;
    RAISE NOTICE 'OK (falló como se esperaba): %', SQLERRM;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'FAIL: se pudo borrar línea de factura emitida (debería estar congelada)';
  END IF;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 7: pago total exacto (sin pagos parciales)';
  RAISE NOTICE '=================================================';

  v_failed := FALSE;
  BEGIN
    INSERT INTO Pago(id_factura, monto, metodo)
    VALUES (v_factura_id, 100, 'mercadopago');
  EXCEPTION WHEN OTHERS THEN
    v_failed := TRUE;
    RAISE NOTICE 'OK (falló pago parcial como se esperaba): %', SQLERRM;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'FAIL: se permitió pago parcial';
  END IF;

  -- Pago exacto
  INSERT INTO Pago(id_factura, monto, metodo)
  VALUES (v_factura_id, (SELECT monto_total FROM Factura WHERE factura_id=v_factura_id), 'mercadopago');

  RAISE NOTICE 'OK: pago exacto insertado';

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 8: anulación restaura stock y cambia estado';
  RAISE NOTICE '=================================================';

  -- Guardar stock actual (descontado)
  SELECT stock INTO v_stock_p1_after FROM Producto WHERE producto_id=v_p1;
  SELECT stock INTO v_stock_p2_after FROM Producto WHERE producto_id=v_p2;

  PERFORM anular_factura(v_factura_id, 'test anulación');

  IF (SELECT estado FROM Factura WHERE factura_id=v_factura_id) <> 'anulada' THEN
    RAISE EXCEPTION 'FAIL: factura no quedó anulada';
  END IF;

  -- Stock debería restaurarse a before
  IF (SELECT stock FROM Producto WHERE producto_id=v_p1) <> v_stock_p1_before THEN
    RAISE EXCEPTION 'FAIL: stock P1 no se restauró al anular';
  END IF;

  IF (SELECT stock FROM Producto WHERE producto_id=v_p2) <> v_stock_p2_before THEN
    RAISE EXCEPTION 'FAIL: stock P2 no se restauró al anular';
  END IF;

  RAISE NOTICE 'OK: anulación restauró stock y estado=anulada';

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TEST 9: envío - transición de estados';
  RAISE NOTICE '=================================================';

  -- Crear envío asociado a la factura
  INSERT INTO Envio(id_direccion, id_factura, estado, costoEnvio)
  VALUES (v_direccion_id, v_factura_id, 'pendiente', 0)
  RETURNING envio_id INTO v_envio_id;

  -- pendiente -> enCamino (setea fechaArribo si NULL)
  UPDATE Envio SET estado='enCamino' WHERE envio_id=v_envio_id;
  IF (SELECT fechaArribo FROM Envio WHERE envio_id=v_envio_id) IS NULL THEN
    RAISE EXCEPTION 'FAIL: fechaArribo no se seteó al pasar a enCamino';
  END IF;

  -- enCamino -> entregado (setea fechaEntrega si NULL)
  UPDATE Envio SET estado='entregado' WHERE envio_id=v_envio_id;
  IF (SELECT fechaEntrega FROM Envio WHERE envio_id=v_envio_id) IS NULL THEN
    RAISE EXCEPTION 'FAIL: fechaEntrega no se seteó al pasar a entregado';
  END IF;

  -- entregado -> enCamino (debe fallar)
  v_failed := FALSE;
  BEGIN
    UPDATE Envio SET estado='enCamino' WHERE envio_id=v_envio_id;
  EXCEPTION WHEN OTHERS THEN
    v_failed := TRUE;
    RAISE NOTICE 'OK (falló revertir estado entregado como se esperaba): %', SQLERRM;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'FAIL: se permitió cambiar estado de envío entregado a otro';
  END IF;

  RAISE NOTICE '=================================================';
  RAISE NOTICE 'TODOS LOS TESTS PASARON ✅';
  RAISE NOTICE 'Se hará ROLLBACK para no dejar datos.';
  RAISE NOTICE '=================================================';

END $$;

ROLLBACK;












