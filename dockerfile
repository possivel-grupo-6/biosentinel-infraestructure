FROM amazonlinux:2

# Atualiza o sistema e instala dependências
RUN amazon-linux-extras enable python3.8 && \
    yum install -y python3.8 tar java-11-openjdk gzip && \
    python3.8 -m pip install --upgrade pip && \
    pip3 install pyspark jupyterlab boto3 --no-cache-dir


# Configura o Apache Spark
RUN curl -O https://downloads.apache.org/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz && \
    tar -xzf spark-3.5.3-bin-hadoop3.tgz -C /usr/local --owner root --group root --no-same-owner && \
    rm -f spark-3.5.3-bin-hadoop3.tgz && \
    mv /usr/local/spark-3.5.3-bin-hadoop3 /usr/local/spark

# Configura os diretórios para o Jupyter e notebooks
RUN mkdir -p /opt/jupyter/{notebook,script,logs,auto-run}
COPY move_client_db.ipynb move_raw_trusted.ipynb move_trusted_client.ipynb /opt/jupyter/notebook/

# Adiciona o script de inicialização
COPY configjupyter.sh /opt/jupyter/script/configjupyter.sh
RUN chmod +x /opt/jupyter/script/configjupyter.sh

# Define a pasta inicial do Jupyter
ENV JUPYTER_NOTEBOOK_DIR="/opt/jupyter/notebook"

# Expõe a porta padrão do Jupyter
EXPOSE 80

# Comando de inicialização
CMD ["/opt/jupyter/script/configjupyter.sh"]
