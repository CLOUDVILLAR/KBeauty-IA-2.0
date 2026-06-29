CREATE TABLE IF NOT EXISTS analisis_externos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    villar_id UUID NOT NULL REFERENCES usuarios(villar_id) ON DELETE CASCADE,
    proveedor VARCHAR(100),
    nombre_archivo VARCHAR(255),
    archivo_url TEXT,
    texto_extraido TEXT,
    datos_extraidos JSONB NOT NULL DEFAULT '{}'::jsonb,
    analisis_ia JSONB NOT NULL DEFAULT '{}'::jsonb,
    rutina_recomendada JSONB NOT NULL DEFAULT '{}'::jsonb,
    aplicado_a_rutina BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analisis_externos_villar_id_creado
ON analisis_externos(villar_id, creado_en DESC);
