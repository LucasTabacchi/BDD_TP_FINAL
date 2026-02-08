-- =========================================================
-- ecommerce_backup.sql
-- Backup "lógico" para recrear el esquema + datos de prueba
-- (TP - ecommerce_db)
--
-- Orden pensado para restaurar en una DB vacía:
--  1) Tablas
--  2) Índices/constraints auxiliares
--  3) Funciones / triggers / reglas de negocio
--  4) Datos de prueba (sin RLS activo todavía)
--  5) Vistas (+ security_invoker)
--  6) RLS + policies
--  7) GRANTs (permisos por rol)
--
-- Nota:
-- - Los usuarios/roles globales del cluster van en globals.sql.
-- - Este script NO crea la base de datos: restauralo dentro de una DB ya creada.
-- =========================================================



-- ===================== 1) TABLAS =====================
BEGIN;
-- =========================================================
-- TABLAS MAESTRAS DE UBICACION
-- =========================================================
CREATE TABLE Provincia (
  provincia_id SERIAL PRIMARY KEY,
  nombre       VARCHAR(50) NOT NULL
);

CREATE TABLE Ciudad (
  ciudad_id     SERIAL PRIMARY KEY,
  id_provincia  INT NOT NULL REFERENCES Provincia(provincia_id),
  cp            VARCHAR(10) NOT NULL,
  nombre        VARCHAR(50) NOT NULL
);

-- =========================================================
-- USUARIOS Y DIRECCIONES
-- =========================================================
CREATE TABLE Usuario (
  usuario_id  SERIAL PRIMARY KEY,
  db_login    VARCHAR(63) UNIQUE,
  nombre      VARCHAR(50)  NOT NULL,
  apellido    VARCHAR(50)  NOT NULL,
  email       VARCHAR(100) NOT NULL UNIQUE,
  contrasenia VARCHAR(80)  NOT NULL CHECK (length(contrasenia) >= 8),
  rol         VARCHAR(30)  NOT NULL CHECK (rol IN ('admin_app','operador_logistica','operador_comercial','cliente_app'))
);

CREATE TABLE Direccion (
  direccion_id SERIAL PRIMARY KEY,
  id_usuario   INT NOT NULL REFERENCES Usuario(usuario_id),
  id_ciudad    INT NOT NULL REFERENCES Ciudad(ciudad_id),
  calle        VARCHAR(150) NOT NULL
);

-- =========================================================
-- PRODUCTO, PROMOCION, INGRESOS DE STOCK
-- =========================================================
CREATE TABLE Producto (
  producto_id SERIAL PRIMARY KEY,
  nombre      VARCHAR(100) NOT NULL,
  stock       INT NOT NULL CHECK (stock >= 0),
  precio      NUMERIC(10,2) NOT NULL CHECK (precio > 0),
  descripcion VARCHAR(300) NOT NULL
);

CREATE TABLE Promocion (
  promocion_id SERIAL PRIMARY KEY,
  id_producto  INT NOT NULL REFERENCES Producto(producto_id),
  fechaInicio  DATE NOT NULL,
  fechaFin     DATE NOT NULL CHECK (fechaFin >= fechaInicio),
  titulo       VARCHAR(100) NOT NULL,
  descripcion  VARCHAR(300),
  descuento    INT CHECK (descuento BETWEEN 0 AND 100),
  activa       BOOLEAN
);

CREATE TABLE ingresoProducto (
  ingreso_id  SERIAL PRIMARY KEY,
  id_producto INT NOT NULL REFERENCES Producto(producto_id),
  fecha       DATE NOT NULL DEFAULT CURRENT_DATE,
  cant        INT  NOT NULL CHECK (cant > 0)
);

-- =========================================================
-- CARRITO Y SUS LINEAS
-- =========================================================
CREATE TABLE Carrito (
  carrito_id         SERIAL PRIMARY KEY,
  id_usuario         INT NOT NULL REFERENCES Usuario(usuario_id),
  fecha_creacion     DATE NOT NULL,
  fecha_actualizacion DATE NOT NULL CHECK (fecha_actualizacion >= fecha_creacion),
  estado             VARCHAR(15) NOT NULL CHECK (estado IN ('activo','cerrado')),
  total              NUMERIC(10,2) NOT NULL CHECK (total >= 0)
);

CREATE TABLE lineaCarrito (
  id_carrito      INT NOT NULL REFERENCES Carrito(carrito_id) ON DELETE CASCADE,
  id_producto     INT NOT NULL REFERENCES Producto(producto_id),
  fecha_agregado  DATE  NOT NULL DEFAULT CURRENT_DATE,
  cantidad        INT   NOT NULL CHECK (cantidad > 0),
  precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
  subtotal        NUMERIC(10,2) NOT NULL CHECK (subtotal > 0),
  PRIMARY KEY (id_carrito, id_producto)
);

-- =========================================================
-- FAVORITOS Y RESEÑAS
-- =========================================================
CREATE TABLE Favorito (
  id_usuario   INT NOT NULL REFERENCES Usuario(usuario_id) ON DELETE CASCADE,
  id_producto  INT NOT NULL REFERENCES Producto(producto_id) ON DELETE CASCADE,
  fecha_creacion    DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_eliminacion DATE,
  CHECK (fecha_eliminacion IS NULL OR fecha_eliminacion >= fecha_creacion),
  PRIMARY KEY (id_usuario, id_producto)
);

CREATE TABLE Reseña (
  id_usuario  INT NOT NULL REFERENCES Usuario(usuario_id) ON DELETE CASCADE,
  id_producto INT NOT NULL REFERENCES Producto(producto_id) ON DELETE CASCADE,
  calificacion INT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
  comentario   VARCHAR(300),
  fecha        DATE NOT NULL DEFAULT CURRENT_DATE,
  PRIMARY KEY (id_usuario, id_producto)
);

-- =========================================================
-- FACTURACION, LINEAS, PAGOS, ENVIOS
-- =========================================================
CREATE TABLE Factura (
  factura_id   SERIAL PRIMARY KEY,
  id_usuario   INT NOT NULL REFERENCES Usuario(usuario_id),
  fecha        DATE NOT NULL DEFAULT CURRENT_DATE,
  monto_total  NUMERIC(10,2) NOT NULL CHECK (monto_total >= 0),
  estado VARCHAR(10) NOT NULL DEFAULT 'emitida'
);

CREATE TABLE lineaFactura (
  id_factura      INT NOT NULL REFERENCES Factura(factura_id) ON DELETE CASCADE,
  id_producto     INT NOT NULL REFERENCES Producto(producto_id),
  precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
  descuento       INT CHECK (descuento BETWEEN 0 AND 100),
  cantidad        INT NOT NULL CHECK (cantidad > 0),
  subtotal        NUMERIC(10,2) NOT NULL CHECK (subtotal > 0),
  PRIMARY KEY (id_factura, id_producto)
);

CREATE TABLE Pago (
  pago_id    SERIAL PRIMARY KEY,
  id_factura INT NOT NULL REFERENCES Factura(factura_id) ON DELETE CASCADE,
  monto      NUMERIC(10,2) NOT NULL CHECK (monto > 0),
  metodo     VARCHAR(30) NOT NULL CHECK (metodo IN ('mercadopago'))
);

CREATE TABLE Envio (
  envio_id     SERIAL PRIMARY KEY,
  id_direccion INT NOT NULL REFERENCES Direccion(direccion_id),
  id_factura   INT NOT NULL REFERENCES Factura(factura_id) ON DELETE CASCADE,
  estado       VARCHAR(20) NOT NULL CHECK (estado IN ('pendiente','enPreparacion','enCamino','entregado')),
  fechaArribo  DATE,
  fechaEntrega DATE,
  CHECK (fechaEntrega IS NULL OR (fechaArribo IS NOT NULL AND fechaEntrega >= fechaArribo)),
  costoEnvio   NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (costoEnvio >= 0)
);
COMMIT;


-- ===================== 2) ÍNDICES =====================
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

BEGIN

-- Índice para filtrar por facturas por estado
CREATE INDEX IF NOT EXISTS idx_factura_estado ON Factura(estado);

COMMIT;


-- ===================== 3) FUNCIONES / TRIGGERS =====================
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

DROP TRIGGER IF EXISTS trigger_actualizar_stock_ingreso ON ingresoproducto;
CREATE TRIGGER trigger_actualizar_stock_ingreso
    AFTER INSERT ON ingresoproducto
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_stock_ingreso();

-- =========================================================
-- TRIGGERS PARA CARRITO DE COMPRAS
-- =========================================================
-- Observación docente: el precio no debe hardcodearse; debe obtenerse de Producto.
-- Se reemplaza el trigger que calculaba subtotal usando precio_unitario insertado
-- por uno que setea precio_unitario desde Producto y calcula subtotal.

-- NUEVO: setear precio_unitario desde Producto y calcular subtotal en lineaCarrito
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
    NEW.subtotal := NEW.cantidad * NEW.precio_unitario;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_precio_y_subtotal_carrito
    BEFORE INSERT OR UPDATE ON lineacarrito
    FOR EACH ROW
    EXECUTE FUNCTION set_precio_y_subtotal_carrito();

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
-- Observación docente: el precio debe obtenerse desde Producto.
-- Se reemplaza el trigger que calculaba subtotal usando precio_unitario insertado
-- por uno que setea precio_unitario desde Producto y calcula subtotal con descuento.

-- NUEVO: setear precio_unitario desde Producto y calcular subtotal en lineaFactura
CREATE OR REPLACE FUNCTION set_precio_y_subtotal_factura()
RETURNS TRIGGER AS $$
DECLARE
    v_precio NUMERIC(10,2);
    v_precio_final NUMERIC(10,2);
BEGIN
    SELECT precio INTO v_precio
    FROM Producto
    WHERE producto_id = NEW.id_producto;

    IF v_precio IS NULL THEN
        RAISE EXCEPTION 'Producto inexistente: %', NEW.id_producto;
    END IF;

    NEW.precio_unitario := v_precio;

    IF NEW.descuento IS NOT NULL AND NEW.descuento > 0 THEN
        v_precio_final := NEW.precio_unitario * (1 - NEW.descuento::NUMERIC / 100);
    ELSE
        v_precio_final := NEW.precio_unitario;
    END IF;

    NEW.subtotal := v_precio_final * NEW.cantidad;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_precio_y_subtotal_factura
    BEFORE INSERT OR UPDATE ON lineafactura
    FOR EACH ROW
    EXECUTE FUNCTION set_precio_y_subtotal_factura();

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

-- Trigger: Actualizar monto_total de factura
CREATE OR REPLACE FUNCTION actualizar_monto_total_factura()
RETURNS TRIGGER AS $$
DECLARE
    nuevo_monto_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(subtotal), 0) INTO nuevo_monto_total
    FROM lineafactura
    WHERE id_factura = COALESCE(NEW.id_factura, OLD.id_factura);

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

---- BLOQUEO DE MODIFICACIÓN / ELIMINACIÓN DE FACTURAS (la factura es documento; si hay error, se anula, no se edita/borra)
CREATE OR REPLACE FUNCTION bloquear_modificacion_factura()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'No se permite modificar ni eliminar facturas conformadas. Use anulación.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_factura_no_update
BEFORE UPDATE ON Factura
FOR EACH ROW
EXECUTE FUNCTION bloquear_modificacion_factura();

CREATE TRIGGER trg_factura_no_delete
BEFORE DELETE ON Factura
FOR EACH ROW
EXECUTE FUNCTION bloquear_modificacion_factura();

CREATE TRIGGER trg_lineafactura_no_update
BEFORE UPDATE ON lineaFactura
FOR EACH ROW
EXECUTE FUNCTION bloquear_modificacion_factura();

CREATE TRIGGER trg_lineafactura_no_delete
BEFORE DELETE ON lineaFactura
FOR EACH ROW
EXECUTE FUNCTION bloquear_modificacion_factura();

-- =========================================================
-- TRIGGERS PARA ENVÍOS
-- =========================================================

-- Trigger: Validar transición de estados de envío
CREATE OR REPLACE FUNCTION validar_transicion_estado_envio()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado = 'entregado' AND NEW.estado != 'entregado' THEN
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

CREATE TRIGGER trigger_validar_transicion_estado_envio
    BEFORE UPDATE ON envio
    FOR EACH ROW
    EXECUTE FUNCTION validar_transicion_estado_envio();


-- Función anular_factura(p_factura_id, p_motivo) SIN BORRAR
--    - restaura stock (revierte lineafactura)
--    - marca factura como anulada
--    - opcional: registra motivo en un comentario (sin tocar estructura)

CREATE OR REPLACE FUNCTION anular_factura(p_factura_id INT, p_motivo TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    v_estado VARCHAR(10);
BEGIN
    -- Validar existencia y estado
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

    -- Restaurar stock por cada línea de la factura
    UPDATE Producto p
    SET stock = p.stock + lf.cantidad
    FROM lineaFactura lf
    WHERE lf.id_factura = p_factura_id
      AND p.producto_id = lf.id_producto;

    -- Marcar factura como anulada
    UPDATE Factura
    SET estado = 'anulada'
    WHERE factura_id = p_factura_id;

    -- (Opcional) dejar motivo como comentario SQL a nivel fila no existe,
    -- pero podés dejar comentario en la función o crear una tabla de anulaciones.
    -- Acá no guardamos motivo para no cambiar más el modelo.
    IF p_motivo IS NOT NULL THEN
        RAISE NOTICE 'Factura % anulada. Motivo: %', p_factura_id, p_motivo;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION anular_factura(INT, TEXT) IS
'Anula una factura sin borrarla: restaura stock según lineaFactura y marca estado=anulada. No elimina líneas.';

COMMIT;




-- ===================== 4) DATOS DE PRUEBA =====================
BEGIN;

-- =========================================================
-- PROVINCIA (15 filas)
-- =========================================================
INSERT INTO Provincia (nombre) VALUES
('Buenos Aires'),
('Córdoba'),
('Santa Fe'),
('Mendoza'),
('Tucumán'),
('Salta'),
('San Juan'),
('Neuquén'),
('Río Negro'),
('Chubut'),
('Misiones'),
('Entre Ríos'),
('La Pampa'),
('San Luis'),
('Formosa');

-- =========================================================
-- CIUDAD (15 filas)
-- =========================================================
INSERT INTO Ciudad (id_provincia, cp, nombre) VALUES
(1,  '1000', 'CABA'),
(1,  '1704', 'Ramos Mejía'),
(2,  '5000', 'Córdoba Capital'),
(3,  '2000', 'Rosario'),
(4,  '5500', 'Mendoza'),
(5,  '4000', 'San Miguel de Tucumán'),
(6,  '4400', 'Salta'),
(7,  '5400', 'San Juan'),
(8,  '8300', 'Neuquén'),
(9,  '8500', 'Viedma'),
(10, '9000', 'Rawson'),
(11, '3300', 'Posadas'),
(12, '3100', 'Paraná'),
(13, '6300', 'Santa Rosa'),
(14, '5700', 'San Luis');

-- =========================================================
-- USUARIO (15 filas)
-- =========================================================
-- =========================================================
-- USUARIO (15 filas)
-- Nota: db_login mapea el usuario de login del motor (session_user) con Usuario.usuario_id.
--       Solo es obligatorio setearlo para los usuarios de prueba (ana_perez, fernando_rossi,
--       hernan_torres, julian_diaz). El resto puede quedar NULL.
-- =========================================================
INSERT INTO Usuario (db_login, nombre, apellido, email, contrasenia, rol) VALUES
('ana_perez',       'Ana',     'Pérez',    'ana@example.com',      'Password1',   'cliente_app'),
(NULL,              'Bruno',   'García',   'bruno@example.com',    'Password2',   'cliente_app'),
(NULL,              'Carla',   'López',    'carla@example.com',    'Password3',   'cliente_app'),
(NULL,              'Diego',   'Martínez', 'diego@example.com',    'Password4',   'cliente_app'),
(NULL,              'Elena',   'Suárez',   'elena@example.com',    'Password5',   'cliente_app'),
('fernando_rossi',  'Fernando','Rossi',    'fernando@example.com', 'Password6',   'operador_comercial'),
(NULL,              'Gabriela','Santos',   'gabriela@example.com', 'Password7',   'operador_comercial'),
('hernan_torres',   'Hernán',  'Torres',   'hernan@example.com',   'Password8',   'operador_logistica'),
(NULL,              'Inés',    'Moreno',   'ines@example.com',     'Password9',   'operador_logistica'),
('julian_diaz',     'Julián',  'Díaz',     'julian@example.com',   'Password10',  'admin_app'),
(NULL,              'Karen',   'Vega',     'karen@example.com',    'Password11',  'cliente_app'),
(NULL,              'Luis',    'Navarro',  'luis@example.com',     'Password12',  'cliente_app'),
(NULL,              'María',   'Castro',   'maria@example.com',    'Password13',  'cliente_app'),
(NULL,              'Nicolás', 'Ferrer',   'nicolas@example.com',  'Password14',  'cliente_app'),
(NULL,              'Olga',    'Silva',    'olga@example.com',     'Password15',  'cliente_app');


-- usuario_id = 1..15 en este orden

-- =========================================================
-- DIRECCION (15 filas)
-- =========================================================
INSERT INTO Direccion (id_usuario, id_ciudad, calle) VALUES
(1,  1,  'Av. Siempre Viva 123'),
(2,  2,  'Mitre 456'),
(3,  3,  'Colón 789'),
(4,  4,  'San Martín 101'),
(5,  5,  'Rivadavia 202'),
(6,  6,  'Belgrano 303'),
(7,  7,  'Sarmiento 404'),
(8,  8,  'Alsina 505'),
(9,  9,  'Urquiza 606'),
(10, 10, 'Lavalle 707'),
(11, 11, 'French 808'),
(12, 12, '25 de Mayo 909'),
(13, 13, 'España 1001'),
(14, 14, 'Italia 1102'),
(15, 15, 'Brasil 1203');
-- direccion_id = 1..15 en este orden

-- =========================================================
-- PRODUCTO (15 filas)
-- =========================================================
INSERT INTO Producto (nombre, stock, precio, descripcion) VALUES
('Producto 1',  1000, 100.00, 'Descripción producto 1'),
('Producto 2',  1000, 150.00, 'Descripción producto 2'),
('Producto 3',  1000, 200.00, 'Descripción producto 3'),
('Producto 4',  1000, 250.00, 'Descripción producto 4'),
('Producto 5',  1000, 300.00, 'Descripción producto 5'),
('Producto 6',  1000, 350.00, 'Descripción producto 6'),
('Producto 7',  1000, 400.00, 'Descripción producto 7'),
('Producto 8',  1000, 450.00, 'Descripción producto 8'),
('Producto 9',  1000, 500.00, 'Descripción producto 9'),
('Producto 10', 1000, 550.00, 'Descripción producto 10'),
('Producto 11', 1000, 600.00, 'Descripción producto 11'),
('Producto 12', 1000, 650.00, 'Descripción producto 12'),
('Producto 13', 1000, 700.00, 'Descripción producto 13'),
('Producto 14', 1000, 750.00, 'Descripción producto 14'),
('Producto 15', 1000, 800.00, 'Descripción producto 15');
-- producto_id = 1..15

-- =========================================================
-- PROMOCION (15 filas)
-- =========================================================
INSERT INTO Promocion (id_producto, fechaInicio, fechaFin, titulo, descripcion, descuento, activa) VALUES
(1,  '2025-01-01', '2025-12-31', 'Promo 1',  'Descuento producto 1', 10, true),
(2,  '2025-01-01', '2025-03-31', 'Promo 2',  'Descuento producto 2', 15, true),
(3,  '2025-02-01', '2025-05-31', 'Promo 3',  'Descuento producto 3', 5,  true),
(4,  '2025-03-01', '2025-06-30', 'Promo 4',  'Descuento producto 4', 20, false),
(5,  '2025-04-01', '2025-07-31', 'Promo 5',  'Descuento producto 5', 25, true),
(6,  '2025-05-01', '2025-08-31', 'Promo 6',  'Descuento producto 6', 30, true),
(7,  '2025-06-01', '2025-09-30', 'Promo 7',  'Descuento producto 7', 10, false),
(8,  '2025-07-01', '2025-10-31', 'Promo 8',  'Descuento producto 8', 5,  true),
(9,  '2025-08-01', '2025-11-30', 'Promo 9',  'Descuento producto 9', 15, true),
(10, '2025-01-15', '2025-04-15', 'Promo 10', 'Descuento producto 10',20, false),
(11, '2025-02-15', '2025-05-15', 'Promo 11', 'Descuento producto 11',10, true),
(12, '2025-03-15', '2025-06-15', 'Promo 12', 'Descuento producto 12',5,  true),
(13, '2025-04-15', '2025-07-15', 'Promo 13', 'Descuento producto 13',15, false),
(14, '2025-05-15', '2025-08-15', 'Promo 14', 'Descuento producto 14',10, true),
(15, '2025-06-15', '2025-09-15', 'Promo 15', 'Descuento producto 15',20, true);
-- promocion_id = 1..15

-- =========================================================
-- INGRESO PRODUCTO (15 filas) - actualiza stock por trigger
-- =========================================================
INSERT INTO ingresoProducto (id_producto, fecha, cant) VALUES
(1,  '2025-10-01', 100),
(2,  '2025-10-02', 100),
(3,  '2025-10-03', 100),
(4,  '2025-10-04', 100),
(5,  '2025-10-05', 100),
(6,  '2025-10-06', 100),
(7,  '2025-10-07', 100),
(8,  '2025-10-08', 100),
(9,  '2025-10-09', 100),
(10, '2025-10-10', 100),
(11, '2025-10-11', 100),
(12, '2025-10-12', 100),
(13, '2025-10-13', 100),
(14, '2025-10-14', 100),
(15, '2025-10-15', 100);
-- ingreso_id = 1..15

-- =========================================================
-- CARRITO (15 filas, 1 activo por usuario)
-- =========================================================
INSERT INTO Carrito (id_usuario, fecha_creacion, fecha_actualizacion, estado, total) VALUES
(1,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(2,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(3,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(4,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(5,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(6,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(7,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(8,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(9,  '2025-10-01', '2025-10-01', 'activo',   0.00),
(10, '2025-10-01', '2025-10-01', 'activo',   0.00),
(1,  '2025-09-01', '2025-09-15', 'cerrado',  500.00),
(2,  '2025-09-02', '2025-09-16', 'cerrado',  750.00),
(3,  '2025-09-03', '2025-09-17', 'cerrado',  900.00),
(4,  '2025-09-04', '2025-09-18', 'cerrado', 1200.00),
(5,  '2025-09-05', '2025-09-19', 'cerrado', 1500.00);
-- carrito_id = 1..15 en este orden

-- =========================================================
-- LINEA CARRITO (15 filas, solo carritos activos 1..10)
-- Ahora el trigger set_precio_y_subtotal_carrito setea precio_unitario y subtotal.
-- Por eso:
--   - NO insertamos precio_unitario
--   - SÍ insertamos subtotal (pero es NOT NULL), entonces lo seteamos dummy 0 y el trigger lo recalcula
--     (el trigger BEFORE INSERT pisa NEW.subtotal).
-- =========================================================
INSERT INTO lineaCarrito (id_carrito, id_producto, fecha_agregado, cantidad, precio_unitario, subtotal) VALUES
(1,  1,  '2025-10-02', 2, 0.00, 0.00),
(1,  2,  '2025-10-02', 1, 0.00, 0.00),
(2,  3,  '2025-10-03', 3, 0.00, 0.00),
(2,  4,  '2025-10-03', 1, 0.00, 0.00),
(3,  5,  '2025-10-04', 2, 0.00, 0.00),
(3,  6,  '2025-10-04', 1, 0.00, 0.00),
(4,  7,  '2025-10-05', 1, 0.00, 0.00),
(4,  8,  '2025-10-05', 2, 0.00, 0.00),
(5,  9,  '2025-10-06', 1, 0.00, 0.00),
(5,  10, '2025-10-06', 1, 0.00, 0.00),
(6,  11, '2025-10-07', 2, 0.00, 0.00),
(7,  12, '2025-10-08', 1, 0.00, 0.00),
(8,  13, '2025-10-09', 1, 0.00, 0.00),
(9,  14, '2025-10-10', 2, 0.00, 0.00),
(10, 15, '2025-10-11', 1, 0.00, 0.00);

-- =========================================================
-- FAVORITO (15 filas)
-- =========================================================
INSERT INTO Favorito (id_usuario, id_producto, fecha_creacion, fecha_eliminacion) VALUES
(1,  1,  '2025-09-01', NULL),
(1,  2,  '2025-09-02', NULL),
(2,  3,  '2025-09-03', NULL),
(2,  4,  '2025-09-04', '2025-09-20'),
(3,  5,  '2025-09-05', NULL),
(3,  6,  '2025-09-06', NULL),
(4,  7,  '2025-09-07', NULL),
(4,  8,  '2025-09-08', NULL),
(5,  9,  '2025-09-09', NULL),
(6,  10, '2025-09-10', NULL),
(7,  11, '2025-09-11', NULL),
(8,  12, '2025-09-12', NULL),
(9,  13, '2025-09-13', NULL),
(10, 14, '2025-09-14', NULL),
(11, 15, '2025-09-15', NULL);

-- =========================================================
-- RESEÑA (15 filas)
-- =========================================================
INSERT INTO Reseña (id_usuario, id_producto, calificacion, comentario, fecha) VALUES
(1,  1, 5, 'Excelente producto',           '2025-09-10'),
(1,  2, 4, 'Muy bueno',                    '2025-09-11'),
(2,  3, 3, 'Aceptable',                    '2025-09-12'),
(2,  4, 4, 'Cumple con lo esperado',       '2025-09-13'),
(3,  5, 5, 'Me encantó',                   '2025-09-14'),
(3,  6, 2, 'Podría ser mejor',             '2025-09-15'),
(4,  7, 4, 'Buen rendimiento',             '2025-09-16'),
(5,  8, 5, 'Lo volvería a comprar',        '2025-09-17'),
(6,  9, 3, 'Calidad promedio',             '2025-09-18'),
(7,  10,4, 'Buen precio-calidad',          '2025-09-19'),
(8,  11,5, 'Excelente relación calidad',   '2025-09-20'),
(9,  12,4, 'Muy conforme',                 '2025-09-21'),
(10, 13,5, 'Producto destacado',           '2025-09-22'),
(11, 14,3, 'Está bien',                    '2025-09-23'),
(12, 15,4, 'Recomendable',                 '2025-09-24');

-- =========================================================
-- FACTURA (15 filas)
-- Ahora Factura tiene estado (emitida/anulada).
-- Si no lo incluís, toma DEFAULT 'emitida'. Lo dejamos explícito.
-- monto_total comienza en 0 y se recalcula al insertar lineaFactura.
-- =========================================================
INSERT INTO Factura (id_usuario, fecha, monto_total, estado) VALUES
(1,  '2025-11-01', 0.00, 'emitida'),
(2,  '2025-11-01', 0.00, 'emitida'),
(3,  '2025-11-02', 0.00, 'emitida'),
(4,  '2025-11-02', 0.00, 'emitida'),
(5,  '2025-11-03', 0.00, 'emitida'),
(6,  '2025-11-03', 0.00, 'emitida'),
(7,  '2025-11-04', 0.00, 'emitida'),
(8,  '2025-11-04', 0.00, 'emitida'),
(9,  '2025-11-05', 0.00, 'emitida'),
(10, '2025-11-05', 0.00, 'emitida'),
(11, '2025-11-06', 0.00, 'emitida'),
(12, '2025-11-06', 0.00, 'emitida'),
(13, '2025-11-07', 0.00, 'emitida'),
(14, '2025-11-07', 0.00, 'emitida'),
(15, '2025-11-08', 0.00, 'emitida');
-- factura_id = 1..15

-- =========================================================
-- LINEA FACTURA (15 filas)
-- Ahora el trigger set_precio_y_subtotal_factura setea precio_unitario y subtotal.
-- Además, tu modelo exige NOT NULL en precio_unitario y subtotal.
-- Por eso:
--   - insertamos precio_unitario y subtotal como 0.00 (valores dummy)
--   - el trigger BEFORE INSERT los pisa con el precio real y el subtotal calculado
-- =========================================================
INSERT INTO lineaFactura (id_factura, id_producto, precio_unitario, descuento, cantidad, subtotal) VALUES
(1,  1,  0.00, 0,  2, 0.00),
(2,  2,  0.00, 10, 3, 0.00),
(3,  3,  0.00, 0,  1, 0.00),
(4,  4,  0.00, 15, 4, 0.00),
(5,  5,  0.00, 0,  2, 0.00),
(6,  6,  0.00, 5,  5, 0.00),
(7,  7,  0.00, 0,  3, 0.00),
(8,  8,  0.00, 20, 2, 0.00),
(9,  9,  0.00, 0,  1, 0.00),
(10, 10, 0.00, 0,  4, 0.00),
(11, 11, 0.00, 0,  2, 0.00),
(12, 12, 0.00, 0,  3, 0.00),
(13, 13, 0.00, 5,  1, 0.00),
(14, 14, 0.00, 0,  2, 0.00),
(15, 15, 0.00, 15, 3, 0.00);

-- =========================================================
-- PAGO (15 filas)
-- IMPORTANTE: validar_pago_total_factura exige que el pago sea EXACTAMENTE el monto_total.
-- Como monto_total lo recalcula el trigger en lineaFactura, NO hardcodeamos montos:
-- los insertamos desde la BD con un SELECT.
-- =========================================================
INSERT INTO Pago (id_factura, monto, metodo)
SELECT f.factura_id, f.monto_total, 'mercadopago'
FROM Factura f
ORDER BY f.factura_id;

-- =========================================================
-- ENVIO (15 filas, 1 por factura)
-- =========================================================
INSERT INTO Envio (id_direccion, id_factura, estado, fechaArribo, fechaEntrega, costoEnvio) VALUES
(1,  1,  'pendiente',     NULL,        NULL,        0.00),
(2,  2,  'enPreparacion', NULL,        NULL,        500.00),
(3,  3,  'enCamino',      '2025-11-03',NULL,        600.00),
(4,  4,  'entregado',     '2025-11-02','2025-11-05',700.00),
(5,  5,  'pendiente',     NULL,        NULL,        400.00),
(6,  6,  'enPreparacion', NULL,        NULL,        450.00),
(7,  7,  'enCamino',      '2025-11-04',NULL,        550.00),
(8,  8,  'entregado',     '2025-11-04','2025-11-06',650.00),
(9,  9,  'pendiente',     NULL,        NULL,        350.00),
(10, 10, 'enPreparacion', NULL,        NULL,        380.00),
(11, 11, 'enCamino',      '2025-11-06',NULL,        420.00),
(12, 12, 'entregado',     '2025-11-06','2025-11-08',460.00),
(13, 13, 'pendiente',     NULL,        NULL,        300.00),
(14, 14, 'enCamino',      '2025-11-07',NULL,        320.00),
(15, 15, 'entregado',     '2025-11-08','2025-11-10',500.00);

COMMIT;


-- ===================== 5) VISTAS =====================
-- Views
BEGIN;

-- =========================================================
-- VISTAS DE USUARIOS (Ocultar contraseñas)
-- =========================================================

-- Vista: Usuarios sin contraseña (para operadores y clientes)
CREATE OR REPLACE VIEW v_usuario_publico AS
SELECT 
    usuario_id,
    nombre,
    apellido,
    email,
    rol
FROM Usuario;

COMMENT ON VIEW v_usuario_publico IS 
'Vista de usuarios sin información sensible. Oculta la contraseña.';

-- Vista: Perfil de usuario completo (para que el cliente vea su propio perfil)
CREATE OR REPLACE VIEW v_perfil_usuario AS
SELECT 
    u.usuario_id,
    u.nombre,
    u.apellido,
    u.email,
    u.rol,
    COUNT(DISTINCT c.carrito_id) AS total_carritos,
    COUNT(DISTINCT f.factura_id) AS total_facturas,
    COUNT(DISTINCT fav.id_producto) AS total_favoritos,
    COUNT(DISTINCT r.id_producto) AS total_resenas
FROM Usuario u
LEFT JOIN Carrito c ON u.usuario_id = c.id_usuario
LEFT JOIN Factura f ON u.usuario_id = f.id_usuario
LEFT JOIN Favorito fav ON u.usuario_id = fav.id_usuario AND fav.fecha_eliminacion IS NULL
LEFT JOIN Reseña r ON u.usuario_id = r.id_usuario
GROUP BY u.usuario_id, u.nombre, u.apellido, u.email, u.rol;

COMMENT ON VIEW v_perfil_usuario IS 
'Vista con estadísticas del perfil de usuario. Sin contraseña.';

-- =========================================================
-- VISTAS DE PRODUCTOS
-- =========================================================

-- Vista: Catálogo de productos para clientes (con promociones activas)
CREATE OR REPLACE VIEW v_catalogo_productos AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    p.descripcion,
    p.stock,
    -- Precio con descuento (redondeado a 2 decimales)
    CASE 
        WHEN prom.activa = true 
             AND prom.fechaInicio <= CURRENT_DATE 
             AND prom.fechaFin >= CURRENT_DATE 
             AND prom.descuento IS NOT NULL
        THEN ROUND(p.precio * (1 - prom.descuento::NUMERIC / 100), 2)
        ELSE p.precio
    END AS precio_final,
    prom.promocion_id,
    prom.titulo AS promocion_titulo,
    prom.descuento AS promocion_descuento,
    prom.fechaFin AS promocion_fecha_fin,
    ROUND(COALESCE(AVG(r.calificacion), 0), 2) AS calificacion_promedio,
    COUNT(DISTINCT r.id_usuario) AS total_resenas
FROM Producto p
LEFT JOIN Promocion prom ON p.producto_id = prom.id_producto
LEFT JOIN Reseña r ON p.producto_id = r.id_producto
WHERE p.stock > 0
GROUP BY 
    p.producto_id, p.nombre, p.precio, p.descripcion, p.stock,
    prom.promocion_id, prom.titulo, prom.descuento, prom.fechaFin, prom.activa,
    prom.fechaInicio, prom.fechaFin;

COMMENT ON VIEW v_catalogo_productos IS 
'Catálogo de productos con promociones activas y calificaciones. Para clientes.';

-- Vista: Productos con información de stock para operadores
CREATE OR REPLACE VIEW v_productos_stock AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    p.stock,
    p.descripcion,
    -- Total de ingresos
    COALESCE(SUM(ip.cant), 0) AS total_ingresos,
    -- Último ingreso
    MAX(ip.fecha) AS ultimo_ingreso,
    -- Promociones activas
    COUNT(DISTINCT CASE 
        WHEN prom.activa = true 
             AND prom.fechaInicio <= CURRENT_DATE 
             AND prom.fechaFin >= CURRENT_DATE 
        THEN prom.promocion_id 
    END) AS promociones_activas,
    -- Total en carritos activos
    COALESCE(SUM(lc.cantidad), 0) AS cantidad_en_carritos
FROM Producto p
LEFT JOIN ingresoProducto ip ON p.producto_id = ip.id_producto
LEFT JOIN Promocion prom ON p.producto_id = prom.id_producto
LEFT JOIN lineaCarrito lc ON p.producto_id = lc.id_producto
LEFT JOIN Carrito c ON lc.id_carrito = c.carrito_id AND c.estado = 'activo'
GROUP BY p.producto_id, p.nombre, p.precio, p.stock, p.descripcion;

COMMENT ON VIEW v_productos_stock IS 
'Vista de productos con información detallada de stock e ingresos. Para operadores.';

-- Vista: Productos con stock bajo (alerta)
CREATE OR REPLACE VIEW v_productos_stock_bajo AS
SELECT 
    producto_id,
    nombre,
    stock,
    precio,
    CASE 
        WHEN stock = 0 THEN 'Sin stock'
        WHEN stock < 10 THEN 'Stock muy bajo'
        WHEN stock < 50 THEN 'Stock bajo'
    END AS nivel_alerta
FROM Producto
WHERE stock < 50
ORDER BY stock ASC;

COMMENT ON VIEW v_productos_stock_bajo IS 
'Productos con stock bajo o sin stock. Para alertas de inventario.';

-- =========================================================
-- VISTAS DE CARRITOS
-- =========================================================

-- Vista: Carritos activos con información del cliente
CREATE OR REPLACE VIEW v_carritos_activos AS
SELECT 
    c.carrito_id,
    c.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    u.email,
    c.fecha_creacion,
    c.fecha_actualizacion,
    c.total,
    COUNT(lc.id_producto) AS cantidad_productos,
    SUM(lc.cantidad) AS total_items
FROM Carrito c
JOIN Usuario u ON c.id_usuario = u.usuario_id
LEFT JOIN lineaCarrito lc ON c.carrito_id = lc.id_carrito
WHERE c.estado = 'activo'
GROUP BY c.carrito_id, c.id_usuario, u.nombre, u.apellido, u.email, 
         c.fecha_creacion, c.fecha_actualizacion, c.total;

COMMENT ON VIEW v_carritos_activos IS 
'Carritos activos con información del cliente. Para análisis comercial.';

-- Vista: Detalle de carrito con productos
CREATE OR REPLACE VIEW v_detalle_carrito AS
SELECT 
    c.carrito_id,
    c.id_usuario,
    c.estado,
    c.total AS total_carrito,
    lc.id_producto,
    p.nombre AS nombre_producto,
    lc.cantidad,
    lc.precio_unitario,
    lc.subtotal,
    lc.fecha_agregado
FROM Carrito c
JOIN lineaCarrito lc ON c.carrito_id = lc.id_carrito
JOIN Producto p ON lc.id_producto = p.producto_id;

COMMENT ON VIEW v_detalle_carrito IS 
'Detalle completo de carritos con información de productos.';

-- =========================================================
-- VISTAS DE FACTURAS
-- =========================================================

-- Vista: Facturas con información del cliente

CREATE OR REPLACE VIEW v_facturas_completas AS
SELECT 
    f.factura_id,
    f.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    u.email,
    f.fecha,
    f.monto_total,
    -- Cantidad de productos (subconsulta para evitar duplicación)
    COALESCE((
        SELECT COUNT(*)
        FROM lineaFactura lf
        WHERE lf.id_factura = f.factura_id
    ), 0) AS cantidad_productos,
    -- Información de pago (simplificado: solo hay un pago o ninguno)
    COALESCE(p.monto, 0) AS monto_pagado,
    -- Estado de pago: Pagado o Pendiente
    CASE 
        WHEN p.pago_id IS NOT NULL THEN 'Pagado'
        ELSE 'Pendiente'
    END AS estado_pago,
    -- Información del pago
    p.pago_id,
    p.metodo AS metodo_pago,
    -- Información de envío
    e.envio_id,
    e.estado AS estado_envio,
    e.fechaArribo,
    e.fechaEntrega
FROM Factura f
JOIN Usuario u ON f.id_usuario = u.usuario_id
LEFT JOIN Pago p ON f.factura_id = p.id_factura
LEFT JOIN Envio e ON f.factura_id = e.id_factura;

COMMENT ON VIEW v_facturas_completas IS 
'Facturas con información completa: cliente, pagos y envíos. Solo se permiten pagos del monto total completo.';


-- Vista: Detalle de factura con productos
CREATE OR REPLACE VIEW v_detalle_factura AS
SELECT 
    f.factura_id,
    f.id_usuario,
    f.fecha,
    f.monto_total,
    lf.id_producto,
    p.nombre AS nombre_producto,
    lf.cantidad,
    lf.precio_unitario,
    lf.descuento,
    lf.subtotal
FROM Factura f
JOIN lineaFactura lf ON f.factura_id = lf.id_factura
JOIN Producto p ON lf.id_producto = p.producto_id;

COMMENT ON VIEW v_detalle_factura IS 
'Detalle de facturas con información de productos y descuentos.';

-- =========================================================
-- VISTAS DE ENVÍOS
-- =========================================================

-- Vista: Envíos pendientes para logística
CREATE OR REPLACE VIEW v_envios_pendientes AS
SELECT 
    e.envio_id,
    e.estado,
    e.fechaArribo,
    e.fechaEntrega,
    e.costoEnvio,
    f.factura_id,
    f.fecha AS fecha_factura,
    f.monto_total,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    u.email,
    d.calle,
    ci.nombre AS ciudad,
    ci.cp,
    prov.nombre AS provincia
FROM Envio e
JOIN Factura f ON e.id_factura = f.factura_id
JOIN Usuario u ON f.id_usuario = u.usuario_id
JOIN Direccion d ON e.id_direccion = d.direccion_id
JOIN Ciudad ci ON d.id_ciudad = ci.ciudad_id
JOIN Provincia prov ON ci.id_provincia = prov.provincia_id
WHERE e.estado IN ('pendiente', 'enPreparacion', 'enCamino')
ORDER BY 
    CASE e.estado
        WHEN 'pendiente' THEN 1
        WHEN 'enPreparacion' THEN 2
        WHEN 'enCamino' THEN 3
    END,
    f.fecha ASC;

COMMENT ON VIEW v_envios_pendientes IS 
'Envíos pendientes con información completa de cliente y dirección. Para logística.';

-- Vista: Envíos del cliente (sin información sensible de otros)
CREATE OR REPLACE VIEW v_mis_envios AS
SELECT 
    e.envio_id,
    e.estado,
    e.fechaArribo,
    e.fechaEntrega,
    e.costoEnvio,
    f.factura_id,
    f.fecha AS fecha_factura,
    f.monto_total,
    d.calle,
    ci.nombre AS ciudad,
    ci.cp,
    prov.nombre AS provincia
FROM Envio e
JOIN Factura f ON e.id_factura = f.factura_id
JOIN Direccion d ON e.id_direccion = d.direccion_id
JOIN Ciudad ci ON d.id_ciudad = ci.ciudad_id
JOIN Provincia prov ON ci.id_provincia = prov.provincia_id;

COMMENT ON VIEW v_mis_envios IS 
'Envíos del cliente. Usar con RLS para filtrar por usuario.';

-- =========================================================
-- VISTAS DE REPORTES Y ANÁLISIS
-- =========================================================

-- Vista: Ventas por producto
CREATE OR REPLACE VIEW v_ventas_producto AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    COUNT(DISTINCT lf.id_factura) AS total_ventas,
    SUM(lf.cantidad) AS unidades_vendidas,
    SUM(lf.subtotal) AS ingresos_totales,
    ROUND(AVG(lf.precio_unitario), 2) AS precio_promedio
FROM Producto p
JOIN lineaFactura lf ON p.producto_id = lf.id_producto
JOIN Factura f ON lf.id_factura = f.factura_id
GROUP BY p.producto_id, p.nombre, p.precio
ORDER BY ingresos_totales DESC;

COMMENT ON VIEW v_ventas_producto IS 
'Reporte de ventas por producto. Para análisis comercial.';

-- Vista: Reseñas con información del producto
CREATE OR REPLACE VIEW v_resenas_productos AS
SELECT 
    r.id_producto,
    p.nombre AS nombre_producto,
    r.id_usuario,
    u.nombre || ' ' || u.apellido AS nombre_cliente,
    r.calificacion,
    r.comentario,
    r.fecha,
    -- Calificación promedio del producto (redondeada a 2 decimales)
    ROUND(AVG(r.calificacion) OVER (PARTITION BY r.id_producto), 2) AS calificacion_promedio
FROM Reseña r
JOIN Producto p ON r.id_producto = p.producto_id
JOIN Usuario u ON r.id_usuario = u.usuario_id
ORDER BY r.fecha DESC;

COMMENT ON VIEW v_resenas_productos IS 
'Reseñas con información del producto y cliente.';

-- Vista: Productos más favoritos
CREATE OR REPLACE VIEW v_productos_populares AS
SELECT 
    p.producto_id,
    p.nombre,
    p.precio,
    COUNT(DISTINCT fav.id_usuario) AS total_favoritos,
    COUNT(DISTINCT CASE WHEN fav.fecha_eliminacion IS NULL THEN fav.id_usuario END) AS favoritos_activos
FROM Producto p
LEFT JOIN Favorito fav ON p.producto_id = fav.id_producto
GROUP BY p.producto_id, p.nombre, p.precio
HAVING COUNT(DISTINCT CASE WHEN fav.fecha_eliminacion IS NULL THEN fav.id_usuario END) > 0
ORDER BY favoritos_activos DESC;

COMMENT ON VIEW v_productos_populares IS 
'Productos más agregados a favoritos. Para análisis comercial.';


-- =========================================================
-- SEGURIDAD DE VISTAS (RLS)
-- =========================================================
-- Para que RLS se aplique usando la identidad del usuario que consulta,
-- marcamos estas vistas como security_invoker. Evita que, si la vista es
-- propiedad de un rol con BYPASSRLS (ej: postgres/superuser), se filtren mal.
ALTER VIEW v_perfil_usuario     SET (security_invoker = true);
ALTER VIEW v_carritos_activos   SET (security_invoker = true);
ALTER VIEW v_detalle_carrito    SET (security_invoker = true);
ALTER VIEW v_mis_envios         SET (security_invoker = true);
ALTER VIEW v_detalle_factura    SET (security_invoker = true);
ALTER VIEW v_facturas_completas SET (security_invoker = true);

-- =========================================================
-- OTORGAR PERMISOS EN VISTAS
-- =========================================================

-- Clientes: Solo vistas públicas
GRANT SELECT ON v_usuario_publico TO cliente_app;
GRANT SELECT ON v_perfil_usuario TO cliente_app;
GRANT SELECT ON v_catalogo_productos TO cliente_app;
GRANT SELECT ON v_detalle_carrito TO cliente_app;
GRANT SELECT ON v_detalle_factura TO cliente_app;
GRANT SELECT ON v_facturas_completas TO cliente_app;
GRANT SELECT ON v_carritos_activos TO cliente_app;
GRANT SELECT ON v_mis_envios TO cliente_app;
GRANT SELECT ON v_resenas_productos TO cliente_app;

-- Operador Comercial: Vistas de análisis y productos
GRANT SELECT ON v_usuario_publico TO operador_comercial;
GRANT SELECT ON v_perfil_usuario TO operador_comercial;
GRANT SELECT ON v_catalogo_productos TO operador_comercial;
GRANT SELECT ON v_productos_stock TO operador_comercial;
GRANT SELECT ON v_productos_stock_bajo TO operador_comercial;
GRANT SELECT ON v_carritos_activos TO operador_comercial;
GRANT SELECT ON v_detalle_carrito TO operador_comercial;
GRANT SELECT ON v_facturas_completas TO operador_comercial;
GRANT SELECT ON v_detalle_factura TO operador_comercial;
GRANT SELECT ON v_envios_pendientes TO operador_comercial;
GRANT SELECT ON v_ventas_producto TO operador_comercial;
GRANT SELECT ON v_resenas_productos TO operador_comercial;
GRANT SELECT ON v_productos_populares TO operador_comercial;

-- Operador Logística: Vistas de stock y envíos
GRANT SELECT ON v_usuario_publico TO operador_logistica;
GRANT SELECT ON v_productos_stock TO operador_logistica;
GRANT SELECT ON v_productos_stock_bajo TO operador_logistica;
GRANT SELECT ON v_envios_pendientes TO operador_logistica;
GRANT SELECT ON v_facturas_completas TO operador_logistica;
GRANT SELECT ON v_detalle_factura TO operador_logistica;

-- Administrador: Todas las vistas
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_app;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_app;

COMMIT;


-- ===================== 6) RLS =====================
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
-- Las expresiones clave en una POLICY son:
--
-- 1) USING (condición)
--    - Define qué filas son "visibles" o "alcanzables" por la operación.
--    - En SELECT: filtra las filas que el rol puede ver.
--    - En UPDATE/DELETE: limita qué filas pueden actualizarse o eliminarse.
--    - Ejemplo del TP: en Usuario, USING (usuario_id = current_user_id())
--      permite operar solo sobre la fila del usuario autenticado.
--
-- 2) WITH CHECK (condición)
--    - Define qué filas se permiten INSERTAR o cómo debe quedar una fila luego de un UPDATE.
--    - En INSERT: obliga a que la fila nueva cumpla la condición.
--    - En UPDATE: obliga a que la fila resultante (NEW) siga cumpliendo la condición.
--    - Ejemplo del TP: en Usuario, WITH CHECK (usuario_id=current_user_id() AND rol='cliente_app')
--      evita que un cliente cambie su rol o "mueva" la fila a otro usuario.
--
-- Además, el usuario autenticado se representa con una variable de sesión:
--   SET app.user_id = '123';
-- La función current_user_id() lee esa variable. Si no está seteada o no es válida,
-- devuelve NULL y las policies tienden a bloquear el acceso (comportamiento seguro).
-- =========================================================

-- =========================================================
-- 1. FUNCIÓN PARA OBTENER EL USUARIO ACTUAL
-- =========================================================
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id INTEGER;
    v_app_user TEXT;
BEGIN
    -- 1) Si la app seteó app.user_id, lo usamos (modo "API")
    v_app_user := current_setting('app.user_id', true);
    IF v_app_user IS NOT NULL AND v_app_user <> '' THEN
        BEGIN
            v_user_id := v_app_user::INTEGER;
            RETURN v_user_id;
        EXCEPTION
            WHEN OTHERS THEN
                -- Si no castea, seguimos al fallback por db_login
                NULL;
        END;
    END IF;

    -- 2) Fallback: mapear session_user -> Usuario.db_login (modo "pgAdmin / conexión por usuario")
    SELECT u.usuario_id
      INTO v_user_id
    FROM Usuario u
    WHERE u.db_login = session_user
    LIMIT 1;

    RETURN v_user_id; -- puede ser NULL si no está mapeado
END;
$$;

COMMENT ON FUNCTION current_user_id() IS
'Retorna el usuario_id del usuario autenticado. Prioriza app.user_id (si está seteado) y, si no, mapea session_user -> Usuario.db_login. Si no puede resolver, retorna NULL para que RLS bloquee.';

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

CREATE POLICY lineacarrito_select_own ON lineaCarrito
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    );

CREATE POLICY lineacarrito_insert_own ON lineaCarrito
    FOR INSERT
    TO cliente_app
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    );

CREATE POLICY lineacarrito_update_own ON lineaCarrito
    FOR UPDATE
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM Carrito
            WHERE Carrito.carrito_id = lineaCarrito.id_carrito
              AND Carrito.id_usuario = current_user_id()
        )
    );

CREATE POLICY lineacarrito_delete_own ON lineaCarrito
    FOR DELETE
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Carrito
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

CREATE POLICY factura_select_own ON Factura
    FOR SELECT
    TO cliente_app
    USING (id_usuario = current_user_id());

COMMENT ON POLICY factura_select_own ON Factura IS
'Permite a los clientes ver solo sus propias facturas.';

-- =========================================================
-- 10. POLÍTICAS RLS PARA TABLA lineaFactura
-- =========================================================

CREATE POLICY lineafactura_select_own ON lineaFactura
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Factura
            WHERE Factura.factura_id = lineaFactura.id_factura
              AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY lineafactura_select_own ON lineaFactura IS
'Permite a los clientes ver solo líneas de sus propias facturas.';

-- =========================================================
-- 11. POLÍTICAS RLS PARA TABLA Pago
-- =========================================================

CREATE POLICY pago_select_own ON Pago
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Factura
            WHERE Factura.factura_id = Pago.id_factura
              AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY pago_select_own ON Pago IS
'Permite a los clientes ver solo pagos de sus propias facturas.';

-- =========================================================
-- 12. POLÍTICAS RLS PARA TABLA Envio
-- =========================================================

CREATE POLICY envio_select_own ON Envio
    FOR SELECT
    TO cliente_app
    USING (
        EXISTS (
            SELECT 1 FROM Factura
            WHERE Factura.factura_id = Envio.id_factura
              AND Factura.id_usuario = current_user_id()
        )
    );

COMMENT ON POLICY envio_select_own ON Envio IS
'Permite a los clientes ver solo envíos de sus propias facturas.';

-- =========================================================
-- POLÍTICAS RLS PARA admin_app (ACCESO COMPLETO)
-- =========================================================

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

COMMIT;



-- ===================== 7) GRANTS POR ROL =====================
-- =========================================================
-- ROLES Y PERMISOS (PostgreSQL) - Versión corregida + permiso anular_factura()
-- =========================================================
-- Nota: el permiso EXECUTE sobre anular_factura se restringe solo a admin_app
--       (se revoca de PUBLIC por seguridad).
--
-- IMPORTANTE: este bloque asume que la función ya existe:
--   CREATE OR REPLACE FUNCTION anular_factura(p_factura_id INT, p_motivo TEXT DEFAULT NULL)

-- =========================================================
-- 1) ADMIN_APP - Administrador de la aplicación
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_app') THEN
        CREATE ROLE admin_app NOLOGIN;
    END IF;
END $$;

GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES    TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO admin_app;

-- =========================================================
-- 2) OPERADOR_COMERCIAL - Catálogo / promociones / análisis
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operador_comercial') THEN
        CREATE ROLE operador_comercial NOLOGIN;
    END IF;
END $$;

GRANT SELECT ON Provincia TO operador_comercial;
GRANT SELECT ON Ciudad    TO operador_comercial;

GRANT SELECT, INSERT, UPDATE, DELETE ON Producto TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE producto_producto_id_seq TO operador_comercial;

GRANT SELECT, INSERT, UPDATE, DELETE ON Promocion TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE promocion_promocion_id_seq TO operador_comercial;

GRANT SELECT ON ingresoProducto TO operador_comercial;
GRANT SELECT ON Reseña          TO operador_comercial;
GRANT SELECT ON Usuario         TO operador_comercial;
GRANT SELECT ON Carrito         TO operador_comercial;
GRANT SELECT ON lineaCarrito    TO operador_comercial;
GRANT SELECT ON Factura         TO operador_comercial;
GRANT SELECT ON lineaFactura    TO operador_comercial;
GRANT SELECT ON Pago            TO operador_comercial;
GRANT SELECT ON Envio           TO operador_comercial;
GRANT SELECT ON Favorito        TO operador_comercial;

-- =========================================================
-- 3) OPERADOR_LOGISTICA - Stock / ingresos / envíos
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operador_logistica') THEN
        CREATE ROLE operador_logistica NOLOGIN;
    END IF;
END $$;

GRANT SELECT ON Provincia TO operador_logistica;
GRANT SELECT ON Ciudad    TO operador_logistica;

GRANT SELECT        ON Producto TO operador_logistica;
GRANT UPDATE(stock) ON Producto TO operador_logistica;

GRANT SELECT, INSERT, UPDATE, DELETE ON ingresoProducto TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE ingresoproducto_ingreso_id_seq TO operador_logistica;

GRANT SELECT, INSERT, UPDATE, DELETE ON Envio TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE envio_envio_id_seq TO operador_logistica;

GRANT SELECT ON Direccion   TO operador_logistica;
GRANT SELECT ON Factura     TO operador_logistica;
GRANT SELECT ON lineaFactura TO operador_logistica;
GRANT SELECT ON Pago          TO operador_logistica;
GRANT SELECT ON Usuario     TO operador_logistica;
GRANT SELECT ON Carrito     TO operador_logistica;
GRANT SELECT ON lineaCarrito TO operador_logistica;

-- =========================================================
-- 4) CLIENTE_APP - Cliente de la aplicación
-- =========================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cliente_app') THEN
        CREATE ROLE cliente_app NOLOGIN;
    END IF;
END $$;

GRANT SELECT ON Provincia TO cliente_app;
GRANT SELECT ON Ciudad    TO cliente_app;

GRANT SELECT, UPDATE ON Usuario TO cliente_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON Direccion TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE direccion_direccion_id_seq TO cliente_app;

GRANT SELECT ON Producto  TO cliente_app;
GRANT SELECT ON Promocion TO cliente_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON Carrito TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE carrito_carrito_id_seq TO cliente_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON lineaCarrito TO cliente_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON Favorito    TO cliente_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON Reseña      TO cliente_app;

GRANT SELECT ON Factura      TO cliente_app;
GRANT SELECT ON lineaFactura TO cliente_app;

GRANT SELECT ON Pago  TO cliente_app;
GRANT SELECT ON Envio TO cliente_app;

-- =========================================================
-- PERMISOS ESPECÍFICOS PARA FUNCIÓN DE NEGOCIO: anular_factura()
-- =========================================================
-- Seguridad: por defecto, cualquiera podría ejecutar funciones si tiene USAGE/EXECUTE heredado.
-- Restringimos explícitamente esta función: solo admin_app puede anular facturas.

REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM cliente_app;
REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM operador_comercial;
REVOKE ALL ON FUNCTION anular_factura(INT, TEXT) FROM operador_logistica;

GRANT EXECUTE ON FUNCTION anular_factura(INT, TEXT) TO admin_app;

-- =========================================================
-- FIN
-- =========================================================


