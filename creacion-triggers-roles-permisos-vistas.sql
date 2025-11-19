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
  monto_total  NUMERIC(10,2) NOT NULL CHECK (monto_total >= 0)
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
BEGIN
    UPDATE producto
    SET stock = stock - NEW.cantidad
    WHERE producto_id = NEW.id_producto;
    
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

-- Indices
-- indice para asegurar que un usuario tenga solo un carrito activo a la vez
CREATE UNIQUE INDEX idx_carrito_unico_activo 
ON carrito (id_usuario) 
WHERE estado = 'activo';

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

-- Roles y permisos
BEGIN;

-- =========================================================
-- 1. ADMIN_APP - Administrador de la aplicación
-- =========================================================
-- Permisos: Acceso completo a todas las tablas
-- Responsabilidades: Gestión total del sistema

-- Crear rol si no existe (PostgreSQL)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_app') THEN
        CREATE ROLE admin_app;
    END IF;
END $$;

-- Permisos completos en todas las tablas
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_app;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_app;

-- Permisos futuros
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO admin_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO admin_app;

-- =========================================================
-- 2. OPERADOR_COMERCIAL - Operador comercial
-- =========================================================
-- Permisos: Gestión de productos, promociones, reseñas
-- Responsabilidades: Catálogo, precios, promociones

-- Crear rol si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'operador_comercial') THEN
        CREATE ROLE operador_comercial;
    END IF;
END $$;

-- Tablas maestras de ubicación (solo lectura)
GRANT SELECT ON Provincia TO operador_comercial;
GRANT SELECT ON Ciudad TO operador_comercial;

-- Productos: CRUD completo
GRANT SELECT, INSERT, UPDATE, DELETE ON Producto TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE producto_producto_id_seq TO operador_comercial;

-- Promociones: CRUD completo
GRANT SELECT, INSERT, UPDATE, DELETE ON Promocion TO operador_comercial;
GRANT USAGE, SELECT ON SEQUENCE promocion_promocion_id_seq TO operador_comercial;

-- Ingresos de producto: Solo lectura (para consultar stock)
GRANT SELECT ON ingresoProducto TO operador_comercial;

-- Reseñas: Lectura y moderación (puede ver pero no eliminar)
GRANT SELECT ON Reseña TO operador_comercial;
-- Nota: Si necesitas que puedan eliminar reseñas inapropiadas, agregar DELETE

-- Usuarios: Solo lectura (para consultas)
GRANT SELECT ON Usuario TO operador_comercial;

-- Carritos: Solo lectura (para análisis)
GRANT SELECT ON Carrito TO operador_comercial;
GRANT SELECT ON lineaCarrito TO operador_comercial;

-- Facturas: Solo lectura (para reportes)
GRANT SELECT ON Factura TO operador_comercial;
GRANT SELECT ON lineaFactura TO operador_comercial;

-- Favoritos: Solo lectura (para análisis)
GRANT SELECT ON Favorito TO operador_comercial;

-- =========================================================
-- 3. OPERADOR_LOGISTICA - Operador de logística
-- =========================================================
-- Permisos: Gestión de stock, ingresos, envíos
-- Responsabilidades: Inventario, recepción de mercadería, envíos

-- Crear rol si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'operador_logistica') THEN
        CREATE ROLE operador_logistica;
    END IF;
END $$;

-- Tablas maestras de ubicación (solo lectura)
GRANT SELECT ON Provincia TO operador_logistica;
GRANT SELECT ON Ciudad TO operador_logistica;

-- Productos: Solo lectura de stock y actualización de stock
-- Nota: Para actualizar solo stock, necesitaríamos una función o vista
GRANT SELECT ON Producto TO operador_logistica;
-- Permitir actualizar solo la columna stock
GRANT UPDATE (stock) ON Producto TO operador_logistica;

-- Ingresos de producto: CRUD completo
GRANT SELECT, INSERT, UPDATE, DELETE ON ingresoProducto TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE ingresoproducto_ingreso_id_seq TO operador_logistica;

-- Envíos: CRUD completo (gestión de estados de envío)
GRANT SELECT, INSERT, UPDATE, DELETE ON Envio TO operador_logistica;
GRANT USAGE, SELECT ON SEQUENCE envio_envio_id_seq TO operador_logistica;

-- Direcciones: Solo lectura (para ver direcciones de envío)
GRANT SELECT ON Direccion TO operador_logistica;

-- Facturas: Solo lectura (para ver qué facturar)
GRANT SELECT ON Factura TO operador_logistica;
GRANT SELECT ON lineaFactura TO operador_logistica;

-- Usuarios: Solo lectura (para ver datos del cliente)
GRANT SELECT ON Usuario TO operador_logistica;

-- Carritos: Solo lectura (para consultas)
GRANT SELECT ON Carrito TO operador_logistica;
GRANT SELECT ON lineaCarrito TO operador_logistica;

-- =========================================================
-- 4. CLIENTE_APP - Cliente de la aplicación
-- =========================================================
-- Permisos: Solo sus propios datos, carrito, favoritos, reseñas
-- Responsabilidades: Compras, gestión de cuenta

-- Crear rol si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'cliente_app') THEN
        CREATE ROLE cliente_app;
    END IF;
END $$;

-- Tablas maestras de ubicación (solo lectura)
GRANT SELECT ON Provincia TO cliente_app;
GRANT SELECT ON Ciudad TO cliente_app;

-- Usuario: Solo lectura y actualización de sus propios datos
-- Nota: Esto requiere políticas RLS (Row Level Security) o funciones
-- Por ahora, damos permisos limitados
GRANT SELECT, UPDATE ON Usuario TO cliente_app;
-- Restricción: Solo puede actualizar sus propios datos (implementar con RLS o funciones)

-- Direcciones: CRUD solo de sus propias direcciones
GRANT SELECT, INSERT, UPDATE, DELETE ON Direccion TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE direccion_direccion_id_seq TO cliente_app;
-- Restricción: Solo puede gestionar sus propias direcciones (implementar con RLS)

-- Productos: Solo lectura (catálogo)
GRANT SELECT ON Producto TO cliente_app;

-- Promociones: Solo lectura (ver promociones activas)
GRANT SELECT ON Promocion TO cliente_app;

-- Carrito: CRUD solo de sus propios carritos
GRANT SELECT, INSERT, UPDATE, DELETE ON Carrito TO cliente_app;
GRANT USAGE, SELECT ON SEQUENCE carrito_carrito_id_seq TO cliente_app;
-- Restricción: Solo puede gestionar sus propios carritos (implementar con RLS)

-- Líneas de carrito: CRUD solo de sus propios carritos
GRANT SELECT, INSERT, UPDATE, DELETE ON lineaCarrito TO cliente_app;
-- Restricción: Solo puede gestionar líneas de sus propios carritos (implementar con RLS)

-- Favoritos: CRUD solo de sus propios favoritos
GRANT SELECT, INSERT, UPDATE, DELETE ON Favorito TO cliente_app;
-- Restricción: Solo puede gestionar sus propios favoritos (implementar con RLS)

-- Reseñas: CRUD solo de sus propias reseñas
GRANT SELECT, INSERT, UPDATE, DELETE ON Reseña TO cliente_app;
-- Restricción: Solo puede gestionar sus propias reseñas (implementar con RLS)

-- Facturas: Solo lectura de sus propias facturas
GRANT SELECT ON Factura TO cliente_app;
GRANT SELECT ON lineaFactura TO cliente_app;
-- Restricción: Solo puede ver sus propias facturas (implementar con RLS)

-- Pagos: Solo lectura de sus propios pagos
GRANT SELECT ON Pago TO cliente_app;
-- Restricción: Solo puede ver sus propios pagos (implementar con RLS)

-- Envíos: Solo lectura de sus propios envíos
GRANT SELECT ON Envio TO cliente_app;

COMMIT;


SELECT grantee, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE grantee IN ('operador_comercial')
ORDER BY grantee, table_name;

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

COMMENT ON VIEW v_productos_favoritos IS 
'Productos más agregados a favoritos. Para análisis comercial.';

-- =========================================================
-- OTORGAR PERMISOS EN VISTAS
-- =========================================================

-- Clientes: Solo vistas públicas
GRANT SELECT ON v_usuario_publico TO cliente_app;
GRANT SELECT ON v_perfil_usuario TO cliente_app;
GRANT SELECT ON v_catalogo_productos TO cliente_app;
GRANT SELECT ON v_detalle_carrito TO cliente_app;
GRANT SELECT ON v_detalle_factura TO cliente_app;
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
GRANT SELECT ON v_ventas_producto TO operador_comercial;
GRANT SELECT ON v_resenas_productos TO operador_comercial;
GRANT SELECT ON v_productos_favoritos TO operador_comercial;

-- Operador Logística: Vistas de stock y envíos
GRANT SELECT ON v_usuario_publico TO operador_logistica;
GRANT SELECT ON v_productos_stock TO operador_logistica;
GRANT SELECT ON v_productos_stock_bajo TO operador_logistica;
GRANT SELECT ON v_envios_pendientes TO operador_logistica;
GRANT SELECT ON v_facturas_completas TO operador_logistica;

-- Administrador: Todas las vistas
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_app;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_app;

COMMIT;


