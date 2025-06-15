FROM python:3.11-slim

# 必要パッケージのインストール
RUN apt-get update && apt-get install -y \
    unzip libaio1 wget && \
    rm -rf /var/lib/apt/lists/*

# Oracle Instant Client のダウンロードと展開（任意のバージョンを選んでOK）
WORKDIR /opt/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/1918000/instantclient-basic-linux.x64-19.18.0.0.0dbru.zip && \
    wget https://download.oracle.com/otn_software/linux/instantclient/1918000/instantclient-sdk-linux.x64-19.18.0.0.0dbru.zip && \
    unzip instantclient-basic-linux.x64-19.18.0.0.0dbru.zip && \
    unzip instantclient-sdk-linux.x64-19.18.0.0.0dbru.zip && \
    rm *.zip

# 環境変数の設定
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_19_18
ENV PATH=$LD_LIBRARY_PATH:$PATH

# Pythonライブラリのインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# 作業ディレクトリ
WORKDIR /app
COPY . .

CMD ["python", "main.py"]
