-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role AS ENUM ('admin', 'gestor', 'operador', 'cidadao');
CREATE TYPE avaliacao_nota AS ENUM ('excellent', 'good', 'regular', 'bad');
CREATE TYPE sentimento AS ENUM ('positive', 'neutral', 'negative', 'mixed', 'not_analyzed');
CREATE TYPE alerta_status AS ENUM ('active', 'triggered', 'acknowledged', 'resolved', 'disabled');
CREATE TYPE alerta_severidade AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE relatorio_formato AS ENUM ('pdf', 'xlsx', 'csv', 'json');
CREATE TYPE relatorio_status AS ENUM ('pending', 'generating', 'completed', 'failed');
CREATE TYPE unidade_tipo AS ENUM (
  'upa', 'ubs', 'hospital', 'escola', 'creche',
  'centro_esportivo', 'centro_cultural', 'orgao_publico', 'outro'
);

-- ============================================================
-- HIERARCHY TABLES
-- ============================================================
CREATE TABLE municipios (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        TEXT NOT NULL,
  codigo_ibge CHAR(7) UNIQUE NOT NULL,
  uf          CHAR(2) NOT NULL,
  populacao   INTEGER,
  ativo       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX idx_municipios_uf ON municipios(uf);
CREATE INDEX idx_municipios_deleted ON municipios(deleted_at) WHERE deleted_at IS NULL;

CREATE TABLE secretarias (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipio_id UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  nome         TEXT NOT NULL,
  sigla        VARCHAR(20),
  responsavel  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ,
  CONSTRAINT uq_secretarias_municipio_nome UNIQUE (municipio_id, nome)
);

CREATE INDEX idx_secretarias_municipio ON secretarias(municipio_id);
CREATE INDEX idx_secretarias_deleted ON secretarias(deleted_at) WHERE deleted_at IS NULL;

CREATE TABLE unidades (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  secretaria_id  UUID NOT NULL REFERENCES secretarias(id) ON DELETE CASCADE,
  municipio_id   UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  nome           TEXT NOT NULL,
  tipo           unidade_tipo NOT NULL,
  endereco       TEXT,
  latitude       NUMERIC(10,7),
  longitude      NUMERIC(10,7),
  telefone       VARCHAR(20),
  horario_funcionamento TEXT,
  ativa          BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ
);

CREATE INDEX idx_unidades_secretaria ON unidades(secretaria_id);
CREATE INDEX idx_unidades_municipio ON unidades(municipio_id);
CREATE INDEX idx_unidades_tipo ON unidades(tipo);
CREATE INDEX idx_unidades_deleted ON unidades(deleted_at) WHERE deleted_at IS NULL;

CREATE TABLE setores (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unidade_id  UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  municipio_id UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  nome        TEXT NOT NULL,
  descricao   TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX idx_setores_unidade ON setores(unidade_id);
CREATE INDEX idx_setores_municipio ON setores(municipio_id);
CREATE INDEX idx_setores_deleted ON setores(deleted_at) WHERE deleted_at IS NULL;

-- ============================================================
-- PROFILES (extends auth.users)
-- ============================================================
CREATE TABLE profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome          TEXT NOT NULL,
  email         TEXT NOT NULL,
  papel         user_role NOT NULL DEFAULT 'cidadao',
  avatar_url    TEXT,
  telefone      VARCHAR(20),
  municipio_id  UUID REFERENCES municipios(id) ON DELETE SET NULL,
  secretaria_id UUID REFERENCES secretarias(id) ON DELETE SET NULL,
  unidade_id    UUID REFERENCES unidades(id) ON DELETE SET NULL,
  setor_id      UUID REFERENCES setores(id) ON DELETE SET NULL,
  ativo         BOOLEAN NOT NULL DEFAULT TRUE,
  ultimo_acesso TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX idx_profiles_municipio ON profiles(municipio_id);
CREATE INDEX idx_profiles_papel ON profiles(papel);
CREATE INDEX idx_profiles_deleted ON profiles(deleted_at) WHERE deleted_at IS NULL;

-- ============================================================
-- AVALIACOES (PARTITIONED BY MONTH)
-- ============================================================
CREATE TABLE avaliacoes (
  id            UUID NOT NULL DEFAULT gen_random_uuid(),
  municipio_id  UUID NOT NULL,
  secretaria_id UUID NOT NULL,
  unidade_id    UUID NOT NULL,
  setor_id      UUID,
  nota          avaliacao_nota NOT NULL,
  pontuacao     SMALLINT NOT NULL GENERATED ALWAYS AS (
    CASE nota
      WHEN 'excellent' THEN 4
      WHEN 'good'      THEN 3
      WHEN 'regular'   THEN 2
      WHEN 'bad'       THEN 1
    END
  ) STORED,
  canal         VARCHAR(20) NOT NULL DEFAULT 'totem',
  session_id    TEXT,
  cpf_hash      TEXT,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  latitude      NUMERIC(10,7),
  longitude     NUMERIC(10,7),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ,
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE avaliacoes_default PARTITION OF avaliacoes DEFAULT;

CREATE INDEX idx_avaliacoes_municipio ON avaliacoes(municipio_id, created_at);
CREATE INDEX idx_avaliacoes_unidade   ON avaliacoes(unidade_id, created_at);
CREATE INDEX idx_avaliacoes_secretaria ON avaliacoes(secretaria_id, created_at);
CREATE INDEX idx_avaliacoes_nota      ON avaliacoes(nota);
CREATE INDEX idx_avaliacoes_created   ON avaliacoes(created_at DESC);

-- ============================================================
-- COMENTARIOS
-- ============================================================
CREATE TABLE comentarios (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  avaliacao_id   UUID,
  municipio_id   UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  secretaria_id  UUID NOT NULL REFERENCES secretarias(id) ON DELETE CASCADE,
  unidade_id     UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
  setor_id       UUID REFERENCES setores(id) ON DELETE SET NULL,
  user_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  comentario     TEXT NOT NULL,
  sentimento     sentimento NOT NULL DEFAULT 'not_analyzed',
  score_sentimento NUMERIC(4,3),
  moderado       BOOLEAN NOT NULL DEFAULT FALSE,
  moderado_por   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  moderado_em    TIMESTAMPTZ,
  curtidas       INTEGER NOT NULL DEFAULT 0,
  anonimo        BOOLEAN NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ
);

CREATE INDEX idx_comentarios_municipio ON comentarios(municipio_id);
CREATE INDEX idx_comentarios_unidade   ON comentarios(unidade_id);
CREATE INDEX idx_comentarios_sentimento ON comentarios(sentimento);
CREATE INDEX idx_comentarios_created   ON comentarios(created_at DESC);
CREATE INDEX idx_comentarios_deleted   ON comentarios(deleted_at) WHERE deleted_at IS NULL;

-- ============================================================
-- INDICADORES MATERIALIZADOS
-- ============================================================
CREATE TABLE indicadores_materializados (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nivel                 VARCHAR(20) NOT NULL,
  municipio_id          UUID REFERENCES municipios(id) ON DELETE CASCADE,
  secretaria_id         UUID REFERENCES secretarias(id) ON DELETE CASCADE,
  unidade_id            UUID REFERENCES unidades(id) ON DELETE CASCADE,
  setor_id              UUID REFERENCES setores(id) ON DELETE CASCADE,
  periodo_inicio        DATE NOT NULL,
  periodo_fim           DATE NOT NULL,
  intervalo             VARCHAR(10) NOT NULL,
  total_avaliacoes      INTEGER NOT NULL DEFAULT 0,
  total_excellent       INTEGER NOT NULL DEFAULT 0,
  total_good            INTEGER NOT NULL DEFAULT 0,
  total_regular         INTEGER NOT NULL DEFAULT 0,
  total_bad             INTEGER NOT NULL DEFAULT 0,
  media_pontuacao       NUMERIC(4,3),
  satisfacao_bruta      NUMERIC(5,2),
  total_comentarios     INTEGER NOT NULL DEFAULT 0,
  total_positivos       INTEGER NOT NULL DEFAULT 0,
  total_negativos       INTEGER NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uq_indicador_periodo ON indicadores_materializados (
    nivel, municipio_id,
    COALESCE(secretaria_id, '00000000-0000-0000-0000-000000000000'),
    COALESCE(unidade_id, '00000000-0000-0000-0000-000000000000'),
    COALESCE(setor_id, '00000000-0000-0000-0000-000000000000'),
    periodo_inicio, intervalo
);

CREATE INDEX idx_indicadores_nivel ON indicadores_materializados(nivel, municipio_id);
CREATE INDEX idx_indicadores_unidade ON indicadores_materializados(unidade_id);
CREATE INDEX idx_indicadores_periodo ON indicadores_materializados(periodo_inicio DESC);

-- ============================================================
-- ALERTAS
-- ============================================================
CREATE TABLE alertas_config (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipio_id        UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  secretaria_id       UUID REFERENCES secretarias(id) ON DELETE CASCADE,
  unidade_id          UUID REFERENCES unidades(id) ON DELETE CASCADE,
  nome                TEXT NOT NULL,
  descricao           TEXT,
  ativo               BOOLEAN NOT NULL DEFAULT TRUE,
  severidade          alerta_severidade NOT NULL DEFAULT 'medium',
  condicoes           JSONB NOT NULL,
  notificar_por       TEXT[] NOT NULL DEFAULT '{email}',
  notificar_para      JSONB,
  intervalo_cooldown  INTERVAL NOT NULL DEFAULT '6 hours',
  ultima_disparado_em TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_alertas_config_municipio ON alertas_config(municipio_id);
CREATE INDEX idx_alertas_config_ativo     ON alertas_config(ativo) WHERE ativo = TRUE;
CREATE INDEX idx_alertas_config_deleted   ON alertas_config(deleted_at) WHERE deleted_at IS NULL;

CREATE TABLE alertas_historico (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alerta_config_id    UUID NOT NULL REFERENCES alertas_config(id) ON DELETE CASCADE,
  municipio_id        UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  status              alerta_status NOT NULL DEFAULT 'triggered',
  mensagem            TEXT NOT NULL,
  metrica_disparada   JSONB NOT NULL,
  valor_apurado       NUMERIC(10,2),
  valor_limite        NUMERIC(10,2),
  reconhecido_por     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reconhecido_em      TIMESTAMPTZ,
  resolvido_por       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolvido_em        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alertas_historico_municipio ON alertas_historico(municipio_id);
CREATE INDEX idx_alertas_historico_status    ON alertas_historico(status);
CREATE INDEX idx_alertas_historico_created   ON alertas_historico(created_at DESC);

-- ============================================================
-- RELATORIOS
-- ============================================================
CREATE TABLE relatorios_config (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipio_id          UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  secretaria_id         UUID REFERENCES secretarias(id) ON DELETE SET NULL,
  unidade_id            UUID REFERENCES unidades(id) ON DELETE SET NULL,
  nome                  TEXT NOT NULL,
  descricao             TEXT,
  formato               relatorio_formato NOT NULL DEFAULT 'pdf',
  periodicidade         VARCHAR(20),
  parametros            JSONB NOT NULL DEFAULT '{}',
  inclui_graficos       BOOLEAN NOT NULL DEFAULT TRUE,
  inclui_comentarios    BOOLEAN NOT NULL DEFAULT FALSE,
  inclui_evolucao       BOOLEAN NOT NULL DEFAULT TRUE,
  gerar_automaticamente BOOLEAN NOT NULL DEFAULT FALSE,
  notificar_ao_gerar    BOOLEAN NOT NULL DEFAULT FALSE,
  criar_publico         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ
);

CREATE INDEX idx_relatorios_config_municipio ON relatorios_config(municipio_id);
CREATE INDEX idx_relatorios_config_deleted   ON relatorios_config(deleted_at) WHERE deleted_at IS NULL;

CREATE TABLE relatorios_gerados (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_id           UUID NOT NULL REFERENCES relatorios_config(id) ON DELETE CASCADE,
  municipio_id        UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  status              relatorio_status NOT NULL DEFAULT 'pending',
  formato             relatorio_formato NOT NULL,
  parametros_usados   JSONB,
  tamanho_bytes       BIGINT,
  storage_path        TEXT,
  url_publico         TEXT,
  gerado_por          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  erro_mensagem       TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_relatorios_gerados_config    ON relatorios_gerados(config_id);
CREATE INDEX idx_relatorios_gerados_municipio ON relatorios_gerados(municipio_id);
CREATE INDEX idx_relatorios_gerados_status    ON relatorios_gerados(status);
CREATE INDEX idx_relatorios_gerados_created   ON relatorios_gerados(created_at DESC);

-- ============================================================
-- INDICADORES PUBLICOS (transparency portal)
-- ============================================================
CREATE TABLE indicadores_publicos (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipio_id          UUID NOT NULL REFERENCES municipios(id) ON DELETE CASCADE,
  unidade_id            UUID REFERENCES unidades(id) ON DELETE CASCADE,
  secretaria_id         UUID REFERENCES secretarias(id) ON DELETE SET NULL,
  mes_referencia        DATE NOT NULL,
  total_avaliacoes      INTEGER NOT NULL DEFAULT 0,
  satisfacao_percentual NUMERIC(5,2),
  media_geral           NUMERIC(3,2),
  total_comentarios     INTEGER NOT NULL DEFAULT 0,
  comentarios_positivos INTEGER NOT NULL DEFAULT 0,
  comentarios_negativos INTEGER NOT NULL DEFAULT 0,
  tendencia             VARCHAR(10),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uq_publico_mes ON indicadores_publicos (
    municipio_id,
    COALESCE(unidade_id, '00000000-0000-0000-0000-000000000000'),
    mes_referencia
);

CREATE INDEX idx_indicadores_publicos_municipio ON indicadores_publicos(municipio_id);
CREATE INDEX idx_indicadores_publicos_mes       ON indicadores_publicos(mes_referencia DESC);

-- ============================================================
-- AUDIT LOG
-- ============================================================
CREATE TABLE audit_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  municipio_id    UUID REFERENCES municipios(id) ON DELETE SET NULL,
  user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  acao            VARCHAR(50) NOT NULL,
  entidade_tipo   VARCHAR(50) NOT NULL,
  entidade_id     UUID,
  valores_antigos JSONB,
  valores_novos   JSONB,
  ip_origem       INET,
  user_agent      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_municipio ON audit_log(municipio_id, created_at);
CREATE INDEX idx_audit_log_user      ON audit_log(user_id);
CREATE INDEX idx_audit_log_entidade  ON audit_log(entidade_tipo, entidade_id);
CREATE INDEX idx_audit_log_created   ON audit_log(created_at DESC);

-- ============================================================
-- RLS ENABLE
-- ============================================================
ALTER TABLE municipios ENABLE ROW LEVEL SECURITY;
ALTER TABLE secretarias ENABLE ROW LEVEL SECURITY;
ALTER TABLE unidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE setores ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE avaliacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comentarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE indicadores_materializados ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas_historico ENABLE ROW LEVEL SECURITY;
ALTER TABLE relatorios_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE relatorios_gerados ENABLE ROW LEVEL SECURITY;
ALTER TABLE indicadores_publicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- HELPER FUNCTIONS FOR RLS
-- ============================================================
CREATE OR REPLACE FUNCTION fn_usuario_papel()
RETURNS user_role
LANGUAGE SQL STABLE SECURITY DEFINER
AS $$
  SELECT papel FROM public.profiles WHERE id = auth.uid() AND deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION fn_usuario_municipio()
RETURNS UUID
LANGUAGE SQL STABLE SECURITY DEFINER
AS $$
  SELECT municipio_id FROM public.profiles WHERE id = auth.uid() AND deleted_at IS NULL;
$$;

-- ============================================================
-- RLS POLICIES: MUNICIPIOS
-- ============================================================
CREATE POLICY "admin_all_municipios" ON municipios
  FOR ALL USING (fn_usuario_papel() = 'admin');

CREATE POLICY "gestor_read_municipio" ON municipios
  FOR SELECT USING (
    fn_usuario_papel() = 'gestor'
    AND id = fn_usuario_municipio()
  );

-- ============================================================
-- RLS POLICIES: SECRETARIAS
-- ============================================================
CREATE POLICY "secretarias_admin_all" ON secretarias
  FOR ALL USING (fn_usuario_papel() = 'admin');

CREATE POLICY "secretarias_gestor" ON secretarias
  FOR ALL USING (
    fn_usuario_papel() = 'gestor'
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "secretarias_operador_read" ON secretarias
  FOR SELECT USING (
    fn_usuario_papel() = 'operador'
    AND municipio_id = fn_usuario_municipio()
  );

-- ============================================================
-- RLS POLICIES: UNIDADES
-- ============================================================
CREATE POLICY "unidades_admin_all" ON unidades
  FOR ALL USING (fn_usuario_papel() = 'admin');

CREATE POLICY "unidades_gestor" ON unidades
  FOR ALL USING (
    fn_usuario_papel() = 'gestor'
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "unidades_operador_read" ON unidades
  FOR SELECT USING (
    fn_usuario_papel() = 'operador'
    AND municipio_id = fn_usuario_municipio()
  );

-- ============================================================
-- RLS POLICIES: SETORES
-- ============================================================
CREATE POLICY "setores_admin_all" ON setores
  FOR ALL USING (fn_usuario_papel() = 'admin');

CREATE POLICY "setores_gestor" ON setores
  FOR ALL USING (
    fn_usuario_papel() = 'gestor'
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "setores_operador_read" ON setores
  FOR SELECT USING (
    fn_usuario_papel() = 'operador'
    AND municipio_id = fn_usuario_municipio()
  );

-- ============================================================
-- RLS POLICIES: PROFILES
-- ============================================================
CREATE POLICY "profiles_self" ON profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL USING (fn_usuario_papel() = 'admin');

CREATE POLICY "profiles_gestor_scope" ON profiles
  FOR SELECT USING (
    fn_usuario_papel() = 'gestor'
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "profiles_operador_scope" ON profiles
  FOR SELECT USING (
    fn_usuario_papel() = 'operador'
    AND unidade_id = (SELECT unidade_id FROM profiles WHERE id = auth.uid())
  );

-- ============================================================
-- RLS POLICIES: AVALIACOES
-- ============================================================
CREATE POLICY "avaliacoes_anon_insert" ON avaliacoes
  FOR INSERT WITH CHECK (auth.role() = 'anon');

CREATE POLICY "avaliacoes_cidadao_insert" ON avaliacoes
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated'
    AND fn_usuario_papel() = 'cidadao'
  );

CREATE POLICY "avaliacoes_cidadao_select" ON avaliacoes
  FOR SELECT USING (
    fn_usuario_papel() = 'cidadao'
    AND user_id = auth.uid()
  );

CREATE POLICY "avaliacoes_gestor" ON avaliacoes
  FOR SELECT USING (
    fn_usuario_papel() IN ('gestor', 'admin')
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "avaliacoes_operador" ON avaliacoes
  FOR SELECT USING (
    fn_usuario_papel() = 'operador'
    AND unidade_id = (SELECT unidade_id FROM profiles WHERE id = auth.uid())
  );

-- ============================================================
-- RLS POLICIES: COMENTARIOS
-- ============================================================
CREATE POLICY "comentarios_cidadao_insert" ON comentarios
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated'
    AND fn_usuario_papel() = 'cidadao'
    AND user_id = auth.uid()
  );

CREATE POLICY "comentarios_cidadao_select" ON comentarios
  FOR SELECT USING (
    fn_usuario_papel() = 'cidadao'
    AND (user_id = auth.uid() OR anonimo = TRUE)
  );

CREATE POLICY "comentarios_gestor" ON comentarios
  FOR ALL USING (
    fn_usuario_papel() IN ('gestor', 'admin')
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "comentarios_operador" ON comentarios
  FOR SELECT USING (
    fn_usuario_papel() = 'operador'
    AND unidade_id = (SELECT unidade_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "comentarios_operador_moderate" ON comentarios
  FOR UPDATE USING (
    fn_usuario_papel() = 'operador'
    AND unidade_id = (SELECT unidade_id FROM profiles WHERE id = auth.uid())
  );

-- ============================================================
-- RLS POLICIES: INDICADORES
-- ============================================================
CREATE POLICY "indicadores_gestor" ON indicadores_materializados
  FOR SELECT USING (
    fn_usuario_papel() IN ('gestor', 'operador', 'admin')
    AND municipio_id = fn_usuario_municipio()
  );

-- ============================================================
-- RLS POLICIES: ALERTAS
-- ============================================================
CREATE POLICY "alertas_config_gestor" ON alertas_config
  FOR ALL USING (
    fn_usuario_papel() IN ('gestor', 'admin')
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "alertas_config_operador_read" ON alertas_config
  FOR SELECT USING (
    fn_usuario_papel() = 'operador'
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "alertas_historico_gestor" ON alertas_historico
  FOR ALL USING (
    fn_usuario_papel() IN ('gestor', 'admin')
    AND municipio_id = fn_usuario_municipio()
  );

-- ============================================================
-- RLS POLICIES: RELATORIOS
-- ============================================================
CREATE POLICY "relatorios_gestor" ON relatorios_config
  FOR ALL USING (
    fn_usuario_papel() IN ('gestor', 'admin')
    AND municipio_id = fn_usuario_municipio()
  );

CREATE POLICY "relatorios_gerados_gestor" ON relatorios_gerados
  FOR ALL USING (
    fn_usuario_papel() IN ('gestor', 'admin')
    AND municipio_id = fn_usuario_municipio()
  );

-- ============================================================
-- RLS POLICIES: INDICADORES PUBLICOS (anon can read)
-- ============================================================
CREATE POLICY "indicadores_publicos_anon_select" ON indicadores_publicos
  FOR SELECT USING (auth.role() = 'anon' OR auth.role() = 'authenticated');

-- ============================================================
-- RLS POLICIES: AUDIT LOG
-- ============================================================
CREATE POLICY "audit_log_admin" ON audit_log
  FOR SELECT USING (fn_usuario_papel() = 'admin');

CREATE POLICY "audit_log_gestor" ON audit_log
  FOR SELECT USING (
    fn_usuario_papel() = 'gestor'
    AND municipio_id = fn_usuario_municipio()
  );

-- ============================================================
-- TRIGGERS: updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_municipios_updated_at BEFORE UPDATE ON municipios
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_secretarias_updated_at BEFORE UPDATE ON secretarias
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_unidades_updated_at BEFORE UPDATE ON unidades
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_setores_updated_at BEFORE UPDATE ON setores
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_comentarios_updated_at BEFORE UPDATE ON comentarios
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_alertas_config_updated_at BEFORE UPDATE ON alertas_config
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_relatorios_config_updated_at BEFORE UPDATE ON relatorios_config
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
CREATE TRIGGER trg_indicadores_updated_at BEFORE UPDATE ON indicadores_materializados
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ============================================================
-- TRIGGER: Atualizar indicadores materializados
-- ============================================================
CREATE OR REPLACE FUNCTION fn_atualizar_indicadores()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO indicadores_materializados
    (nivel, municipio_id, secretaria_id, unidade_id, setor_id,
     periodo_inicio, periodo_fim, intervalo,
     total_avaliacoes, total_excellent, total_good, total_regular, total_bad,
     media_pontuacao, satisfacao_bruta)
  SELECT
    'unidade',
    NEW.municipio_id,
    NEW.secretaria_id,
    NEW.unidade_id,
    NEW.setor_id,
    date_trunc('day', NEW.created_at)::DATE,
    date_trunc('day', NEW.created_at)::DATE,
    'day',
    COUNT(*),
    COUNT(*) FILTER (WHERE nota = 'excellent'),
    COUNT(*) FILTER (WHERE nota = 'good'),
    COUNT(*) FILTER (WHERE nota = 'regular'),
    COUNT(*) FILTER (WHERE nota = 'bad'),
    ROUND(AVG(pontuacao), 3),
    ROUND((COUNT(*) FILTER (WHERE nota IN ('excellent', 'good'))::NUMERIC / GREATEST(COUNT(*), 1)) * 100, 2)
  FROM avaliacoes
  WHERE unidade_id = NEW.unidade_id
    AND created_at >= date_trunc('day', NEW.created_at)
    AND created_at < date_trunc('day', NEW.created_at) + INTERVAL '1 day'
    AND deleted_at IS NULL
  GROUP BY municipio_id, secretaria_id, unidade_id, setor_id
  ON CONFLICT (nivel, municipio_id,
    COALESCE(secretaria_id, '00000000-0000-0000-0000-000000000000'),
    COALESCE(unidade_id, '00000000-0000-0000-0000-000000000000'),
    COALESCE(setor_id, '00000000-0000-0000-0000-000000000000'),
    periodo_inicio, intervalo)
  DO UPDATE SET
    total_avaliacoes  = EXCLUDED.total_avaliacoes,
    total_excellent   = EXCLUDED.total_excellent,
    total_good        = EXCLUDED.total_good,
    total_regular     = EXCLUDED.total_regular,
    total_bad         = EXCLUDED.total_bad,
    media_pontuacao   = EXCLUDED.media_pontuacao,
    satisfacao_bruta  = EXCLUDED.satisfacao_bruta,
    updated_at        = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_avaliacoes_atualiza_indicadores
  AFTER INSERT ON avaliacoes
  FOR EACH ROW
  EXECUTE FUNCTION fn_atualizar_indicadores();

-- ============================================================
-- REALTIME: Enable for live dashboards
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY avaliacoes;
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY comentarios;
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY alertas_historico;
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY indicadores_materializados;
