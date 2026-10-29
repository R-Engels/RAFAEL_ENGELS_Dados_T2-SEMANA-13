"""verificar.py - prova real no BANCO (anexo 8). Rodar: python -m src.verificar
Executa as consultas de sql/02_perguntas.sql, imprime os resultados e compara os totais com o anexo 8."""
import re
import sys

from src import banco, config

ESPERADO = {  # (rotulo, consulta, esperado, tolerancia)
    "itens na fato": ("SELECT COUNT(*) FROM fato_item_contratado", 6126, 0),
    "contratacoes distintas": ("SELECT COUNT(DISTINCT numero_controle_pncp) FROM fato_item_contratado", 1962, 0),
    "volume homologado": ("SELECT SUM(valor_total_homologado) FROM fato_item_contratado", 8044498805.74, 1),
    "estimado total": ("SELECT SUM(valor_total_estimado) FROM fato_item_contratado", 32629639732.13, 1),
    "estimado comparavel": ("SELECT SUM(CASE WHEN comparavel=1 THEN valor_total_estimado END) FROM fato_item_contratado", 6867663469.91, 1),
    "itens comparaveis": ("SELECT SUM(comparavel) FROM fato_item_contratado", 5457, 0),
    "economia (R$)": ("SELECT SUM(economia_valor) FROM fato_item_contratado", 992861686.95, 1),
    "economia (%)": ("SELECT ROUND(100*SUM(economia_valor)/SUM(CASE WHEN comparavel=1 THEN valor_total_estimado END),2) FROM fato_item_contratado", 14.46, 0.005),
    "sobrepreco": ("SELECT COUNT(*) FROM fato_item_contratado WHERE comparavel=1 AND economia_valor < 0", 27, 0),
    "itens com ciclo": ("SELECT COUNT(dias_ciclo) FROM fato_item_contratado", 5896, 0),
    "ciclo medio": ("SELECT ROUND(AVG(dias_ciclo),1) FROM fato_item_contratado", 48.1, 0.05),
    "ciclo maximo": ("SELECT MAX(dias_ciclo) FROM fato_item_contratado", 611, 0),
    "itens sem ciclo": ("SELECT COUNT(*)-COUNT(dias_ciclo) FROM fato_item_contratado", 230, 0),
    "perfil Obras (%)": ("SELECT ROUND(100*SUM(CASE WHEN perfil_gasto='Obras e engenharia' THEN valor_total_homologado END)/SUM(valor_total_homologado),1) FROM fato_item_contratado", 60.8, 0.05),
    "unidades compradoras": ("SELECT COUNT(DISTINCT sk_orgao) FROM fato_item_contratado", 363, 0),
}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    con = banco.conectar()
    falhas = 0
    print("=== PROVA REAL (banco x anexo 8) ===")
    for rotulo, (sql, esperado, tol) in ESPERADO.items():
        obtido = float(banco.consultar(con, sql)[0][0])
        ok = abs(obtido - esperado) <= tol
        falhas += not ok
        print(f"{'✔' if ok else '✘'} {rotulo:24s} obtido={obtido:>20,.2f} esperado={esperado:>20,.2f}")

    print("\n=== sql/02_perguntas.sql ===")
    texto = (config.PASTA_SQL / "02_perguntas.sql").read_text(encoding="utf-8-sig")
    for cmd in banco._separar_comandos(texto):
        if cmd.upper().startswith("USE"):
            continue
        cur = con.cursor()
        cur.execute(cmd)
        print("\n" + " | ".join(c[0] for c in cur.description))
        for linha in cur.fetchall()[:12]:
            print(" | ".join(str(v) for v in linha))
        cur.close()
    con.close()
    print(f"\n{'TUDO CONFERE ✔' if not falhas else f'{falhas} DIVERGENCIA(S) ✘'}")
    return falhas


if __name__ == "__main__":
    raise SystemExit(1 if main() else 0)
