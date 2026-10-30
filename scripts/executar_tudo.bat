@echo off
REM Reproduz o pipeline completo: limpeza -> tabelas -> MySQL -> prova real.
REM Pre-requisitos: Python 3.10+, MySQL 8 no ar, arquivo .env criado a partir do .env.example.
chcp 65001 >nul
cd /d "%~dp0.."

if not exist .env (
    echo [ERRO] Crie o arquivo .env a partir do .env.example e preencha MYSQL_PASSWORD.
    exit /b 1
)

echo [1/5] Instalando dependencias...
python -m pip install -q -r requirements.txt || goto erro
echo [2/5] Autoteste da limpeza...
python -m src.limpeza || goto erro
echo [3/5] Montando fato e dimensoes (data/processed)...
python -m src.montar_tabelas || goto erro
echo [4/5] Carregando no MySQL...
python -m src.carregar || goto erro
echo [5/5] Prova real no banco (anexo 8) e perguntas SQL...
python -m src.verificar || goto erro
echo.
echo PIPELINE COMPLETO COM SUCESSO.
exit /b 0

:erro
echo.
echo [FALHA] Etapa anterior terminou com erro. Veja a mensagem acima.
exit /b 1
