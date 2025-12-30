
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
import tempfile

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
                  wallet_dir: str = ""
                  ):


        self.user = user
        self.password = password
        self.dataset_name = dataset_name
        self.wallet_password = wallet_password
        self._base64_wallet_text = base64_wallet_text
        self._wallet_dir = wallet_dir


    def __enter__(self):

        if self._wallet_dir == "":

            self._wallet_dir = "./worker/python/wallet"
            # walletのbase64テキストからzipファイルを作成して展開

            with tempfile.NamedTemporaryFile(suffix=".zip") as temp_wallet_file:

                # 2. base64 デコードして zip ファイルとして保存
                with open(temp_wallet_file.name, "wb") as f:
                    f.write(base64.b64decode(self._base64_wallet_text))

                # 3. zip を展開
                with zipfile.ZipFile(temp_wallet_file, "r") as z:
                    z.extractall(".")

        for f in Path(self._wallet_dir).rglob("*"):
            if f.is_file():
                print(f)

        oracledb.init_oracle_client(
            config_dir=str(self._wallet_dir)
            )


        self.connection = oracledb.connect(user=self.user, password=self.password, dsn=self.dataset_name)

        return(self)


    def set_logger(self,logger: Callable[[str], None]):
        self.logger = logger
    

    def select(self, name: str) -> pd.DataFrame:
        sql_select: str =  f"SELECT * FROM {name}"
        return pd.read_sql(sql_select, con=self.connection)
    
    def get_tables(self):
        cursor = self.connection.cursor()

        # ログインユーザーの所有するテーブル一覧を取得
        cursor.execute("SELECT table_name FROM user_tables")

        tables = cursor.fetchall()
        for table in tables:
            print(table[0])

        cursor.close()

    def delete(self, name:str):
        with self.connection.cursor() as cursor:
            sql_delete: str =  f"TRUNCATE TABLE {name}"
            cursor.execute(sql_delete)
            self.connection.commit()

        self.logger(f"{name} Deleted")

    def _create_temp_table(self, name:str, temp_name:str = "", cols: list = None) -> str:

        if temp_name == "":
            temp_name = f"TEMP_{name}"

        if cols is None:
            col_list = "*"
        else:
            col_list = ", ".join(cols)

        with self.connection.cursor() as cursor:
            sql_create: str =  f"""
                CREATE GLOBAL TEMPORARY TABLE {temp_name}
                ON COMMIT PRESERVE ROWS
                AS SELECT {col_list} FROM {name} WHERE 1=0
            """ 
            cursor.execute(sql_create)
            self.connection.commit()

        self.logger(f"{temp_name} Created")
        return(temp_name)

    def sync_from_df(self, name:str, df:pd.DataFrame, key_cols: list = None,):

        if len(df) >= 1:

            columns = df.columns.values
            key_cols = key_cols if key_cols is not None else columns.tolist()
            self.merge_from_df(name, df, key_cols)

            temp_name: str = f"TEMP_{name}"

            condition = " AND ".join([f"t.{col} = s.{col}" for col in key_cols])

            sql_delete = f"""
                DELETE FROM {name} t
                WHERE NOT EXISTS (
                SELECT 1
                FROM {temp_name} s
                WHERE {condition}
                )
                """
            print(sql_delete)


            with self.connection.cursor() as cursor:
                cursor.execute(sql_delete)
                self.connection.commit()
        
            self.logger(f"{name} Sync End ")


    def merge_from_df(self, name:str, df:pd.DataFrame, key_cols: list = None, source :str = ""):
        
        if len(df) >= 1:

            if source != "":
                self.logger(f"{source}")

            self.logger(f"{name} Merge Start : {len(df)} Record")
            

            temp_name: str = f"TEMP_{name}"
            if not self.exists_table(temp_name):
                self._create_temp_table(name, temp_name, key_cols)

            self.insert_from_df(temp_name,df)

            columns = df.columns.values
            key_cols = key_cols if key_cols is not None else columns.tolist()
            condition = " AND ".join([f"t.{col} = s.{col}" for col in key_cols])

            sql_merge = f"""
                MERGE INTO {name} t
                    USING {temp_name} s
                    ON ({condition})
                WHEN NOT MATCHED THEN
                    INSERT ({', '.join(columns)})
                    VALUES ({', '.join([f"s.{col}" for col in columns])})
                """
            print(sql_merge)

            with self.connection.cursor() as cursor:
                cursor.execute(sql_merge)
                self.connection.commit()
        
            self.logger(f"{name} Merge End ")

    def insert_from_df(self, name:str, df:pd.DataFrame, source :str = "", batch_size: int = 0):
        
        if len(df) >= 1:
            
            if source != "":
                self.logger(f"{source}")

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

            
        
        

    def exists_table(self, name: str) -> bool:
        with self.connection.cursor() as cursor:
            sql_check = f"""
                SELECT COUNT(*) FROM user_tables WHERE table_name = UPPER(:table_name)
            """
            cursor.execute(sql_check, table_name=name)
            count = cursor.fetchone()[0]
            return count > 0

    def execute_proc(self, proc_name: str):
        self.logger(f"{proc_name} proc Execute Start")
        with self.connection.cursor() as cursor:
            cursor.callproc(proc_name)
            self.connection.commit()
        self.logger(f"{proc_name} proc Execute End")

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
            
        if self._wallet_dir != "" and os.path.exists(self._wallet_dir):
            shutil.rmtree(self._wallet_dir)
