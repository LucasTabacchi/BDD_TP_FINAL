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
  db_login text UNIQUE;
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