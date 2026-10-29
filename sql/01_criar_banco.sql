-- 01_criar_banco.sql : Star Schema da Controladoria PNCP (1 fato + 4 dimensoes)
-- Executado por src/carregar.py. Recria o banco do zero (idempotente).
CREATE DATABASE IF NOT EXISTS pncp_controladoria CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE pncp_controladoria;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS fato_item_contratado;
DROP TABLE IF EXISTS dim_orgao;
DROP TABLE IF EXISTS dim_fornecedor;
DROP TABLE IF EXISTS dim_modalidade;
DROP TABLE IF EXISTS dim_localidade;
SET FOREIGN_KEY_CHECKS = 1;

-- sk_ = chave substituta (INT com sinal: aceita a linha -1 "Nao informado").
-- A carga informa o sk_ explicitamente; AUTO_INCREMENT nao e usado.
CREATE TABLE dim_orgao (
    sk_orgao   INT          NOT NULL,
    cnpj_orgao VARCHAR(14)  NOT NULL,
    nome_orgao VARCHAR(255) NOT NULL,
    poder      VARCHAR(20)  NOT NULL,
    PRIMARY KEY (sk_orgao),
    UNIQUE KEY uq_orgao_cnpj (cnpj_orgao)
) ENGINE=InnoDB;

CREATE TABLE dim_fornecedor (
    sk_fornecedor   INT          NOT NULL,
    ni_fornecedor   VARCHAR(30)  NOT NULL,
    nome_fornecedor VARCHAR(255) NULL,
    tipo_pessoa     VARCHAR(5)   NULL,
    porte           VARCHAR(60)  NULL,
    PRIMARY KEY (sk_fornecedor),
    UNIQUE KEY uq_fornecedor_ni (ni_fornecedor)
) ENGINE=InnoDB;

CREATE TABLE dim_modalidade (
    sk_modalidade   INT          NOT NULL,
    modalidade_id   INT          NOT NULL,
    nome_modalidade VARCHAR(60)  NOT NULL,
    PRIMARY KEY (sk_modalidade),
    UNIQUE KEY uq_modalidade_id (modalidade_id)
) ENGINE=InnoDB;

CREATE TABLE dim_localidade (
    sk_localidade INT         NOT NULL,
    uf_sigla      VARCHAR(2)  NOT NULL,
    uf_nome       VARCHAR(40) NULL,
    regiao        VARCHAR(20) NOT NULL,
    PRIMARY KEY (sk_localidade),
    UNIQUE KEY uq_localidade_uf (uf_sigla)
) ENGINE=InnoDB;

CREATE TABLE fato_item_contratado (
    sk_fato                   INT           NOT NULL AUTO_INCREMENT,
    numero_controle_pncp      VARCHAR(60)   NOT NULL,
    numero_item               INT           NOT NULL,
    sk_orgao                  INT           NOT NULL,
    sk_fornecedor             INT           NOT NULL,
    sk_modalidade             INT           NOT NULL,
    sk_localidade             INT           NOT NULL,
    data_publicacao           DATE          NULL,
    data_homologacao          DATE          NULL,
    descricao_item            TEXT          NULL,
    perfil_gasto              VARCHAR(30)   NOT NULL,
    quantidade                DECIMAL(18,4) NOT NULL,
    valor_unitario_estimado   DECIMAL(18,4) NOT NULL,
    valor_total_estimado      DECIMAL(18,2) NOT NULL,
    valor_unitario_homologado DECIMAL(18,4) NOT NULL,
    valor_total_homologado    DECIMAL(18,2) NOT NULL,
    comparavel                TINYINT       NOT NULL,
    economia_valor            DECIMAL(18,2) NULL,
    dias_ciclo                INT           NULL,
    PRIMARY KEY (sk_fato),
    UNIQUE KEY uq_fato_item (numero_controle_pncp, numero_item),
    CONSTRAINT fk_fato_orgao      FOREIGN KEY (sk_orgao)      REFERENCES dim_orgao (sk_orgao),
    CONSTRAINT fk_fato_fornecedor FOREIGN KEY (sk_fornecedor) REFERENCES dim_fornecedor (sk_fornecedor),
    CONSTRAINT fk_fato_modalidade FOREIGN KEY (sk_modalidade) REFERENCES dim_modalidade (sk_modalidade),
    CONSTRAINT fk_fato_localidade FOREIGN KEY (sk_localidade) REFERENCES dim_localidade (sk_localidade),
    CONSTRAINT ck_fato_quantidade CHECK (quantidade > 0),
    CONSTRAINT ck_fato_valores    CHECK (valor_unitario_estimado >= 0 AND valor_unitario_homologado >= 0
                                         AND valor_total_estimado >= 0 AND valor_total_homologado >= 0),
    CONSTRAINT ck_fato_comparavel CHECK (comparavel IN (0, 1)),
    CONSTRAINT ck_fato_ciclo      CHECK (dias_ciclo IS NULL OR dias_ciclo >= 0)
) ENGINE=InnoDB;

CREATE INDEX ix_fato_publicacao ON fato_item_contratado (data_publicacao);
CREATE INDEX ix_fato_perfil     ON fato_item_contratado (perfil_gasto);

-- Linhas "Nao informado" (sk = -1): destino de FK sem dado. Chave natural com valor que nao existe nas demais.
INSERT INTO dim_orgao      (sk_orgao, cnpj_orgao, nome_orgao, poder)            VALUES (-1, 'NAO-INFORMADO', 'NÃO INFORMADO', 'Não informado');
INSERT INTO dim_fornecedor (sk_fornecedor, ni_fornecedor, nome_fornecedor, tipo_pessoa, porte) VALUES (-1, 'NAO-INFORMADO-DIM', 'NÃO INFORMADO', NULL, NULL);
INSERT INTO dim_modalidade (sk_modalidade, modalidade_id, nome_modalidade)     VALUES (-1, -1, 'Não informado');
INSERT INTO dim_localidade (sk_localidade, uf_sigla, uf_nome, regiao)          VALUES (-1, 'NI', 'NÃO INFORMADO', 'Não informado');
