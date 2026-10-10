get_response <- function(url) {

  request(url) %>%
    req_method("GET") %>%
    req_options(http_version = 2L) %>%  # HTTP/1.1
    req_timeout(60) %>%
    req_retry(
      max_tries = 5,
      retry_on_failure = TRUE,
      is_transient = function(resp) {
        resp_status(resp) %in% c(
          429, 500, 502, 503, 504
        )
      }
    ) %>%
    req_error(
      is_error = function(resp) {
        # 404は呼び出し側で判定
        resp_status(resp) >= 400 &&
          resp_status(resp) != 404
      }
    ) %>%
    req_perform()
}


# エラーログを追記
save_error <- function(
    type, id, url, error, dest_dir) {

  path <- file.path(dest_dir, "failed.csv")

  record <- data.frame(
    datetime = as.character(Sys.time()),
    type = type,
    id = as.character(id),
    url = url,
    error = as.character(error)
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

  message(glue("ERROR [{type}] {id}: {error}"))
}


get_last_page <- function() {

  url <- "https://www.e-stat.go.jp/stat-search?page=1"

  res <- get_response(url)

  if (resp_status(res) != 200) {
    stop("統計一覧の取得に失敗しました")
  }

  page_text <- resp_body_html(res) %>%
    html_element("body") %>%
    html_element("div.stat-paginate-index.rig") %>%
    html_text()

  last_page <- str_match(
    page_text,
    "([0-9]+)/([0-9]+)ページ"
  )[1, 3]

  if (is.na(last_page)) {
    stop("最大ページ数を取得できませんでした")
  }

  as.integer(last_page)
}


# 統計情報を1件取得
get_stat_info <- function(statcode, dest_dir) {

  dest <- file.path(
    dest_dir,
    glue("{statcode}.json")
  )

  # 取得済みJSONはスキップ
  if (file.exists(dest) &&
      file.size(dest) > 0) {
    message(glue("SKIP: {statcode}"))
    return(TRUE)
  }

  # 詳細ページ
  url <- glue(
    "https://www.e-stat.go.jp/statistics/{statcode}"
  )

  message(glue("GET: {url}"))

  result <- tryCatch({

    res <- get_response(url)

    if (resp_status(res) != 200) {
      stop(glue("HTTP {resp_status(res)}"))
    }

    info <- resp_body_html(res) %>%
      html_element("body") %>%
      html_element(
        "table.stat-resource_sheet.stat-resource_table"
      ) %>%
      html_table()

    # 調査計画ページ
    plan_url <- glue(
      "https://www.e-stat.go.jp/surveyplan/p{statcode}001"
    )

    message(glue("GET: {plan_url}"))

    plan_res <- get_response(plan_url)

    if (resp_status(plan_res) == 200) {

      plan <- resp_body_html(plan_res) %>%
        html_element("body") %>%
        html_elements(
          "table.stat-resource_sheet.stat-resource_table"
        ) %>%
        html_table() %>%
        bind_rows()

      info <- bind_rows(info, plan) %>%
        distinct()

    } else if (resp_status(plan_res) != 404) {
      stop(glue(
        "調査計画 HTTP {resp_status(plan_res)}"
      ))
    }

    # 元のJSON変換処理
    output <- info %>%
      setNames(c("name", "value")) %>%
      pivot_wider() %>%
      mutate(across(
        everything(),
        ~ ifelse(
          is.na(.) | . == "",
          "",
          strsplit(., "\n", fixed = TRUE)
        )
      ))

    # 書き込み途中の不完全なJSONを残さない
    tmp <- tempfile(
      pattern = "stat_",
      tmpdir = dest_dir,
      fileext = ".json"
    )

    on.exit(unlink(tmp), add = TRUE)

    jsonlite::write_json(
      output,
      path = tmp,
      pretty = TRUE,
      auto_unbox = TRUE
    )

    if (!file.rename(tmp, dest)) {
      stop("JSONファイルの保存に失敗しました")
    }

    TRUE

  }, error = function(e) {

    save_error(
      type = "stat",
      id = statcode,
      url = url,
      error = conditionMessage(e),
      dest_dir = dest_dir
    )

    FALSE
  })

  result
}


create_stat_info <- function(dest_dir) {

  dir.create(
    dest_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )

  last_page <- get_last_page()

  message(glue("TOTAL PAGES: {last_page}"))

  success <- 0L
  failed <- 0L
  skipped_pages <- 0L

  for (page in seq_len(last_page)) {

    message(glue(
      "===== PAGE {page}/{last_page} ====="
    ))

    url <- glue(
      "https://www.e-stat.go.jp/stat-search?page={page}"
    )

    # 一覧取得失敗時は次ページへ
    statcodes <- tryCatch({

      res <- get_response(url)

      if (resp_status(res) != 200) {
        stop(glue("HTTP {resp_status(res)}"))
      }

      doc <- resp_body_html(res) %>%
        html_element("body")

      codes <- doc %>%
        html_elements("span.stat-title") %>%
        html_text() %>%
        str_extract("[0-9]{8}") %>%
        na.omit() %>%
        unique() %>%
        as.character()

      if (length(codes) == 0) {
        stop("統計コードを抽出できませんでした")
      }

      codes

    }, error = function(e) {

      save_error(
        type = "page",
        id = page,
        url = url,
        error = conditionMessage(e),
        dest_dir = dest_dir
      )

      NULL
    })

    if (is.null(statcodes)) {
      skipped_pages <- skipped_pages + 1L
      next
    }

    for (statcode in statcodes) {

      result <- get_stat_info(
        statcode,
        dest_dir
      )

      if (result) {
        success <- success + 1L
      } else {
        failed <- failed + 1L
      }

      # リクエスト間隔を確保
      Sys.sleep(0.5)
    }
  }

  message("===== FINISHED =====")
  message(glue("SUCCESS: {success}"))
  message(glue("FAILED : {failed}"))
  message(glue("FAILED PAGES: {skipped_pages}"))

  if (failed > 0 || skipped_pages > 0) {
    warning("取得に失敗したデータがあります")
  }

  invisible(list(
    success = success,
    failed = failed,
    failed_pages = skipped_pages
  ))
}


# 実行
root_dir <- "./resource"
dest_dir <- file.path(root_dir, "stat_info")

# 既存のデータを削除しない
dir.create(
  dest_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

result <- create_stat_info(dest_dir)

# 失敗が残っている場合はActionsを失敗扱いにする
if (result$failed > 0 ||
    result$failed_pages > 0) {
  stop("一部の統計情報を取得できませんでした")
}
