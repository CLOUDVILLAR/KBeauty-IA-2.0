-- =========================================================
-- KBEAUTY IA V2 - ESQUEMA ADAPTADO A VILLAR.DO
-- Ejecutar conectado a la DB: kbeauty_ia_v2
-- =========================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ADVERTENCIA: borra tablas de KBeauty y las recrea adaptadas a Villar.do.
DROP TABLE IF EXISTS productos_recomendados CASCADE;
DROP TABLE IF EXISTS rutinas_recomendadas CASCADE;
DROP TABLE IF EXISTS historial_evolucion CASCADE;
DROP TABLE IF EXISTS analisis_zonas CASCADE;
DROP TABLE IF EXISTS analisis_piel CASCADE;
DROP TABLE IF EXISTS perfiles_piel CASCADE;
DROP TABLE IF EXISTS usuarios_roles CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS eventos_kbeauty CASCADE;

CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    villar_id UUID NOT NULL UNIQUE,
    estado_en_app VARCHAR(30) NOT NULL DEFAULT 'activo',
    formulario_completado BOOLEAN NOT NULL DEFAULT FALSE,
    primer_acceso TIMESTAMP NOT NULL DEFAULT NOW(),
    ultimo_acceso TIMESTAMP,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_usuarios_estado_en_app
        CHECK (estado_en_app IN ('activo', 'desactivado', 'suspendido'))
);

CREATE INDEX idx_usuarios_villar_id ON usuarios(villar_id);
CREATE INDEX idx_usuarios_estado_en_app ON usuarios(estado_en_app);

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO roles (codigo, nombre, descripcion)
VALUES
    ('cliente', 'Cliente', 'Usuario cliente de KBeauty IA'),
    ('admin_kbeauty', 'Administrador KBeauty', 'Administrador local de KBeauty IA')
ON CONFLICT (codigo) DO NOTHING;

CREATE TABLE usuarios_roles (
    villar_id UUID NOT NULL REFERENCES usuarios(villar_id) ON DELETE CASCADE,
    rol_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (villar_id, rol_id)
);

CREATE INDEX idx_usuarios_roles_villar_id ON usuarios_roles(villar_id);
CREATE INDEX idx_usuarios_roles_rol_id ON usuarios_roles(rol_id);

CREATE TABLE perfiles_piel (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    villar_id UUID NOT NULL UNIQUE REFERENCES usuarios(villar_id) ON DELETE CASCADE,
    tipo_piel VARCHAR(80),
    condicion_principal VARCHAR(120),
    rango_edad VARCHAR(50),
    sensibilidad VARCHAR(50),
    usa_protector_solar BOOLEAN,
    frecuencia_protector_solar VARCHAR(80),
    alergias TEXT,
    productos_actuales TEXT,
    objetivo_principal TEXT,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_perfiles_piel_villar_id ON perfiles_piel(villar_id);
CREATE INDEX idx_perfiles_piel_tipo_piel ON perfiles_piel(tipo_piel);
CREATE INDEX idx_perfiles_piel_condicion ON perfiles_piel(condicion_principal);

CREATE TABLE analisis_piel (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    villar_id UUID NOT NULL REFERENCES usuarios(villar_id) ON DELETE CASCADE,
    resumen_general TEXT,
    tono_piel VARCHAR(100),
    condicion_principal_detectada VARCHAR(120),
    condiciones_detectadas JSONB NOT NULL DEFAULT '[]'::jsonb,
    puntajes JSONB NOT NULL DEFAULT '{}'::jsonb,
    resultado_completo JSONB NOT NULL DEFAULT '{}'::jsonb,
    modo_demo BOOLEAN NOT NULL DEFAULT FALSE,
    modelo_ia VARCHAR(100),
    version_rubrica VARCHAR(80),
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_analisis_piel_villar_id ON analisis_piel(villar_id);
CREATE INDEX idx_analisis_piel_creado_en ON analisis_piel(creado_en);
CREATE INDEX idx_analisis_piel_condicion_detectada ON analisis_piel(condicion_principal_detectada);

CREATE TABLE analisis_zonas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analisis_id UUID NOT NULL REFERENCES analisis_piel(id) ON DELETE CASCADE,
    zona VARCHAR(80) NOT NULL,
    resumen TEXT,
    puntajes JSONB NOT NULL DEFAULT '{}'::jsonb,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_analisis_zonas_analisis_id ON analisis_zonas(analisis_id);
CREATE INDEX idx_analisis_zonas_zona ON analisis_zonas(zona);

CREATE TABLE rutinas_recomendadas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    villar_id UUID NOT NULL REFERENCES usuarios(villar_id) ON DELETE CASCADE,
    analisis_id UUID REFERENCES analisis_piel(id) ON DELETE SET NULL,
    nombre_rutina VARCHAR(200),
    tipo_piel VARCHAR(80),
    condicion VARCHAR(120),
    criterios JSONB NOT NULL DEFAULT '{}'::jsonb,
    rutina JSONB NOT NULL DEFAULT '{}'::jsonb,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rutinas_recomendadas_villar_id ON rutinas_recomendadas(villar_id);
CREATE INDEX idx_rutinas_recomendadas_analisis_id ON rutinas_recomendadas(analisis_id);
CREATE INDEX idx_rutinas_recomendadas_tipo_condicion ON rutinas_recomendadas(tipo_piel, condicion);

CREATE TABLE productos_recomendados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rutina_id UUID NOT NULL REFERENCES rutinas_recomendadas(id) ON DELETE CASCADE,
    id_odoo INTEGER,
    nombre_producto TEXT NOT NULL,
    categoria VARCHAR(120),
    subtipo VARCHAR(120),
    momento VARCHAR(50),
    uso TEXT,
    frecuencia TEXT,
    descripcion_rutina TEXT,
    orden INTEGER NOT NULL DEFAULT 0,
    ubicaciones_odoo JSONB NOT NULL DEFAULT '[]'::jsonb,
    odoo_activo BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_productos_recomendados_rutina_id ON productos_recomendados(rutina_id);
CREATE INDEX idx_productos_recomendados_id_odoo ON productos_recomendados(id_odoo);
CREATE INDEX idx_productos_recomendados_momento ON productos_recomendados(momento);

CREATE TABLE historial_evolucion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    villar_id UUID NOT NULL REFERENCES usuarios(villar_id) ON DELETE CASCADE,
    analisis_anterior_id UUID REFERENCES analisis_piel(id) ON DELETE SET NULL,
    analisis_actual_id UUID REFERENCES analisis_piel(id) ON DELETE SET NULL,
    resumen TEXT,
    comparacion JSONB NOT NULL DEFAULT '{}'::jsonb,
    porcentajes_mejora JSONB NOT NULL DEFAULT '{}'::jsonb,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_historial_evolucion_villar_id ON historial_evolucion(villar_id);
CREATE INDEX idx_historial_evolucion_creado_en ON historial_evolucion(creado_en);

CREATE TABLE eventos_kbeauty (
    id BIGSERIAL PRIMARY KEY,
    villar_id UUID REFERENCES usuarios(villar_id) ON DELETE SET NULL,
    tipo_evento VARCHAR(100) NOT NULL,
    descripcion TEXT,
    datos JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip_origen VARCHAR(100),
    user_agent TEXT,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_eventos_kbeauty_villar_id ON eventos_kbeauty(villar_id);
CREATE INDEX idx_eventos_kbeauty_tipo_evento ON eventos_kbeauty(tipo_evento);
CREATE INDEX idx_eventos_kbeauty_creado_en ON eventos_kbeauty(creado_en);

CREATE OR REPLACE FUNCTION actualizar_columna_actualizado_en()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_usuarios_actualizado_en ON usuarios;
CREATE TRIGGER trg_usuarios_actualizado_en
BEFORE UPDATE ON usuarios
FOR EACH ROW
EXECUTE FUNCTION actualizar_columna_actualizado_en();

DROP TRIGGER IF EXISTS trg_perfiles_piel_actualizado_en ON perfiles_piel;
CREATE TRIGGER trg_perfiles_piel_actualizado_en
BEFORE UPDATE ON perfiles_piel
FOR EACH ROW
EXECUTE FUNCTION actualizar_columna_actualizado_en();

CREATE OR REPLACE VIEW vista_usuarios_kbeauty AS
SELECT
    u.id,
    u.villar_id,
    u.estado_en_app,
    u.formulario_completado,
    u.primer_acceso,
    u.ultimo_acceso,
    u.creado_en,
    u.actualizado_en,
    p.tipo_piel,
    p.condicion_principal,
    p.rango_edad,
    p.sensibilidad,
    p.usa_protector_solar
FROM usuarios u
LEFT JOIN perfiles_piel p ON p.villar_id = u.villar_id;

CREATE OR REPLACE VIEW vista_ultimo_analisis AS
SELECT DISTINCT ON (a.villar_id)
    a.villar_id,
    a.id AS analisis_id,
    a.resumen_general,
    a.tono_piel,
    a.condicion_principal_detectada,
    a.condiciones_detectadas,
    a.puntajes,
    a.modo_demo,
    a.modelo_ia,
    a.version_rubrica,
    a.creado_en
FROM analisis_piel a
ORDER BY a.villar_id, a.creado_en DESC;

SELECT 'KBeauty IA adaptada a Villar.do correctamente' AS estado;
