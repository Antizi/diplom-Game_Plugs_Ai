-- Единая идемпотентная миграция backend.
-- Целевая схема: players, game_models, sessions, events, predictions.

SET search_path = public;

DROP TABLE IF EXISTS public.adaptation_history CASCADE;
DROP TABLE IF EXISTS public.adaptation_state CASCADE;
DROP TABLE IF EXISTS public.session_features CASCADE;
DROP TABLE IF EXISTS public.model_registry CASCADE;
DROP TABLE IF EXISTS public.game_profiles CASCADE;
DROP TABLE IF EXISTS public.schema_migrations CASCADE;

CREATE TABLE IF NOT EXISTS game_models (
    model_id BIGSERIAL PRIMARY KEY,
    model_version VARCHAR(50) NOT NULL,
    game_profile_version INTEGER NOT NULL DEFAULT 1,
    feature_schema_version INTEGER NOT NULL DEFAULT 1,
    critical_points JSONB NOT NULL DEFAULT '[]'::jsonb,
    archetypes JSONB NOT NULL DEFAULT '[]'::jsonb,
    feature_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    onnx JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_game_models_version UNIQUE (model_version)
);

ALTER TABLE game_models ADD COLUMN IF NOT EXISTS feature_schema JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE game_models ADD COLUMN IF NOT EXISTS onnx JSONB;
ALTER TABLE game_models DROP COLUMN IF EXISTS game_id;
ALTER TABLE game_models DROP COLUMN IF EXISTS feature_order;
ALTER TABLE game_models DROP COLUMN IF EXISTS bootstrap_actions;
ALTER TABLE game_models DROP COLUMN IF EXISTS format;
ALTER TABLE game_models DROP COLUMN IF EXISTS sha256;
ALTER TABLE game_models DROP COLUMN IF EXISTS storage_path;
ALTER TABLE game_models DROP COLUMN IF EXISTS download_url;
ALTER TABLE game_models DROP COLUMN IF EXISTS updated_at;

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS model_id BIGINT;
ALTER TABLE sessions DROP COLUMN IF EXISTS game_id;
ALTER TABLE sessions DROP COLUMN IF EXISTS game_profile_version;
ALTER TABLE sessions DROP COLUMN IF EXISTS feature_schema_version;
ALTER TABLE sessions DROP COLUMN IF EXISTS model_version;

ALTER TABLE events ADD COLUMN IF NOT EXISTS payload JSONB;
ALTER TABLE events DROP COLUMN IF EXISTS game_id;
ALTER TABLE events DROP COLUMN IF EXISTS event_data;

ALTER TABLE predictions ADD COLUMN IF NOT EXISTS model_id BIGINT;
ALTER TABLE predictions ADD COLUMN IF NOT EXISTS predicted_archetype VARCHAR(100);
ALTER TABLE predictions ADD COLUMN IF NOT EXISTS confidence NUMERIC;
ALTER TABLE predictions ADD COLUMN IF NOT EXISTS result JSONB;
ALTER TABLE predictions DROP COLUMN IF EXISTS game_id;
ALTER TABLE predictions DROP COLUMN IF EXISTS prediction_type;
ALTER TABLE predictions DROP COLUMN IF EXISTS prediction_value;
ALTER TABLE predictions DROP COLUMN IF EXISTS details;
ALTER TABLE predictions DROP COLUMN IF EXISTS model_version;
ALTER TABLE predictions DROP COLUMN IF EXISTS game_profile_version;
ALTER TABLE predictions DROP COLUMN IF EXISTS feature_schema_version;

ALTER TABLE players DROP COLUMN IF EXISTS last_session_id;
ALTER TABLE players DROP COLUMN IF EXISTS total_playtime;

ALTER TABLE public.game_models DROP CONSTRAINT IF EXISTS uq_game_models_game_version;
ALTER TABLE public.game_models DROP CONSTRAINT IF EXISTS game_models_game_id_model_version_key;
ALTER TABLE public.game_models DROP CONSTRAINT IF EXISTS game_models_model_version_key;
ALTER TABLE public.game_models DROP CONSTRAINT IF EXISTS uq_game_models_version;
ALTER TABLE public.game_models
    ADD CONSTRAINT uq_game_models_version UNIQUE (model_version);

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS fk_sessions_model_id;
ALTER TABLE public.sessions
    ADD CONSTRAINT fk_sessions_model_id
    FOREIGN KEY (model_id) REFERENCES public.game_models(model_id)
    ON DELETE SET NULL;

ALTER TABLE public.predictions DROP CONSTRAINT IF EXISTS fk_predictions_model_id;
ALTER TABLE public.predictions
    ADD CONSTRAINT fk_predictions_model_id
    FOREIGN KEY (model_id) REFERENCES public.game_models(model_id)
    ON DELETE SET NULL;

DROP INDEX IF EXISTS idx_game_models_game_created;
CREATE INDEX IF NOT EXISTS idx_sessions_model_id ON public.sessions(model_id);
CREATE INDEX IF NOT EXISTS idx_predictions_model_id ON public.predictions(model_id);
CREATE INDEX IF NOT EXISTS idx_game_models_created ON public.game_models(created_at DESC);
