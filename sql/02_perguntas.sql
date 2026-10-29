-- 02_perguntas.sql : 6 perguntas de negocio da Controladoria
-- Rodar depois de: python -m src.carregar
-- Regras: percentual = SOMA / SOMA (nunca media de percentuais); economia so em itens comparaveis (comparavel = 1);
-- NULLIF evita divisao por zero (Credenciamento nao tem item comparavel).
USE pncp_controladoria;

-- P1. Economia global: quanto (R$ e %) o governo economizou?
SELECT
    SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado   ELSE 0 END)                         AS estimado_comparavel,
    SUM(CASE WHEN comparavel = 1 THEN valor_total_homologado ELSE 0 END)                         AS homologado_comparavel,
    SUM(economia_valor)                                                                          AS economia_rs,
    ROUND(100 * SUM(economia_valor)
          / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0), 2)    AS economia_pct,
    SUM(comparavel)                                                                              AS itens_comparaveis,
    COUNT(*)                                                                                     AS itens_total,
    SUM(valor_total_homologado)                                                                  AS volume_homologado
FROM fato_item_contratado;

-- P2. Fornecedores: 10 maiores em volume e % do total concentrado
SELECT
    f.ni_fornecedor,
    f.nome_fornecedor,
    SUM(x.valor_total_homologado)                                                      AS volume,
    ROUND(100 * SUM(x.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)         AS pct_do_total
FROM fato_item_contratado x
JOIN dim_fornecedor f ON f.sk_fornecedor = x.sk_fornecedor
GROUP BY f.ni_fornecedor, f.nome_fornecedor
ORDER BY volume DESC
LIMIT 10;

-- P2b. Concentracao acumulada dos Top 10
SELECT ROUND(100 * SUM(volume) / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS concentracao_top10_pct
FROM (
    SELECT SUM(valor_total_homologado) AS volume
    FROM fato_item_contratado
    GROUP BY sk_fornecedor
    ORDER BY volume DESC
    LIMIT 10
) t;

-- P3. Modalidades: desagio e volume
SELECT
    m.modalidade_id,
    m.nome_modalidade,
    COUNT(*)                                                                                  AS itens,
    SUM(x.valor_total_homologado)                                                             AS volume,
    ROUND(100 * SUM(x.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)                AS pct_volume,
    SUM(x.economia_valor)                                                                     AS economia_rs,
    ROUND(100 * SUM(x.economia_valor)
          / NULLIF(SUM(CASE WHEN x.comparavel = 1 THEN x.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado x
JOIN dim_modalidade m ON m.sk_modalidade = x.sk_modalidade
GROUP BY m.modalidade_id, m.nome_modalidade
ORDER BY economia_pct DESC;

-- P4. Ciclo: media de dias entre publicacao e homologacao, por orgao (nome padronizado), >= 5 itens com ciclo
SELECT
    o.nome_orgao,
    COUNT(x.dias_ciclo)           AS itens_com_ciclo,
    COUNT(DISTINCT o.cnpj_orgao)  AS unidades,
    ROUND(AVG(x.dias_ciclo), 1)   AS ciclo_medio_dias,
    MAX(x.dias_ciclo)             AS ciclo_max_dias
FROM fato_item_contratado x
JOIN dim_orgao o ON o.sk_orgao = x.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(x.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC;

-- P4b. Indicadores gerais do ciclo
SELECT ROUND(AVG(dias_ciclo), 1) AS ciclo_medio, MAX(dias_ciclo) AS ciclo_max,
       COUNT(dias_ciclo) AS itens_com_ciclo, COUNT(*) - COUNT(dias_ciclo) AS itens_sem_ciclo
FROM fato_item_contratado;

-- P5a. Regional: por UF
SELECT
    l.uf_sigla,
    l.regiao,
    SUM(x.valor_total_homologado)                                                             AS volume,
    COUNT(DISTINCT x.sk_orgao)                                                                AS unidades_compradoras,
    ROUND(100 * SUM(x.economia_valor)
          / NULLIF(SUM(CASE WHEN x.comparavel = 1 THEN x.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado x
JOIN dim_localidade l ON l.sk_localidade = x.sk_localidade
GROUP BY l.uf_sigla, l.regiao
ORDER BY volume DESC;

-- P5b. Regional: por regiao
SELECT
    l.regiao,
    SUM(x.valor_total_homologado)                                                             AS volume,
    ROUND(100 * SUM(x.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)                AS pct_volume,
    ROUND(100 * SUM(x.economia_valor)
          / NULLIF(SUM(CASE WHEN x.comparavel = 1 THEN x.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado x
JOIN dim_localidade l ON l.sk_localidade = x.sk_localidade
GROUP BY l.regiao
ORDER BY volume DESC;

-- P6. Perfil do gasto (coluna da propria fato, sem JOIN)
SELECT
    perfil_gasto,
    COUNT(*)                                                                      AS itens,
    SUM(valor_total_homologado)                                                   AS volume,
    ROUND(100 * SUM(valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1)    AS pct_volume,
    ROUND(SUM(valor_total_homologado) / COUNT(*), 2)                              AS ticket_medio
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY volume DESC;
