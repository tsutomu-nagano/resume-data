
from oci import OCI

import pandas as pd

from pathlib import Path
from typing import List, Callable, Iterator, Iterable
import os
import re
import logging

periods = ["0000","0103","0101","0202","0303","0406","0404","0505","0606","0709","0707","0808","0909","1012","1010","1111","1212"]
timeptn = f'[12]\d{{3}}[01][012](?:{"|".join(periods)})'

# 都道府県名リスト
prefectures = [
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
    "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
    "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
    "岐阜県", "静岡県", "愛知県", "三重県",
    "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
    "鳥取県", "島根県", "岡山県", "広島県", "山口県",
    "徳島県", "香川県", "愛媛県", "高知県",
    "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
]

# 統計調査の属性情報の列名変換用マップ
statinfo_rename_map = {
    "概要": "description",
    "統計分野（大分類）": "domain",
    "統計分野（小分類）": "domain_sub",
    "調査単位": "survey_units",
    "選定の方法": "sampling_methods",
    "調査方法": "survey_methods",
    "使用する統計基準": "statistical_standard",
    "調査周期": "survey_cycle",
}
statinfo_code_to_name_ja = {v: k for k, v in statinfo_rename_map.items()}


# 正規表現を作成（| でOR検索）
pref_pattern = "|".join(prefectures)

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
        
        yield {"filename": Path(f).name, "data": df}


def get_term_and_month(row: pd.Series) -> pd.Series:

    m1 = row["month_range"][:2]
    m2 = row["month_range"][2:4]

    month = "00"
    term = "00"

    if m1 == m2 and m1 != "00":
        month = m1
        term = "00"
    else:
        month = "00"
        if row["half"] != "0":
            term = f'H{row["half"]}'
        else:
            if row["period_type"] == "CY":
                if m1 == "01":
                    term = "Q1"
                elif m1 == "04":
                    term = "Q2"
                elif m1 == "07":
                    term = "Q3"
                elif m1 == "10":
                    term = "Q4"

            if row["period_type"] == "FY":
                if m1 == "01":
                    term = "Q4"
                elif m1 == "04":
                    term = "Q1"
                elif m1 == "07":
                    term = "Q2"
                elif m1 == "10":
                    term = "Q3"


    return pd.Series({"term": term, "month": month})



def read_stat_info(src_dir: str, statcodes: List[str]) -> pd.DataFrame:

    def json2df(statcode: str, src_dir:str) -> pd.DataFrame:
        src = f"{src_dir}/{statcode}.json"
        df = pd.read_json(src).rename(columns=statinfo_rename_map)
        rep_cols = [v for v in statinfo_rename_map.values() if v in df.columns]
        return df[rep_cols].assign(statcode=statcode)

    statinfo = pd.concat([json2df(statcode, src_dir) for statcode in statcodes]).fillna("")

    statinfo_long = pd.melt(
        statinfo,
        id_vars="statcode",
        var_name="variable",
        value_name="value"
    ).pipe(lambda df: df[df["value"] != ""])

    return statinfo_long


src_dir = "./resource"

un = os.environ["ORACLE_USER"]
pw = os.environ["ORACLE_PASSWORD"]
dsn = os.environ["ORACLE_DSN"]
wallet_pw = os.environ["ORACLE_WALLET_PASSWORD"]
encoded_data = os.environ["ORACLE_WALLET_BASE64"]


with OCI(base64_wallet_text=encoded_data,
         user = un, password = pw, dataset_name = dsn, wallet_password = wallet_pw
         ) as oci:


    # oci.migration("./worker/python/migrations", is_up = False)
    # oci.migration("./worker/python/migrations", is_up = True)

    # テーブルの削除
    table_names: str = [
        "dimension_item",
        "table_dimension",
        "dimensionlist",
        "table_measure",
        "measurelist",
        "table_tag",
        "taglist",
        "table_region",
        "table_regiontype",
        "table_time",
        "regionlist",
        "tablelist"
        ]

    for table_name in table_names:
        oci.delete(table_name)

    # 府省／統計の一覧
    statlist_base = pd.read_csv(f"{src_dir}/statlist.csv", dtype =str)

    govlist = statlist_base[["govcode","govname"]].drop_duplicates()
    statlist = statlist_base[["statcode","statname","govcode"]].drop_duplicates()
    oci.sync_from_df(name = "govlist", df = govlist,key_cols = ["govcode"])
    oci.sync_from_df(name = "statlist", df = statlist,key_cols = ["statcode"])

    # 統計調査のメタ情報取得
    stat_info = read_stat_info(f"{src_dir}/stat_info", statlist["statcode"].tolist())
    attributes = stat_info[["statcode","variable"]] \
        .drop_duplicates() \
        .rename(columns={"variable":"code"}) \
        .assign(name_ja=lambda d: d["code"].map(statinfo_code_to_name_ja))

    # 統計調査のメタ情報マスター登録
    oci.sync_from_df(
        name = "stat_attribute", 
        df = attributes[["code","name_ja"]].drop_duplicates(),
        key_cols=["code","name_ja"]
        )

    attribute = oci.select("stat_attribute")

    attribute_values = stat_info.merge(
        attribute,
        left_on=["variable"],
        right_on=["CODE"],
        how="left"
        ) \
        .pipe(lambda df: df[["statcode","ID","value"]]) \
        .rename(columns={"ID":"attribute_id"}) \
        .explode("value")


    oci.sync_from_df(
        name = "stat_attribute_values", 
        df = attribute_values,
        key_cols=["statcode","attribute_id","value"]
        )




    # 統計データの一覧
    table_tags = []
    for item in get_datas(files = Path(f"{src_dir}/tables").glob("*.*")):
        
        table = item["data"]

        tablelist = table.pipe(select, names = ["statcode", "STATDISPID","^TITLE$","CYCLE","SURVEY_DATE"]) \
                        .fillna("-") \
                        .drop_duplicates() \
                        .merge(statlist[["statcode"]], on="statcode", how="inner")

        if len(tablelist) > 0:
            oci.insert_from_df(name = "tablelist", df = tablelist, source = item["filename"])

            table_tags.append(table.pipe(select, names = ["STATDISPID", "^STATISTICS_NAME_SPEC."]) \
                            .melt(id_vars = "STATDISPID", value_name = "TAG_NAME") \
                            .pipe(select, names = ["STATDISPID", "TAG_NAME"]) \
                            .fillna("") \
                            .pipe(lambda df: df[df["TAG_NAME"] != ""]) \
                            .drop_duplicates()                            
        )



    oci.insert_from_df(name = "taglist", df = pd.concat(table_tags)[["TAG_NAME"]].drop_duplicates())
    [oci.insert_from_df(name = "table_tag", df = table_tag) for table_tag in table_tags]



    dimensions = []    
    measures = []
    regions = []
    times = []
    for item in get_datas(files = Path(f"{src_dir}/meta").glob("*.*")):
       
        meta = item["data"].merge(statlist[["statcode"]], on="statcode", how="inner")


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
                        

        # regions.append(
        #         meta.pipe(lambda df: df[df["class_type"].str.startswith("area")]) 
        #             .pipe(select, names = ["STATDISPID", "^name$"]) 
        #             .dropna(subset=["name"]) 
        #             .drop_duplicates()
        #             .pipe(lambda df: df[df["name"].str.contains(pref_pattern)])
        #             # 都道府県名をリストとして抽出
        #             .assign(prefecture_list=lambda df: df["name"].str.findall(pref_pattern))
        #             # 1行に1都道府県になるよう展開
        #             .explode("prefecture_list")
        #             .drop(columns=["name"])
        #             # prefecture_list を name にリネーム
        #             .rename(columns={"prefecture_list": "name"})
        #             .drop_duplicates()
        # )


        time_meta = meta.pipe(lambda df: df[df["class_type"].str.startswith("time")]) \
                        .pipe(select, names = ["STATDISPID", "code"]) \
                        .pipe(lambda df: df[df["code"].str.contains(timeptn, regex=True, na=False)]) \
                        .drop_duplicates() \
                        .assign(
                            year=lambda df: df["code"].str[:4],
                            period_type=lambda df: df["code"].str[4:5].map({"0": "CY", "1": "FY"}),
                            half=lambda df: df["code"].str[5:6],
                            month_range=lambda df: df["code"].str[6:9],
                        )       

        tmp = time_meta[["period_type", "half", "month_range"]].apply(get_term_and_month, axis=1)

        if (len(tmp)) >= 1:
            time_meta = time_meta.join(tmp)
            times.append(time_meta)

    measures_base = pd.concat(measures)


    oci.insert_from_df(name = "measurelist", df = measures_base[["name"]].drop_duplicates())
    oci.insert_from_df(name = "table_measure", df = measures_base[["STATDISPID","name"]].drop_duplicates())


    dimensions_base = pd.concat(dimensions)

    oci.insert_from_df(name = "dimensionlist", df = dimensions_base[["class_name"]].drop_duplicates())
    oci.insert_from_df(name = "table_dimension", df = dimensions_base[["STATDISPID","class_name"]].drop_duplicates())
    oci.insert_from_df(name = "dimension_item", df = dimensions_base[["class_name","name"]].fillna("NA").drop_duplicates(), batch_size = 100000)

    registered_table_ids = oci.select("tablelist")[["STATDISPID"]].drop_duplicates()
    regions_base = (
                    pd.read_parquet(f"{src_dir}/regionlist.parquet")
                    .merge(registered_table_ids, on="STATDISPID", how="inner")
    )
    oci.insert_from_df(name = "regionlist", df = regions_base[["name"]].drop_duplicates())
    oci.insert_from_df(name = "table_region", df = regions_base[["STATDISPID","name"]].drop_duplicates(), batch_size = 100000)

    regiontype = (
                    pd.read_parquet(f"{src_dir}/regiontype.parquet")
                    .merge(registered_table_ids, on="STATDISPID", how="inner")
    )
    oci.insert_from_df(name = "table_regiontype", df = regiontype[["STATDISPID","regiontype"]].drop_duplicates(), batch_size = 100000)

    times_base = pd.concat(times)
                    .merge(registered_table_ids, on="STATDISPID", how="inner")
    oci.insert_from_df(name = "table_time", df = times_base[["STATDISPID","year","period_type","term", "month"]].drop_duplicates())
    oci.execute_proc("UPDATE_TABLELIST_YEARS")
    

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






