

library(httr)
library(readr)
library(dplyr)
library(arrow)
library(glue)
library(tidyr)
library(stringr)
library(digest)


get_sacs <- function(limit = 10000){

    endpoint <- "http://data.e-stat.go.jp/lod/sparql/alldata/query"

    # FILTER(CONTAINS(?city, "前"))
    # FILTER(CONTAINS(?ken, "岩手"))


    query_core <- "
    where {

        ?s rdf:type sacs:StandardAreaCode;
           rdfs:label ?city ;
           sacs:prefectureLabel ?ken;
           dcterms:isPartOf ?p.

        OPTIONAL {
            ?s sacs:districtOfSubPrefecture ?sub .
            FILTER(lang(?sub) = 'ja')
          }

        ?p rdfs:label ?pname .

        FILTER(lang(?city) = 'ja')
        FILTER(lang(?pname) = 'ja')

    }
    "

    query_count <- "
    PREFIX sacs: <http://data.e-stat.go.jp/lod/terms/sacs#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

    select (COUNT(*) AS ?count)
    %s
    "

    query_data <- "
    PREFIX sacs: <http://data.e-stat.go.jp/lod/terms/sacs#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

    select ?ken ?sub ?pname ?city
    %s
    ORDER BY ?s
    LIMIT %d
    OFFSET %d
    "



    res <- POST(
        url = endpoint,
        body = list(
            query = sprintf(query_count, query_core)
        ),
        encode = "form",
        add_headers(
            "Accept" = "text/csv"
        )
    )

    count <- read_csv(content(res, "text"))$COUNT

    div <- count %/% limit
    mod <- count %% limit
    if (mod != 0){
        div <- div + 1
    }

    seq(from = 0, by = limit, length.out = div) %>%
    purrr::map(function(offset){

        print(offset)

        res <- POST(
            url = endpoint,
            body = list(
                query = sprintf(query_data, query_core, limit, offset)
            ),
            encode = "form",
            add_headers(
                "Accept" = "text/csv"
            )
        )

        read_csv(content(res, "text")) %>% return 

    }) %>% bind_rows %>%
    distinct %>%
    return
}



toArray <- function(obj){

    if (!is.null(names(obj))){
        return(list(obj))
    } else {
        return(obj)
    }

}


getMetaList <- function(appid, statsdataid){

    url <- glue("http://api.e-stat.go.jp/rest/3.0/app/json/getMetaInfo?appId={appid}&statsDataId={statsdataid}&explanationGetFlg=Y")
    res <- GET(url)
    res.json <- content(res)


    statcode_ <- res.json$GET_META_INFO$METADATA_INF$TABLE_INF$STAT_NAME$`@code`


    class_objs <- res.json$GET_META_INFO$METADATA_INF$CLASS_INF$CLASS_OBJ %>% toArray

    base <- class_objs %>%
    purrr::map(function(class_obj){


        class.id <- class_obj$`@id`
        class.name <- class_obj$`@name`

        classes <- class_obj$CLASS %>% toArray

        df <- classes %>% tibble

        if (nrow(df) >= 1){
            df <- df %>%
                unnest_wider(".") %>%
                rename_with(~ str_replace(.x, "@",""), everything()) %>%
                mutate(across(everything(), ~replace_na(.x, ""))) %>%
                # mutate(class_type = str_replace(class.id, "(.+?)[0-9]+$", "\\1")) %>%
                mutate(class_name = class.name, class_type = class.id)
        }

        return(df)



    }) %>% bind_rows %>%
    # select(-one_of("level", "parentCode")) %>%
    mutate(STATDISPID = statsdataid, statcode = statcode_) %>%
    return

}

getStatsNameList <- function(appid){

    base <- ""

    url <- glue("http://api.e-stat.go.jp/rest/3.0/app/json/getStatsList?appId={appid}&statsNameList=Y")
    res <- GET(url)
    res.json <- content(res)

    datalist_inf <- res.json$GET_STATS_LIST$DATALIST_INF
    result_inf <- datalist_inf$RESULT_INF
    table_infs <- datalist_inf$LIST_INF %>% toArray

    table_infs %>%
    tibble %>%
    unnest_wider(".") %>%
    unnest_wider(c("STAT_NAME","GOV_ORG"), names_sep = ".") %>%
    rename(statcode = `STAT_NAME.@code`, statname = `STAT_NAME.$`, govcode = `GOV_ORG.@code`, govname = `GOV_ORG.$`) %>%
    select(-`@id`) %>%
    return


}





getStatsList <- function(appid, statcode = "", updated_date = ""){

    base <- ""
    next_key <- "1"
    while (!is.null(next_key)){

        params = list(
            appId = appid,
            startPosition = next_key
        )

        if (statcode != ""){
            params["statsCode"] <- statcode
        }

        if (updated_date != ""){
            params["updatedDate"] <- updated_date
        }


        url <- "http://api.e-stat.go.jp/rest/3.0/app/json/getStatsList"
        res <- GET(url, query = params)
        res.json <- content(res)

        datalist_inf <- res.json$GET_STATS_LIST$DATALIST_INF
        result_inf <- datalist_inf$RESULT_INF
        table_infs <- datalist_inf$TABLE_INF %>% toArray

        if (any(names(result_inf) == "NEXT_KEY")){
            next_key <- result_inf$NEXT_KEY
        } else {
            next_key <- NULL        
        }



        base_ <- table_infs %>%
                tibble %>%
                unnest_wider(".") %>%
                rename(STATDISPID = `@id`) %>%
                select(STATDISPID, STAT_NAME, TITLE, STATISTICS_NAME_SPEC, CYCLE, SURVEY_DATE,UPDATED_DATE) %>%
                unnest_wider(c("STAT_NAME", "STATISTICS_NAME_SPEC","TITLE"), names_sep = ".") %>%
                unite(col = TITLE, matches("TITLE\\.[1$]"), sep = "", remove =TRUE, na.rm = TRUE) %>%
                rename(statcode = `STAT_NAME.@code`, statname = `STAT_NAME.$`) %>%
                select(-statname) %>%
                distinct()


        if (base == ""){
            base <- base_
        } else {
            base <- bind_rows(base, base_)
        }

    }


    return(base %>% distinct())

}


meta_output <- function(statcode, src, name, type, selection){

    dest.dir <- glue("{root_dir}/{name}")
    if (!dir.exists(dest.dir)){
        dir.create(dest.dir)
    }
    dest <-  glue("{dest.dir}/{statcode}_{name}.csv")
    list.files(src, full.names = TRUE) %>%
    purrr::map(function(path){
        read_parquet(path) %>%
        filter(class.type == type) %>%
        select(one_of(selection)) %>%
        distinct %>%
        return
    }) %>% bind_rows %>%
    distinct %>%
    write_excel_csv(dest, quote = "all")

}

args <- commandArgs(trailingOnly = T)

appid <- Sys.getenv("APPID")
root_dir <- args[1]
root_dir <- "./resource"

# 統計調査の一覧
statlist <- getStatsNameList(appid)
statlist %>%
write_excel_csv(glue("{root_dir}/statlist.csv", qutoe = "all"))

# 統計データの一覧
## 1. temp へ統計データの一覧作成
print(glue("1. table create at temp"))
temp_dir <- glue("{root_dir}/temp/tables")
if (!dir.exists(temp_dir)){
    dir.create(temp_dir, recursive = TRUE)
}

statlist %>%
pull(statcode) %>%
purrr::map(function(statcode){

    dest <- glue("{temp_dir}/{statcode}_tables.csv")
    getStatsList(appid, statcode) %>%
    write_excel_csv(dest, quote = "all")

})

## 2. 保存済のデータと比較
print(glue("2. compare to archive"))
temp_tables <- list.files(temp_dir, full.names = TRUE) %>%
purrr::map(function(path){
    read_csv(path, col_type = cols(.default = "c")) %>%
    select(statcode, STATDISPID, UPDATED_DATE) %>%
    rename(DATE.new = UPDATED_DATE, statcode.new = statcode) %>%
    distinct
}) %>% bind_rows


latest_tables_dir <- glue("{root_dir}/tables")
latest_tables <- list.files(latest_tables_dir, full.names = TRUE) %>%
purrr::map(function(path){
    read_csv(path, col_type = cols(.default = "c")) %>%
    select(statcode, STATDISPID, UPDATED_DATE) %>%
    rename(DATE.latest = UPDATED_DATE, statcode.latest = statcode) %>%
    distinct
}) %>% bind_rows

latest_meta_dir <- glue("{root_dir}/meta")
latest_meta <- list.files(latest_meta_dir, full.names = TRUE) %>%
purrr::map(function(path){
    read_parquet(path) %>%
    distinct(STATDISPID) %>%
    mutate(flg.meta = "EXIST")
}) %>% bind_rows


match <- temp_tables %>%
            full_join(latest_tables, by = "STATDISPID") %>%
            left_join(latest_meta, by = "STATDISPID") %>%
            mutate(across(c(starts_with("DATE"),"flg.meta"), ~replace_na(.x, ""))) %>%
            mutate(flg = if_else(DATE.new == "", "DELETE","")) %>%
            mutate(flg = if_else(DATE.latest == "", "NEW",flg)) %>%
            mutate(flg = if_else(flg == "" & DATE.latest != DATE.new, "UPDATE",flg)) %>%
            mutate(flg = if_else(flg == "" & flg.meta == "", "NEW",flg)) %>%
            mutate(statcode = coalesce(statcode.new, statcode.latest)) %>%
            select(-starts_with("statcode."))


## 3. 削除対象のデータを削除
delcnt <- match %>% filter(flg == "DELETE") %>% nrow
print(glue("3. delete meta : target = {delcnt}"))

dummy <- match %>% filter(flg == "DELETE") %>%
select(statcode, STATDISPID, flg) %>%
nest(statdispids = -statcode) %>%
mutate(del = purrr::pmap(
    list(statcode, statdispids),
    function(statcode, statdispids){

        src.latest <- glue("{root_dir}/meta/{statcode}.parquet")
        latest <- read_parquet(src.latest)

        latest %>%
        left_join(statdispids, by = "STATDISPID", multiple = "all") %>%
        filter(is.na(flg)) %>%
        select(-flg) %>%
        write_parquet(src.latest)

    }
))

## 4. 新規 or 更新対象はメタデータ取得
newcnt <- match %>% filter(flg %in% c("NEW", "UPDATE")) %>% nrow
print(glue("4. get meta : target = {newcnt}"))

dummy <- match %>% filter(flg %in% c("NEW", "UPDATE")) %>%
select(statcode, STATDISPID, flg) %>%
nest(statdispids = -statcode) %>%
mutate(new = purrr::pmap(
    list(statcode, statdispids),
    function(statcode, statdispids){

        temp_dir <- glue("{root_dir}/temp/meta/{statcode}")
        if (dir.exists(temp_dir)){unlink(temp_dir, recursive = TRUE, force = TRUE)}
        dir.create(temp_dir, recursive = TRUE)

        new <- statdispids %>% pull(STATDISPID) %>%
        purrr::map(function(statdispid){
            # dest <- glue("{temp_dir}/{statdispid}.parquet")
            # getMetaList(appid, statdispid) %>% write_parquet(dest)
            getMetaList(appid, statdispid)

        }) %>% bind_rows


        latest.src <- glue("{root_dir}/meta/{statcode}.parquet")

        if (file.exists(latest.src)){
            read_parquet(latest.src) %>%
            bind_rows(new) %>%
            write_parquet(latest.src)
        } else {
            new %>%
            write_parquet(latest.src)
        }

 

    }
))


## 5. 「1.」を保存データに置き換え
print("5. replace archive")

temp_dir <- glue("{root_dir}/temp/tables")
latest_tables_dir <- glue("{root_dir}/tables")
unlink(latest_tables_dir, recursive = TRUE, force = TRUE)
dir.create(latest_tables_dir)
list.files(temp_dir, full.names = TRUE) %>%
purrr::map(function(src){

    dest <- glue("{latest_tables_dir}/{basename(src)}")
    file.copy(src, dest)

})


# 6. 地域用のデータを作成
print("6. create region data")
sacs <- get_sacs() %>%
        filter(KEN != CITY) %>%
        filter(str_detect(CITY, "[市町村区]$")) %>%
        mutate(length = str_length(CITY))

lmin <- sacs %>% pull(length) %>% min
lmax <- sacs %>% pull(length) %>% max


regions <- list.files(glue("{root_dir}/meta"), full.names = TRUE) %>%
            purrr::map(function(src){
                read_parquet(src) %>%
                filter(class_type == "area") %>%
                filter(!is.na(name)) %>% 
                distinct(STATDISPID, name) %>%
                return
            }) %>% bind_rows() %>%
            mutate(length = str_length(name), cityname = "") %>%
            purrr::reduce(
                .x = lmax:lmin,
                .init = .,
                .f = function(data, i){

                    sacs_ <- sacs %>% filter(length == i) %>% mutate(name = CITY) %>% distinct(name, CITY)

                    print(sacs_)

                    ptn <- glue(".{{{i - 1}}}[市区町村]")

                    matched <- data %>%
                    filter(length >= i) %>%
                    filter(cityname == "") %>%
                    mutate(t = str_extract(name, ptn)) %>%
                    filter(!is.na(t)) %>%
                    distinct(name, t) %>%
                    inner_join(sacs_, by = c("t" = "name"))


                    if (nrow(matched) >= 1){

                        data <- data %>%
                        left_join(matched, by = c("name"), multiple = "all") %>%
                        mutate(cityname = coalesce(CITY, cityname)) %>%
                        select(-t, -CITY)
                    }

                    return(data)

                }
            ) %>%
            mutate(kenname = replace_na(str_extract(name, ken_ptn), ""))

bind_rows(
    regions %>% filter(cityname != "") %>% select(STATDISPID, cityname) %>% rename(name = cityname),
    regions %>% filter(kenname != "") %>% select(STATDISPID, kenname) %>% rename(name = kenname)
) %>%
write_excel_csv(glue("{root_dir}/regionlist.csv"), quote = "all")


# 事項名とテーブルのIDの中間テーブル用データ作成
# meta_output(statcode, base.dir, "table_dimension", "cat", c("STATDISPID", "class.name"))
# meta_output(statcode, base.dir, "dimension_item", "cat", c("class.name", "name"))

# # 集計事項とテーブルのIDの中間テーブル用データ作成
# meta_output(statcode, base.dir, "table_measure", "tab", c("STATDISPID", "name"))

# # TODO 時間軸とテーブルのIDの中間テーブル用データ作成
# # TODO 地域とテーブルのIDの中間テーブル用データ作成

