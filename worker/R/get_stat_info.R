
library(httr)
library(rvest)
library(glue)
library(dplyr)
library(stringr)
library(readr)
library(tidyr)


get_last_page <- function(){

    url <- glue("https://www.e-stat.go.jp/stat-search?page=1")

    res <- RETRY(
            "GET",
            url,
            times = 5,          # 最大リトライ回数
            pause_base = 1,     # 待機秒（指数バックオフのベース）
            pause_cap = 10,      # 最大待機秒
　　        config = httr::use_http_1_1()
            )

    pageText <- read_html(res) %>%
                html_element("body") %>%
                html_element("div.stat-paginate-index.rig") %>%
                html_text()

    return(str_match(pageText, "([0-9]+)/([0-9]+)ページ")[1,3])


}


create_stat_info <- function(dest_dir){

    # 統計一覧のページ数の最大を取得する
    last_page <- as.integer(get_last_page())

    print(last_page)
    1:last_page %>% 
    purrr::map(function(page){

        print(glue("{page} PAGE"))
        url <- glue("https://www.e-stat.go.jp/stat-search?page={page}")
        res <- RETRY(
                "GET",
                url,
                times = 5,          # 最大リトライ回数
                pause_base = 1,     # 待機秒（指数バックオフのベース）
                pause_cap = 10,      # 最大待機秒
    　　        config = httr::use_http_1_1()
                )

        doc <- read_html(res) %>% html_element("body")

        doc %>%
        html_elements('span.stat-title') %>%
        html_text() %>%
        str_subset("[0-9]{8}") %>%
        purrr::map(function(statcode){

            print(statcode)
            dest <- glue("{dest_dir}/{statcode}.json")

            # 詳細ページ
            url <- glue("https://www.e-stat.go.jp/statistics/{statcode}")
            print(url)

            res <- RETRY(
                "GET",
                url,
                times = 5,          # 最大リトライ回数
                pause_base = 1,     # 待機秒（指数バックオフのベース）
                pause_cap = 10,      # 最大待機秒
    　　        config = httr::use_http_1_1()
            )

            info <- read_html(res) %>%
            html_element("body") %>%
            html_element("table.stat-resource_sheet.stat-resource_table") %>%
            html_table


            # 調査計画
            url <- glue("https://www.e-stat.go.jp/surveyplan/p{statcode}001")
            print(url)

            res <- RETRY(
                "GET",
                url,
                times = 5,          # 最大リトライ回数
                pause_base = 1,     # 待機秒（指数バックオフのベース）
                pause_cap = 10,      # 最大待機秒
    　　        config = httr::use_http_1_1()
            )

            if (httr::status_code(res) == 200) {

                doc <- httr::content(res, as = "parsed")

                plan <- doc %>%
                html_element("body") %>%
                html_elements("table.stat-resource_sheet.stat-resource_table") %>%
                html_table %>%
                bind_rows()


                info <- bind_rows(info, plan) %>% distinct()

            }


            info %>%
            setNames(c("name", "value")) %>%
            pivot_wider() %>%
            mutate(across(everything(),
                ~ ifelse(
                    is.na(.) | . == "",
                    "",
                    strsplit(., "\n", fixed = TRUE)
                ))) %>%
            jsonlite::write_json(
                path = dest,
                pretty = TRUE,
                auto_unbox = TRUE
            )

        })

    })

}


args <- commandArgs(trailingOnly = T)

root_dir <- args[1]
# root_dir <- "./resource"

dest_dir <- glue("{root_dir}/stat_info")
if (dir.exists(dest_dir)){
    unlink(dest_dir, recursive = TRUE, force = TRUE)
}
dir.create(dest_dir)

create_stat_info(dest_dir)
