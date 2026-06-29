CREATE TABLE IF NOT EXISTS chat_ia_mensajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    villar_id UUID NOT NULL REFERENCES usuarios(villar_id) ON DELETE CASCADE,
    rol VARCHAR(20) NOT NULL,
    contenido TEXT NOT NULL,
    contexto_usado JSONB NOT NULL DEFAULT '{}'::jsonb,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_chat_ia_mensajes_rol CHECK (rol IN ('user', 'assistant'))
);

CREATE INDEX IF NOT EXISTS idx_chat_ia_mensajes_villar_id_creado
    ON chat_ia_mensajes(villar_id, creado_en);
