
from oci import OCI

from pathlib import Path
import re
import shutil
import os

def format_query_core(base: str, exec_exist: bool, declare: str, get_count:str, comment: str, condition: str):

    base = re.sub(r'\n', r'\n' + " " * 12 , base)
    base = re.sub(r"'", r"''" , base)

    if exec_exist:
        check_comment = "存在する"
        check_count = 1
    else:
        check_comment = "存在しない"
        check_count = 0

    return(f"""
    DECLARE
        {declare}
    BEGIN
        {get_count}

        -- {comment.format(check_comment = check_comment)}
        {condition.format(check_count = check_count)}
            EXECUTE IMMEDIATE '
            {base}
            ';
        END IF;
        
    END;
    """
    )


def format_constraint_query(base: str, name: str, exec_exist: bool, key_name:str, key_kind:str):

    declare = """
        table_count NUMBER;
        constraint_count NUMBER;
    """

    # if key_name[0] == '"':
    #     con_name = key_name.replace('"', '')
    # else:
    #     con_name = key_name.upper()

   

    get_count = f"""
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = '{name.upper()}';

        -- 制約の存在を確認
        SELECT COUNT(*)
        INTO constraint_count
        FROM all_constraints
        WHERE constraint_name = '{key_name.upper()}'
        AND table_name = '{name.upper()}';
    """

    comment = """
        -- テーブルが存在して制約が{check_comment}場合のみ実行
    """

    condition = """
        IF table_count = 1 AND constraint_count = {check_count} THEN
    """

    return(format_query_core(base, exec_exist, declare, get_count, comment, condition))


def format_table_query(base: str, name: str, exec_exist: bool):

    declare = """
        table_count NUMBER;
    """

    get_count = f"""
        -- テーブルの存在を確認
        SELECT COUNT(*)
        INTO table_count
        FROM user_tables
        WHERE table_name = '{name.upper()}';
    """

    comment = """
        -- テーブルが{check_comment}場合のみ実行
    """

    condition = """
        IF table_count = {check_count} THEN
    """

    return(format_query_core(base, exec_exist, declare, get_count, comment, condition))




def pg_dump_convert_ora_migrations(dump_file_path: str, dest_dir_path: str):

    with open(dump_file_path, 'r') as file:
        sql_content = file.read()

    query_pattern = re.compile(
        r'(?P<method>(CREATE|COMMENT ON|ALTER)) TABLE\s+(?P<name>[\w\.]+)',
        re.IGNORECASE
        )

    constraint_pattern = re.compile(
        r"ADD CONSTRAINT\s+(?P<name>\S+)\s+(?P<kind>(FOREIGN KEY|PRIMARY KEY|UNIQUE|CHECK))",
        re.IGNORECASE
        )


    # 出力先の存在確認、存在した場合はファイル削除
    for kind in ["up", "down"]:
        dest_dir = Path(dest_dir_path) / kind
        if dest_dir.exists():
            shutil.rmtree(str(dest_dir))

        dest_dir.mkdir(parents = True, exist_ok = True)


    # SQLコマンドを区切り文字で分割
    for index, command in enumerate(re.finditer(r"\-\-.+?;\n", sql_content, re.MULTILINE + re.DOTALL)):
        dest_up = f"{dest_dir_path}/up/{index}.sql"
        dest_down = f"{dest_dir_path}/down/{index}.sql"
        with open(dest_up, "w") as file_up, open(dest_down, "w") as file_down:

            # postgres -> oracle convert
            query = command.group(0)
            query = re.sub(r'ALTER TABLE ONLY', 'ALTER TABLE', query)
            query = re.sub(r'ON\sUPDATE.+?(;|ON)', r'\1', query)
            query = re.sub(r'ON\sDELETE.+?(;|ON)', r'\1', query)
            query = re.sub(r'text NOT NULL', 'CLOB', query)
            query = re.sub(r'VARCHAR', 'VARCHAR2', query)
            # query = re.sub(r'public\.', 'stat_meta_admin.', query)
            query = re.sub(r'public\.', '', query)
            query = re.sub(r';', '', query)
            query = re.sub(r'^--.*\n?', '', query, flags=re.MULTILINE)
            query = re.sub(r'^\n?', '', query, flags=re.MULTILINE)
            query = re.sub(r'\.', '_', query)
            query = re.sub(r'"(.+?)"', r'\1', query)

            query_match = query_pattern.search(query)
            const_match = constraint_pattern.search(query)

            if query_match:
                method = query_match.group("method")
                table_name = query_match.group("name")

                if const_match:
                    key_name = const_match.group("name")
                    key_kind = const_match.group("kind")
                    up_query = format_constraint_query(query, table_name, False, key_name, key_kind)

                    file_down.write(format_constraint_query(f"ALTER TABLE {table_name} DROP CONSTRAINT {key_name}", table_name, True, key_name, key_kind))

                else:
                    up_query = format_table_query(query, table_name, (method != "CREATE"))

                    if method == "CREATE":
                        file_down.write(format_table_query(f"DROP TABLE {table_name}", table_name, True))

            else:
                up_query = query


            file_up.write(up_query)




pg_dump_convert_ora_migrations("python/pg_dump.sql", "python/migrations")


un = os.environ["ORACLE_USER"]
pw = os.environ["ORACLE_PASSWORD"]
dsn = os.environ["ORACLE_DSN"]
wallet_pw = os.environ["ORACLE_WALLET_PASSWORD"]

encoded_data = os.environ["ORACLE_WALLET_ENCODED"]


with OCI(base64_wallet_text=encoded_data,
         user = un, password = pw, dataset_name = dsn, wallet_password = wallet_pw) as oci:

    oci.migration("./python/migrations", is_up = True)


# print("--------------")
# print(sql_commands[0])

# print("--------------")
# print(sql_commands[1])

# print("--------------")
# print(sql_commands[2])

# for command in sql_commands:
#      print("-------------")
#      print(command)

