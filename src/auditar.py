"""auditar.py - Sprint 1: conta os problemas dos CSVs brutos. Rodar: python -m src.auditar
Gera docs/auditoria.md (cada problema e quantos registros afeta)."""
import re

import pandas as pd

from src import config, limpeza


def ler(nome):
    return pd.read_csv(config.PASTA_RAW / f"{nome}.csv", dtype=str, keep_default_na=False)

COLUNAS_DINHEIRO = {"itens": ["quantidade", "valor_unitario_estimado", "valor_total_estimado"],
                    "resultados": ["quantidade_homologada", "valor_unitario_homologado", "valor_total_homologado"]}
COLUNAS_DATA = {"compras": ["data_publicacao"], "resultados": ["data_resultado"]}
MOJIBAKE = re.compile("Ã.|Â.")


def nulos_disfarcados(df):
    """Colunas com N/A, NULL, -, SEM INFORMACAO...: conta (exclui vazio e '0' para nao inflar)."""
    out = {}
    for c in df.columns:
        n = int(df[c].map(lambda v: v.strip().upper() in limpeza.NULOS and v.strip() != "0").sum())
        if n:
            out[c] = n
    return out


def main():
    d = {n: ler(n) for n in ["compras", "itens", "resultados"]}
    L = ["# Auditoria dos dados brutos (Sprint 1)", "",
         "Gerado por `python -m src.auditar`. Leitura com `dtype=str` (nada converte sozinho).", "",
         "## Tamanho dos arquivos", "", "| Arquivo | Linhas | Colunas |", "|---|---:|---:|"]
    for n, df in d.items():
        L.append(f"| {n}.csv | {len(df):,} | {df.shape[1]} |".replace(",", "."))
    c, i, r = d["compras"], d["itens"], d["resultados"]
    L += ["", f"- `numero_controle_pncp` repetido em compras.csv: **{int(c['numero_controle_pncp'].duplicated().sum())}**",
          f"- Chave (`numero_controle_pncp`+`numero_item`) repetida em itens.csv: **{int(i.duplicated(['numero_controle_pncp','numero_item']).sum())}**",
          "", "## Desafio 1 - CNPJ/CPF", ""]
    cn = c["cnpj_orgao"]
    L.append(f"- compras.cnpj_orgao com máscara (`.`, `/`, `-`): **{int(cn.str.contains(r'[./-]').sum())}**")
    L.append(f"- compras.cnpj_orgao sem máscara com < 14 dígitos (zero perdido): **{int((~cn.str.contains(r'[./-]') & (cn.str.len() < 14) & (cn.str.len() > 0)).sum())}**")
    ni = r["ni_fornecedor"]
    L.append(f"- resultados.ni_fornecedor com máscara: **{int(ni.str.contains(r'[./-]').sum())}**")
    L.append(f"- resultados.ni_fornecedor vazio/lixo: **{int(ni.map(lambda v: limpeza.eh_nulo(v.strip())).sum())}**")
    L.append("- Tipos de pessoa em resultados: " + ", ".join(f"{k}={v}" for k, v in r["tipo_pessoa"].value_counts().items()))
    L += ["", "## Desafio 2 - Dinheiro e decimais", ""]
    for arq, cols in COLUNAS_DINHEIRO.items():
        for col in cols:
            s = d[arq][col]
            rs = int(s.str.contains("R\\$").sum()); par = int(s.str.startswith("(").sum())
            neg = int(s.str.contains("-").sum()); vir = int(s.str.contains(",").sum())
            falha = int((s.map(limpeza.converter_numero).isna() & ~s.map(lambda v: limpeza.eh_nulo(v.strip(), False))).sum())
            L.append(f"- {arq}.{col}: com `R$` **{rs}**, com vírgula **{vir}**, entre parênteses **{par}**, com `-` **{neg}**, não convertíveis **{falha}**")
    L += ["", "## Desafio 3 - Datas", ""]
    for arq, cols in COLUNAS_DATA.items():
        for col in cols:
            s = d[arq][col]
            fmt = s.str.replace(r"\d", "9", regex=True).value_counts().head(8)
            L.append(f"- {arq}.{col}: máscaras → " + "; ".join(f"`{k}` ({v})" for k, v in fmt.items()))
            L.append(f"  - não convertíveis/vazias: **{int(s.map(limpeza.converter_data).isna().sum())}**")
    pub = c.set_index("numero_controle_pncp")["data_publicacao"].map(limpeza.converter_data)
    rr = r.assign(h=r["data_resultado"].map(limpeza.converter_data),
                  p=r["numero_controle_pncp"].map(pub))
    inv = rr[rr["h"].notna() & rr["p"].notna()].pipe(lambda x: x[x["h"] < x["p"]])
    L.append(f"- resultados com `data_resultado` **anterior** à publicação: **{len(inv)}**")
    L += ["", "## Desafio 4 - Nulos disfarçados", ""]
    for n, df in d.items():
        for col, k in nulos_disfarcados(df).items():
            L.append(f"- {n}.{col}: **{k}**")
    L += ["", "## Desafio 5 - Encoding e nomes", ""]
    for n, df in d.items():
        for col in df.columns:
            k = int(df[col].str.contains(MOJIBAKE).sum())
            if k:
                L.append(f"- {n}.{col} com acento quebrado (Ã§, Ã£...): **{k}**")
    L.append(f"- Nomes de órgão distintos (bruto): **{c['razao_social_orgao'].nunique()}** → padronizados: **{c['razao_social_orgao'].map(limpeza.padronizar_nome).nunique()}**")
    L.append(f"- CNPJ de órgão distintos (bruto): **{c['cnpj_orgao'].nunique()}** → limpos: **{c['cnpj_orgao'].map(lambda v: limpeza.limpar_documento(v, 'PJ')).nunique()}**")
    L.append(f"- Nomes de fornecedor distintos (bruto): **{r['nome_fornecedor'].nunique()}** → padronizados: **{r['nome_fornecedor'].map(limpeza.padronizar_nome).nunique()}**")
    L += ["", "## Regras de negócio - contagens", ""]
    canc = r["data_cancelamento"].str.strip() != ""
    L.append(f"- resultados cancelados (`data_cancelamento` preenchida): **{int(canc.sum())}**")
    L.append(f"- itens com `tem_resultado` = True: **{int((i['tem_resultado'].str.lower() == 'true').sum())}**")
    L.append(f"- itens sigilosos: **{int((i['sigiloso'].str.lower() == 'true').sum())}**")
    L.append(f"- itens em Credenciamento (modalidade 12, não comparáveis): **{int(i.merge(c[['numero_controle_pncp','modalidade_id']], on='numero_controle_pncp')['modalidade_id'].eq('12').sum())}**")
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    print("\n".join(L))


if __name__ == "__main__":
    main()
