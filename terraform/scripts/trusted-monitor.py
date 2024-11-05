import boto3
import time
from subprocess import call

# Configurações
BUCKET_NAME = 'bucket-bio-sentinel-trusted'
NOTEBOOK_PATH = '/opt/jupyter/notebook/move_trusted_client.ipynb'
INTERVALO = 10  # Intervalo de verificação em segundos

# Conectar ao S3
s3_client = boto3.client('s3')

def listar_arquivos(bucket_name):
    response = s3_client.list_objects_v2(Bucket=bucket_name)
    if 'Contents' in response:
        return {obj['Key'] for obj in response['Contents']}
    return set()

def main():
    arquivos_anteriores = listar_arquivos(BUCKET_NAME)
    
    while True:
        time.sleep(INTERVALO)
        arquivos_atualizados = listar_arquivos(BUCKET_NAME)
        
        novos_arquivos = arquivos_atualizados - arquivos_anteriores
        if novos_arquivos:
            print(f"Novos arquivos detectados: {novos_arquivos}")
            
            # Executar o notebook Jupyter
            call(['jupyter', 'nbconvert', '--to', 'notebook', '--execute', NOTEBOOK_PATH])
            
            # Atualizar a lista de arquivos
            arquivos_anteriores = arquivos_atualizados

if __name__ == "__main__":
    main()
