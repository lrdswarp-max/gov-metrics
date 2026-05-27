ALTER TABLE avaliacoes DISABLE TRIGGER trg_avaliacoes_atualiza_indicadores;

INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'excellent', 'totem', NOW() - INTERVAL '1 hour');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'good', 'totem', NOW() - INTERVAL '2 hours');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'excellent', 'totem', NOW() - INTERVAL '3 hours');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', NULL, 'regular', 'totem', NOW() - INTERVAL '4 hours');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'good', 'web', NOW() - INTERVAL '5 hours');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', NULL, 'excellent', 'totem', NOW() - INTERVAL '1 day');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', NULL, 'good', 'totem', NOW() - INTERVAL '1 day');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', NULL, 'good', 'totem', NOW() - INTERVAL '2 days');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', NULL, 'regular', 'totem', NOW() - INTERVAL '2 days');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', NULL, 'bad', 'totem', NOW() - INTERVAL '3 days');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', NULL, 'regular', 'totem', NOW() - INTERVAL '3 days');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', NULL, 'excellent', 'totem', NOW() - INTERVAL '4 days');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', NULL, 'excellent', 'web', NOW() - INTERVAL '5 days');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', NULL, 'good', 'web', NOW() - INTERVAL '6 days');
INSERT INTO avaliacoes (municipio_id, secretaria_id, unidade_id, setor_id, nota, canal, created_at) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', NULL, 'excellent', 'web', NOW() - INTERVAL '7 days');

INSERT INTO comentarios (avaliacao_id, municipio_id, secretaria_id, unidade_id, setor_id, comentario, sentimento, anonimo, created_at)
SELECT id, municipio_id, secretaria_id, unidade_id, setor_id,
  CASE (row_number() OVER ()) % 4
    WHEN 0 THEN 'Atendimento rapido e eficiente, muito satisfeito!'
    WHEN 1 THEN 'Precisa melhorar o tempo de espera'
    WHEN 2 THEN 'Profissionais muito atenciosos, recomendo'
    WHEN 3 THEN 'Demorou muito para ser atendido'
  END,
  'positive',
  true,
  created_at
FROM avaliacoes
WHERE deleted_at IS NULL
LIMIT 8;

ALTER TABLE avaliacoes ENABLE TRIGGER trg_avaliacoes_atualiza_indicadores;

INSERT INTO indicadores_materializados (nivel, municipio_id, periodo_inicio, periodo_fim, intervalo, total_avaliacoes, total_excellent, total_good, total_regular, total_bad, media_pontuacao, satisfacao_bruta)
SELECT 'municipio', municipio_id, date_trunc('day', created_at)::DATE, date_trunc('day', created_at)::DATE, 'day',
  COUNT(*),
  COUNT(*) FILTER (WHERE nota = 'excellent'),
  COUNT(*) FILTER (WHERE nota = 'good'),
  COUNT(*) FILTER (WHERE nota = 'regular'),
  COUNT(*) FILTER (WHERE nota = 'bad'),
  ROUND(AVG(pontuacao), 3),
  ROUND((COUNT(*) FILTER (WHERE nota IN ('excellent', 'good'))::NUMERIC / GREATEST(COUNT(*), 1)) * 100, 2)
FROM avaliacoes
WHERE deleted_at IS NULL
GROUP BY municipio_id, date_trunc('day', created_at)
ON CONFLICT (nivel, municipio_id, COALESCE(secretaria_id, '00000000-0000-0000-0000-000000000000'), COALESCE(unidade_id, '00000000-0000-0000-0000-000000000000'), COALESCE(setor_id, '00000000-0000-0000-0000-000000000000'), periodo_inicio, intervalo)
DO UPDATE SET
  total_avaliacoes = EXCLUDED.total_avaliacoes,
  total_excellent = EXCLUDED.total_excellent,
  total_good = EXCLUDED.total_good,
  total_regular = EXCLUDED.total_regular,
  total_bad = EXCLUDED.total_bad,
  media_pontuacao = EXCLUDED.media_pontuacao,
  satisfacao_bruta = EXCLUDED.satisfacao_bruta,
  updated_at = NOW();
