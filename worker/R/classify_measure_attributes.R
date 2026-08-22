library(dplyr)
library(readr)
library(arrow)
library(tibble)
library(tidyr)
library(stringr)
library(glue)

# ============================================================
# 集計事項名から統計量属性を付与する
# ============================================================



# ------------------------------------------------------------
# 2. 属性判定ルール
#
# attribute : 属性の種類
# value     : 付与する属性値
# pattern   : NAMEに対して判定する正規表現
#
# 1つのNAMEに複数ルールが一致した場合は、
# 複数の属性を保持する。
# ------------------------------------------------------------

attribute_rules <- tibble::tribble(
  ~attribute,         ~value,                   ~pattern,

  # ----------------------------------------------------------
  # 統計量
  # ----------------------------------------------------------

  "statistic",        "mean",                   "平均値|平均",
  "statistic",        "median",                 "中央値|メジアン",
  "statistic",        "max",                    "最大値|最高値",
  "statistic",        "min",                    "最小値|最低値",

  "statistic",        "ratio",                  "割合|構成比|比率",

  "statistic",        "rate",                   paste0(
    "増加率|減少率|伸び率|稼働率|利用率|",
    "就業率|失業率|出生率|死亡率|離職率|",
    "入職率|有病率|受診率|回答率|回収率"
  ),

  "statistic",        "index",                  "指数",

  "statistic",        "change",                 paste0(
    "前年差|前年度差|増減数|増減額"
  ),


  # ----------------------------------------------------------
  # 基準・単位
  # ----------------------------------------------------------

  "basis",            "per_person",             "1人当たり|一人当たり",

  "basis",            "per_household",          "1世帯当たり|一世帯当たり",

  "basis",            "per_establishment",      paste0(
    "1事業所当たり|一事業所当たり"
  ),

  "basis",            "per_company",            "1企業当たり|一企業当たり",


  # ----------------------------------------------------------
  # 比較基準
  # ----------------------------------------------------------

  "comparison",       "year_over_year",         "前年比|対前年比",

  "comparison",       "fiscal_year_over_year",  paste0(
    "前年度比|対前年度比"
  ),

  "comparison",       "previous_period",         paste0(
    "前月比|前期比|前回比"
  ),


  # ----------------------------------------------------------
  # 推計等
  # ----------------------------------------------------------

  "method",           "estimated",              "推計|推定"
)


# ------------------------------------------------------------
# 3. CSV読み込み
# ------------------------------------------------------------

args <- commandArgs(trailingOnly = T)

root_dir <- args[1]
# root_dir <- "./resource"
dest <- glue("{root_dir}/measure_attributes.csv")


measures <- list.files(glue("{root_dir}/meta"), full.names = TRUE) %>%
purrr::map_dfr(function(src){
  
    df <- arrow::open_dataset(src) %>%
          dplyr::filter(class_type == "tab") %>%
          dplyr::select(name) %>%
          dplyr::distinct() %>%
          dplyr::collect()

    return(df)

})




# ------------------------------------------------------------
# 5. nameごとに属性判定
#
# ------------------------------------------------------------

measures %>%
pull(name) %>%
purrr::map_dfr(function(name_){

  attribute_rules %>%
  mutate(name = name_) %>%
  mutate(isMatch = str_detect(name, pattern)) %>%
  filter(isMatch) %>%
  return

}) %>%
distinct(name, attribute, value) %>%
write_excel_csv(dest, quote = "all")

