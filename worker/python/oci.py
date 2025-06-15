
import oracledb

import traceback
from pathlib import Path
import base64
import zipfile
import tempfile
import os
import shutil
import io
import sys

import pandas as pd

from typing import Callable

class OCI:

    user: str = None
    password: str = None
    dataset_name: str = None
    wallet_password: str = None


    _base64_wallet_text: str = ""
    _work_dir: str = None
    _wallet_dir: str = None

    logger: Callable[[str], None] = print

    def __init__(self,
                  user: str,
                  password: str, 
                  dataset_name: str,
                  base64_wallet_text: str,
                  wallet_password: str,
                  work_dir: str = ".", wallet_name: str = "wallet"):


        self.user = user
        self.password = password
        self.dataset_name = dataset_name
        self.wallet_password = wallet_password
        self._base64_wallet_text = base64_wallet_text
        self._work_dir = work_dir
        self._wallet_dir = Path(work_dir) / wallet_name


    def __enter__(self):

        # デコード後のZIPファイルを一時ファイルとして作成
        with tempfile.NamedTemporaryFile(mode='w+b') as temp_file:

            # ファイル名を取得
            temp_file_name = temp_file.name

            # Base64デコードして元のバイナリデータに戻す
            decoded = base64.b64decode(self._base64_wallet_text)
           
            # 一時ファイルにデータを書き込む
            temp_file.write(decoded)
            
            # ファイルポインタを先頭に戻す
            temp_file.seek(0)

            # 解凍先のディレクトリのパス
            extract_dir = self._wallet_dir

            # 解凍先のディレクトリが存在する場合は削除
            if os.path.exists(extract_dir):
                shutil.rmtree(extract_dir)

            # 解凍先のディレクトリを作成
            os.makedirs(extract_dir)

            # ZIPファイルを解凍する
            with zipfile.ZipFile(io.BytesIO(temp_file.read()), 'r') as zip_ref:
                zip_ref.extractall(extract_dir)


        params = oracledb.ConnectParams(wallet_location = str(self._wallet_dir), wallet_password = self.wallet_password)
       
        self.connection = oracledb.connect(user=self.user, password=self.password, dsn=self.dataset_name, params=params)

        return(self)


    def set_logger(self,logger: Callable[[str], None]):
        self.logger = logger
    
    def insert_from_df(self, name:str, df:pd.DataFrame, batch_size: int = 0):
        
        if len(df) >= 1:
            
            self.logger(f"{name} Insert Start : {len(df)} Record")
            
            columns = df.columns.values

            params = ",".join([f":{i + 1}" for i in range(len(columns))])

            sql_insert = f"INSERT INTO {name} ({','.join(columns)}) VALUES ({params})"

            with self.connection.cursor() as cursor:
                data_to_insert = []

                if batch_size == 0:
                    for row in df.values:
                        data_to_insert.append(list(row))

                    # データの一括挿入
                    cursor.executemany(sql_insert, data_to_insert)
                    self.connection.commit()

                else:

                    for i in range(0, len(df), batch_size):
                        data_to_insert = [list(row) for row in df.values[i:i+batch_size]]
                        cursor.executemany(sql_insert, data_to_insert)
                        self.connection.commit()
        
            self.logger(f"{name} Insert End ")

            
        
        
        
    
    def migration(self, dir_path: str, is_up:bool):

        if is_up:
            src_dir =  Path(dir_path) / "up"
            is_asc = True
        else:
            src_dir =  Path(dir_path) / "down"
            is_asc = False

        # グロブパターンでファイルを取得
        query_files = list(src_dir.glob("*.*"))

        # ファイル名でソート
        sorted_query_files = sorted(query_files, key=lambda x: int(x.stem), reverse=(not is_asc))


        with self.connection.cursor() as cursor:

            for query_file in sorted_query_files:
                print(query_file)
                with open(query_file, 'r') as file:
                    query = file.read()

                try:
                    cursor.execute(query)
                except Exception as e:
                    print(f"エラーが発生しました: {e}")
                    print(f"エラーが発生しまファイル: {query_file}")
                    print(f"エラーが発生したクエリ: {query}")
                    # エラーのトレースバックを表示
                    traceback.print_exc()
                    # プログラムを終了
                    sys.exit(1)


    def __exit__(self, exc_type, exc_value, traceback):
            
        if self._wallet_dir and os.path.exists(self._wallet_dir):
            shutil.rmtree(self._wallet_dir)
