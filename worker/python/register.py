
from oci import OCI

import pandas as pd

from pathlib import Path
from typing import List, Callable, Iterator, Iterable
import os
import re
import logging

PandasPipeFunc = Callable[[pd.DataFrame], pd.DataFrame]

# ロガーを作成
logger = logging.getLogger('my_logger')
logger.setLevel(logging.DEBUG)  # ログレベルを設定（DEBUG, INFO, WARNING, ERROR, CRITICAL）

# コンソール出力のハンドラを作成
console_handler = logging.StreamHandler()

# フォーマッタを作成
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)

# ハンドラをロガーに追加
logger.addHandler(console_handler)


def select(df: pd.DataFrame, names: List[str]) -> pd.DataFrame:
    # 引数 'name' で始まる列を選択する
    
    ptn = f"{'|'.join(names)}"
    selected_df = df.loc[:, df.columns.str.contains(ptn)]
    return selected_df

def columns_normalize(df: pd.DataFrame) -> pd.DataFrame:
    return(df.rename(columns=lambda s: s.replace(".","_")))
   


def get_datas(files: Iterable[Path], formats: List[PandasPipeFunc] = None) -> Iterator[pd.DataFrame]:
    for f in files:
        suffix = f.suffix.lower()
        if suffix == ".csv":
            df = pd.read_csv(str(f), dtype =str)
        elif suffix == ".parquet":
            df = pd.read_parquet(str(f))

        if not formats is None:
            for format in formats:
                df = df.pipe(format)         
        
        yield df


src_dir = "./resource"

un = os.environ["ORACLE_USER"]
pw = os.environ["ORACLE_PASSWORD"]
dsn = os.environ["ORACLE_DSN"]
wallet_pw = os.environ["ORACLE_WALLET_PASSWORD"]

encoded_data = os.environ["ORACLE_WALLET_ENCODED"]


with OCI(base64_wallet_text=encoded_data,
         user = un, password = pw, dataset_name = dsn, wallet_password = wallet_pw) as oci:

    oci.migration("./python/migrations", is_up = False)
    oci.migration("./python/migrations", is_up = True)


    # 府省／統計の一覧
    statlist_base = pd.read_csv(f"{src_dir}/statlist.csv", dtype =str)

    govlist = statlist_base[["govcode","govname"]].drop_duplicates()
    statlist = statlist_base[["statcode","statname","govcode"]].drop_duplicates()
    oci.insert_from_df(name = "govlist", df = govlist)
    oci.insert_from_df(name = "statlist", df = statlist)

    # 統計データの一覧
    tables = get_datas(
                files = Path(f"{src_dir}/tables").glob("*.*")
                )
                # formats = [
                #     lambda df: select(df, names = ["statcode", "STATDISPID","^TITLE$","CYCLE","SURVEY_DATE"]),
                #     lambda df: df.drop_duplicates().fillna("-")
                # ])

    table_tags = []
    for table in tables:
        
        tablelist = table.pipe(select, names = ["statcode", "STATDISPID","^TITLE$","CYCLE","SURVEY_DATE"]) \
                        .fillna("-") \
                        .drop_duplicates()

        oci.insert_from_df(name = "tablelist", df = tablelist)

        table_tags.append(table.pipe(select, names = ["STATDISPID", "^STATISTICS_NAME_SPEC."]) \
                        .melt(id_vars = "STATDISPID", value_name = "TAG_NAME") \
                        .pipe(select, names = ["STATDISPID", "TAG_NAME"]) \
                        .fillna("") \
                        .pipe(lambda df: df[df["TAG_NAME"] != ""]) \
                        .drop_duplicates()                            
        )


    oci.insert_from_df(name = "taglist", df = pd.concat(table_tags)[["TAG_NAME"]].drop_duplicates())
    [oci.insert_from_df(name = "table_tag", df = table_tag) for table_tag in table_tags]


    metas = get_datas(
                files = Path(f"{src_dir}/meta").glob("*.*")
                )


    dimensions = []    
    measures = []
    regions = []
    for meta in metas:

       
        measures.append(
            meta.pipe(lambda df: df[df["class_type"] == "tab"]) \
                                    .pipe(select, names = ["STATDISPID", "^name$"]) \
                                    .drop_duplicates()
        )


        dimensions.append(
                meta.pipe(lambda df: df[df["class_type"].str.startswith("cat")]) \
                    .pipe(select, names = ["STATDISPID", "class_name", "^name$"]) \
                    .drop_duplicates()
        )
                        

        regions.append(
                meta.pipe(lambda df: df[df["class_type"].str.startswith("area")]) \
                    .pipe(select, names = ["STATDISPID", "class_name", "^name$"]) \
                    .drop_duplicates()
        )


    measures_base = pd.concat(measures)

    oci.insert_from_df(name = "measurelist", df = measures_base[["name"]].drop_duplicates())
    oci.insert_from_df(name = "table_measure", df = measures_base[["STATDISPID","name"]].drop_duplicates())


    dimensions_base = pd.concat(dimensions)

    oci.insert_from_df(name = "dimensionlist", df = dimensions_base[["class_name"]].drop_duplicates())
    oci.insert_from_df(name = "table_dimension", df = dimensions_base[["STATDISPID","class_name"]].drop_duplicates())
    oci.insert_from_df(name = "dimension_item", df = dimensions_base[["class_name","name"]].fillna("NA").drop_duplicates(), batch_size = 100000)

    regions_base = pd.concat(regions)

    oci.insert_from_df(name = "regionlist", df = regions_base[["class_name"]].drop_duplicates())
    oci.insert_from_df(name = "table_region", df = regions_base[["STATDISPID","class_name"]].drop_duplicates())
    oci.insert_from_df(name = "region_item", df = regions_base[["class_name","name"]].fillna("NA").drop_duplicates(), batch_size = 100000)


## 7. dimensionlist
# dimension.base <- list.files(glue("{root_dir}/table_dimension"), full.names = TRUE) %>%
# purrr::map(function(path){
#     read_csv(path, col_types = cols(.default = "c")) %>%
#     mutate(across(everything(), ~replace_na(.x, ""))) %>%
#     rename_lower %>%
#     return
# }) %>% bind_rows() %>%
# distinct()

# dimension.base %>%
# distinct(class.name) %>%
# dbWriteTable(con, "dimensionlist", ., append = TRUE, row.names = FALSE)

# ## 8. table_dimension
# dimension.base %>%
# dbWriteTable(con, "table_dimension", ., append = TRUE, row.names = FALSE)

# ## 9. dimension_items
# list.files(glue("{root_dir}/dimension_item"), full.names = TRUE) %>%
# purrr::map(function(path){
#     read_csv(path, col_types = cols(.default = "c")) %>%
#     mutate(across(everything(), ~replace_na(.x, ""))) %>%
#     rename_lower %>%
#     return
# }) %>% bind_rows() %>%
# distinct() %>%
# dbWriteTable(con, "dimension_item", ., append = TRUE, row.names = FALSE)






