BEGIN;

CREATE USER ana_perez      PASSWORD 'Password1';   -- cliente_app
CREATE USER fernando_rossi PASSWORD 'Password6';   -- operador_comercial
CREATE USER hernan_torres  PASSWORD 'Password8';   -- operador_logistica
CREATE USER julian_diaz    PASSWORD 'Password10';  -- admin_app

-- Asignar roles a los usuarios
GRANT admin_app         TO julian_diaz;
GRANT operador_comercial TO fernando_rossi;
GRANT operador_logistica TO hernan_torres;
GRANT cliente_app        TO ana_perez;

COMMIT;