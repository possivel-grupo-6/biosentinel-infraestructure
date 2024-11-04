#!/bin/bash
amazon-linux-extras install java-openjdk11 -y
curl -O https://dlcdn.apache.org/spark/spark-3.2.1/spark-3.2.1-bin-hadoop3.2.tgz
tar -xzf spark-3.2.1-bin-hadoop3.2.tgz -C /usr/local --owner root --group root --no-same-owner
mkdir /usr/local/spark
mv /usr/local/spark-3.2.1-bin-hadoop3.2 /usr/local/spark
rm -rf spark-3.2.1-bin-hadoop3.2.tgz
pip3 install pyspark --no-cache-dir
pip3 install jupyterlab --no-cache-dir
echo "[Unit]
Description=Jupyter Notebook
[Service]
Type=simple
ExecStart=/opt/jupyter/script/start.sh
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target" > /lib/systemd/system/jupyter.service
mkdir -p /opt/jupyter/{notebook,script}
sudo mv move_client_db.ipynb move_raw_trusted.ipynb move_trusted_client.ipynb /opt/jupyter/notebook
echo '#!/bin/bash
/usr/bin/python3 -m notebook --NotebookApp.notebook_dir=/opt/jupyter/notebook --NotebookApp.password=$(/usr/bin/python3 -c "from notebook.auth import passwd; print(passwd(\"${var.ec2_jupyter_password}\"))") --allow-root --ip 0.0.0.0 --port 80' > /opt/jupyter/script/start.sh
chmod +x /opt/jupyter/script/start.sh
systemctl daemon-reload
systemctl start jupyter
systemctl enable jupyter
