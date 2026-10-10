library(httr2)
library(rvest)
library(glue)
library(dplyr)
library(stringr)
library(readr)
library(tidyr)

# =============================================
# e-Stat 統計情報取得
# rocker/tidyverse:4.2.2 対応
# =============================================

# ---------------------------------------------
# 設定
# ---------------------------------------------

BASE_URL <- "https://www.e-stat.go.jp"

MAX_TRIES <- 5L
REQUEST_TIMEOUT <- 60L
REQUEST_INTERVAL <- 0.5

RETRY_STATUS <- c(
  408L, 429L, 500L, 502L, 503L, 504L
)


# ---------------------------------------------
# ログ出力
# ---------------------------------------------

log_message <- function(...) {

  message(sprintf(
    "[%s] %s",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    paste0(...)
  ))

}


# ---------------------------------------------
# HTTP取得（リトライ付き）
# ---------------------------------------------

get_response <- function(
    url,
    max_tries = MAX_TRIES,
    allow_404 = FALSE) {

  for (i in seq_len(max_tries)) {

    result <- tryCatch({

      res <- httr2::request(url) |>
        httr2::req_method("GET") |>
        httr2::req_options(
          http_version = 2L
        ) |>
        httr2::req_timeout(
          REQUEST_TIMEOUT
        ) |>
        httr2::req_error(
          is_error = function(resp) FALSE
        ) |>
        httr2::req_perform()

      res

    }, error = function(e) {
      e
    })

    # 通信自体が失敗した場合
    if (inherits(result, "error")) {

      error_msg <- conditionMessage(result)

      retryable <- TRUE

    } else {

      status <- httr2::resp_status(result)

      # 正常終了
      if (status >= 200 && status < 300) {
        return(result)
      }

      # 調査計画ページなどで404を許容
      if (status == 404 && allow_404) {
        return(NULL)
      }

      error_msg <- paste0("HTTP ", status)

      retryable <- status %in% RETRY_STATUS

    }

    log_message(
      "ERROR [", i, "/", max_tries, "] ",
      url,
      " : ",
      error_msg
    )

    # リトライ対象外、または試行回数の上限
    if (!retryable || i >= max_tries) {
      stop(
        paste0(
          "取得失敗: ",
          url,
          " / ",
          error_msg
        ),
        call. = FALSE
      )
    }

    # 指数バックオフ
    wait_sec <- min(2^(i - 1), 30) +
      runif(1, 0, 0.5)

    log_message(
      "RETRY after ",
      round(wait_sec, 1),
      " seconds"
    )

    Sys.sleep(wait_sec)
  }
}


# ---------------------------------------------
# エラーログ保存
# ---------------------------------------------

save_error <- function(
    type,
    id,
    url,
    error,
    dest_dir) {

  path <- file.path(dest_dir, "failed.csv")

  record <- data.frame(
    datetime = format(
      Sys.time(),
      "%Y-%m-%d %H:%M:%S"
    ),
    type = as.character(type),
    id = as.character(id),
    url = as.character(url),
    error = as.character(error),
    stringsAsFactors = FALSE
  )

  write.table(
    record,
    file = path,
    sep = ",",
    row.names = FALSE,
    col.names = !file.exists(path),
    append = file.exists(path),
    quote = TRUE,
    fileEncoding = "UTF-8"
  )

  log_message(
    "FAILED [", type, "] ",
    id,
    " : ",
    error
  )
}


# ---------------------------------------------
# JSON取得済み判定
# ---------------------------------------------

is_completed <- function(path) {

  if (!file.exists(path)) {
    return(FALSE)
  }

  if (file.size(path) == 0) {
    return(FALSE)
  }

  # JSONとして読み込み可能か確認
  valid <- tryCatch({

    jsonlite::validate(
      paste(
        readLines(
          path,
          warn = FALSE,
          encoding = "UTF-8"
        ),
        collapse = "\n"
      )
    )

  }, error = function(e) FALSE)

  isTRUE(valid)
}


# ---------------------------------------------
# 最大ページ数取得
# ---------------------------------------------

get_last_page <- function() {

  url <- paste0(
    BASE_URL,
    "/stat-search?page=1"
  )

  res <- get_response(url)

  page_text <- httr2::resp_body_html(res) |>
    rvest::html_element("body") |>
    rvest::html_element(
      "div.stat-paginate-index.rig"
    ) |>
    rvest::html_text()

  last_page <- stringr::str_match(
    page_text,
    "([0-9]+)/([0-9]+)ページ"
  )[1, 3]

  if (is.na(last_page)) {
    stop("最大ページ数を取得できませんでした")
  }

  as.integer(last_page)
}


# ---------------------------------------------
# 一覧ページから統計コードを取得
# ---------------------------------------------

get_statcodes <- function(page) {

  url <- paste0(
    BASE_URL,
    "/stat-search?page=",
    page
  )

  res <- get_response(url)

  doc <- httr2::resp_body_html(res) |>
    rvest::html_element("body")

  codes <- doc |>
    rvest::html_elements("span.stat-title") |>
    rvest::html_text() |>
    stringr::str_extract("[0-9]{8}")

  codes <- unique(
    as.character(
      stats::na.omit(codes)
    )
  )

  if (length(codes) == 0) {
    stop("統計コードを抽出できませんでした")
  }

  codes
}


# ---------------------------------------------
# 統計詳細ページのテーブル取得
# ---------------------------------------------

get_detail_info <- function(statcode) {

  url <- paste0(
    BASE_URL,
    "/statistics/",
    statcode
  )

  log_message("GET ", url)

  res <- get_response(url)

  table_node <- httr2::resp_body_html(res) |>
    rvest::html_element("body") |>
    rvest::html_element(
      "table.stat-resource_sheet.stat-resource_table"
    )

  if (length(table_node) == 0 ||
      is.na(table_node)) {
    stop("統計詳細テーブルが見つかりません")
  }

  info <- rvest::html_table(table_node)

  if (ncol(info) != 2) {
    stop("統計詳細テーブルの列数が不正です")
  }

  info
}


# ---------------------------------------------
# 調査計画ページのテーブル取得
# ---------------------------------------------

get_plan_info <- function(statcode) {

  url <- paste0(
    BASE_URL,
    "/surveyplan/p",
    statcode,
    "001"
  )

  log_message("GET ", url)

  res <- get_response(
    url,
    allow_404 = TRUE
  )

  # 調査計画が存在しない場合
  if (is.null(res)) {
    log_message(
      "PLAN NOT FOUND: ",
      statcode
    )
    return(NULL)
  }

  tables <- httr2::resp_body_html(res) |>
    rvest::html_element("body") |>
    rvest::html_elements(
      "table.stat-resource_sheet.stat-resource_table"
    )

  if (length(tables) == 0) {
    return(NULL)
  }

  plan <- tables |>
    rvest::html_table() |>
    dplyr::bind_rows()

  if (ncol(plan) != 2) {
    stop("調査計画テーブルの列数が不正です")
  }

  plan
}


# ---------------------------------------------
# JSONに変換
# ---------------------------------------------

convert_info <- function(info) {

  info |>
    stats::setNames(
      c("name", "value")
    ) |>
    tidyr::pivot_wider() |>
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        function(x) {

          ifelse(
            is.na(x) | x == "",
            "",
            strsplit(
              x,
              "\n",
              fixed = TRUE
            )
          )

        }
      )
    )
}


# ---------------------------------------------
# 統計コード1件処理
# ---------------------------------------------

get_stat_info <- function(
    statcode,
    dest_dir) {

  dest <- file.path(
    dest_dir,
    paste0(statcode, ".json")
  )

  # 取得済みデータをスキップ
  if (is_completed(dest)) {

    log_message(
      "SKIP ",
      statcode
    )

    return("skipped")
  }

  current_url <- paste0(
    BASE_URL,
    "/statistics/",
    statcode
  )

  tryCatch({

    # 統計詳細
    info <- get_detail_info(statcode)

    Sys.sleep(REQUEST_INTERVAL)

    # 調査計画
    current_url <- paste0(
      BASE_URL,
      "/surveyplan/p",
      statcode,
      "001"
    )

    plan <- get_plan_info(statcode)

    if (!is.null(plan) && nrow(plan) > 0) {

      info <- dplyr::bind_rows(
        info,
        plan
      ) |>
        dplyr::distinct()
    }

    # JSON変換
    output <- convert_info(info)

    # 一時ファイルに書き込む
    tmp <- tempfile(
      pattern = "stat_",
      tmpdir = dest_dir,
      fileext = ".json"
    )

    on.exit(
      unlink(tmp),
      add = TRUE
    )

    jsonlite::write_json(
      output,
      path = tmp,
      pretty = TRUE,
      auto_unbox = TRUE
    )

    # 正常に書けているか確認
    if (!is_completed(tmp)) {
      stop("JSONファイルの検証に失敗しました")
    }

    # 最終ファイルへ移動
    if (!file.rename(tmp, dest)) {
      stop("JSONファイルの保存に失敗しました")
    }

    log_message(
      "SAVED ",
      statcode
    )

    "success"

  }, error = function(e) {

    save_error(
      type = "stat",
      id = statcode,
      url = current_url,
      error = conditionMessage(e),
      dest_dir = dest_dir
    )

    "failed"
  })
}


# ---------------------------------------------
# 全統計取得
# ---------------------------------------------

create_stat_info <- function(dest_dir) {

  dir.create(
    dest_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )

  last_page <- get_last_page()

  log_message(
    "TOTAL PAGES: ",
    last_page
  )

  success <- 0L
  skipped <- 0L
  failed <- 0L
  failed_pages <- 0L

  for (page in seq_len(last_page)) {

    log_message(
      "===== PAGE ",
      page,
      "/",
      last_page,
      " ====="
    )

    page_url <- paste0(
      BASE_URL,
      "/stat-search?page=",
      page
    )

    statcodes <- tryCatch({

      get_statcodes(page)

    }, error = function(e) {

      save_error(
        type = "page",
        id = page,
        url = page_url,
        error = conditionMessage(e),
        dest_dir = dest_dir
      )

      NULL
    })

    if (is.null(statcodes)) {

      failed_pages <- failed_pages + 1L

      next
    }

    for (statcode in statcodes) {

      result <- get_stat_info(
        statcode,
        dest_dir
      )

      if (result == "success") {

        success <- success + 1L

      } else if (result == "skipped") {

        skipped <- skipped + 1L

      } else {

        failed <- failed + 1L

      }

      Sys.sleep(REQUEST_INTERVAL)
    }
  }

  log_message("===== FINISHED =====")
  log_message("SUCCESS      : ", success)
  log_message("SKIPPED      : ", skipped)
  log_message("FAILED       : ", failed)
  log_message("FAILED PAGES : ", failed_pages)

  invisible(list(
    success = success,
    skipped = skipped,
    failed = failed,
    failed_pages = failed_pages
  ))
}


# ---------------------------------------------
# メイン処理
# ---------------------------------------------

root_dir <- "./resource"

dest_dir <- file.path(
  root_dir,
  "stat_info"
)

dir.create(
  dest_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# 前回のエラーログだけ削除
failed_log <- file.path(
  dest_dir,
  "failed.csv"
)

if (file.exists(failed_log)) {
  unlink(failed_log)
}

log_message(
  "R VERSION: ",
  R.version.string
)

log_message(
  "httr2 VERSION: ",
  as.character(
    utils::packageVersion("httr2")
  )
)

result <- create_stat_info(dest_dir)

# 一部失敗があっても処理を最後まで実行してから判定
if (
  result$failed > 0 ||
  result$failed_pages > 0
) {

  stop(
    paste0(
      "取得失敗があります。 ",
      "FAILED=",
      result$failed,
      ", FAILED PAGES=",
      result$failed_pages
    ),
    call. = FALSE
  )
}

log_message("ALL COMPLETED")
