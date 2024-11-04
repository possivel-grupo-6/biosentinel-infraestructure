#!/bin/bash
sudo amazon-linux-extras install java-openjdk11 -y
curl -O https://downloads.apache.org/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz
sudo tar -xzf spark-3.5.3-bin-hadoop3.tgz -C /usr/local --owner root --group root --no-same-owner
rm -f spark-3.5.3-bin-hadoop3.tgz
sudo mv /usr/local/spark-3.5.3-bin-hadoop3 /usr/local/spark
sudo pip3 install pyspark --no-cache-dir 
sudo pip3 install jupyterlab --no-cache-dir
sudo tee /lib/systemd/system/jupyter.service > /dev/null <<EOT
[Unit]
Description=Jupyter Notebook
After=network.target

[Service]
Type=simple
ExecStart=/opt/jupyter/script/start.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOT
sudo mkdir -p /opt/jupyter/{notebook,script}
sudo mv /tmp/scripts/move_client_db.ipynb /tmp/scripts/move_raw_trusted.ipynb /tmp/scripts/move_trusted_client.ipynb /opt/jupyter/notebook
sudo tee /opt/jupyter/script/start.sh > /dev/null <<EOT
#!/bin/bash
PASSWORD_HASH=\$(/usr/bin/python3 -c "from notebook.auth import passwd; print(passwd('urubu100'))")
/usr/bin/python3 -m notebook --NotebookApp.notebook_dir=/opt/jupyter/notebook --NotebookApp.password=\$PASSWORD_HASH --allow-root --ip 0.0.0.0 --port 80
EOT
sudo chmod +x /opt/jupyter/script/start.sh
sudo systemctl daemon-reload
sudo systemctl start jupyter
sudo systemctl enable jupyter
sudo pip3 install boto3
sudo tee /lib/systemd/system/raw-monitor.service > /dev/null <<EOT
[Unit]
Description=Monitorar o bucket S3 e executar script PySpark

[Service]
ExecStart=/usr/bin/python3 /tmp/scripts/raw-monitor.py
Restart=always

[Install]
WantedBy=multi-user.target
EOT
sudo systemctl enable monitor_s3.service
sudo systemctl start monitor_s3.service
