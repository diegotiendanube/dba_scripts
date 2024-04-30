#!/bin/bash

# Arquivo contendo as configurações de conexão
CONNECTION_LIST="lista_conexoes.txt"

# Configuração de login para o banco de destino
DEST_CONFIG="data-dba"

# Nome do arquivo CSV para salvar os resultados
CSV_FILE="session_kill.csv"

# Loop através das configurações de conexão no arquivo
while IFS= read -r config; do
    # Extrair o texto da segunda posição, separando por ":"
    endpoint=$(echo "$config" | cut -d ":" -f 2)
    # Executar a procedure com a conexão atual e salvar o resultado em um arquivo CSV
    mysql --login-path=dba_crontab -h "$endpoint" -e "call monitoring.sp_monitoring_kill_rds('dba_crontab,root,redash_appl', 1);" | awk -v endpoint="$endpoint" 'BEGIN {FS="\t"} {print endpoint","$1","$2","$3","$4","$5","$6","$7","$8","$9","$10","$11","$12}' > $CSV_FILE

    # Verificar se o arquivo CSV tem mais de uma linha
    if [ $(wc -l < $CSV_FILE) -gt 1 ]; then
        # Abre uma nova conexão com o banco de destino e insere os dados na tabela history_kill_rds
        while IFS=',' read -r rds_aws_name execution_date execution_status processlist_id thread_id user_name host_name data_base_name execution_time tx_query sql_state erro_number text_information; do
            mysql --login-path=$DEST_CONFIG -e "INSERT INTO aws_repository.history_kill_rds (rds_aws_name, execution_date, execution_status, processlist_id, thread_id, user_name, host_name, data_base_name, execution_time, tx_query, sql_state, erro_number, text_information) VALUES ('$rds_aws_name', '$execution_date', '$execution_status', '$processlist_id', '$thread_id', '$user_name', '$host_name', '$data_base_name', '$execution_time', '$tx_query', '$sql_state', '$erro_number', '$text_information');"
        done < <(tail -n +2 $CSV_FILE)
    fi

    # Deletar o arquivo CSV
    rm $CSV_FILE
done < "$CONNECTION_LIST"
