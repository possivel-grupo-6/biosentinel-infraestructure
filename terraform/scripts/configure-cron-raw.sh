#!/bin/bash
SCRIPT_PATH="/opt/jupyter/notebook/auto-run/cron-raw.sh"
LOG_PATH="/opt/jupyter/logs/log-raw.txt"
USER="ec2-user"
CRON_SCHEDULE="*/10 * * * *"
if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Erro: O script $SCRIPT_PATH não foi encontrado."
  exit 1
fi
if [ ! -d "$(dirname "$LOG_PATH")" ]; then
  echo "Erro: O diretório do log $(dirname "$LOG_PATH") não foi encontrado."
  exit 1
fi
echo "Configurando permissões no diretório..."
sudo chown -R $USER:$USER "$(dirname "$SCRIPT_PATH")"
sudo chown -R $USER:$USER "$(dirname "$LOG_PATH")"
sudo chmod -R 770 "$(dirname "$SCRIPT_PATH")"
sudo chmod -R 770 "$(dirname "$LOG_PATH")"
echo "Permissões configuradas para $USER."
echo "Adicionando o cron job para executar o script a cada 10 minutos..."
(crontab -l; echo "$CRON_SCHEDULE $SCRIPT_PATH >> $LOG_PATH 2>&1") | crontab -
echo "Cron job adicionado."
echo "Verificando cron job..."
crontab -l | grep "$SCRIPT_PATH"
if [ $? -eq 0 ]; then
  echo "Cron job configurado com sucesso."
else
  echo "Falha ao configurar o cron job."
fi
echo "Configuração concluída."
echo "Os logs serão armazenados em $LOG_PATH."
