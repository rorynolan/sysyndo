if (!"pacman" %in% rownames(installed.packages())) install.packages("pacman")
pacman::p_load(gmailr, here, tidyverse, filesstrings, magrittr, checkmate,
               lubridate, parsedate, conflicted, xml2, rvest, janitor, clipr,
               memoise, beepr)

conflict_prefer("setdiff", "dplyr")
conflict_prefer("body", "base")
conflict_prefer("message", "base")

gm_auth_configure(path = here::here("gmailrn.json"))

#' Get the number of unix epoch seconds in a datetime.
#'
#' This function is vectorized.
#'
#' @param datetime Something that can be parsed with [parsedate::parse_date()].
#'
#' @return A number.
#'
#' @noRd
unix_secs <- function(datetime) {
  map_dbl(datetime, ~as.numeric(parsedate::parse_date(.x)))
}

#' Extract the bet table from a message.
#'
#' @param msg A `gmail_message`.
#'
#' @return A tibble.
#'
#' @noRd
extract_table_non_memoised <- function(msg) {
  msg_body <- gm_body(msg, "text")[[2]]
  assert_character(msg_body)
  msg_body %<>% read_html()
  rows <- xml_find_all(msg_body, "//tr")
  cells <- map(rows, xml_find_all, "./td")
  cell_contents <- map(cells, ~map_chr(.x, xml_text))
  tsv_vec <- map_chr(cell_contents, str_c, collapse = "\t")
  out <- read_tsv(tsv_vec)
  clean_names(out)
}
extract_table <- memoise(extract_table_non_memoised)

#' Get the category of a message.
#'
#' Bets can be either cat 10, 15, 20 or 30, but messages can only be cat 10, 15
#' or 20 (cat 30 bets come in cat 20 messages).
#'
#' @param msg A `gmail_message`.
#'
#' @return A string. Either `"10"`, `"15"` or `"20"`.
#'
#' @noRd
msg_category <- function(msg) {
  tab <- extract_table(msg) %>%
    mutate(cat = as.character(cat)) %>%
    mutate(cat = if_else(cat == "30", "20", cat))
  out <- unique(tab$cat)
  assert_string(out, pattern = "^(10|15|20)$")
  out
}

#' Get the body of a `gmail_message` as a string.
#'
#' @param gmail_message A `gmail_message`.
#'
#' @return A string.
gmailr_msg_body_chr <- function(gmail_message) {
  bod <- gm_body(gmail_message)
  if (length(bod)) {
    out <- str_c(bod[[1]], collapse = "\n")
  } else {
    out <- character(1)
  }
  assert_string(out)
  out
}

#' Copy bet table to clipboard.
#'
#' @param cat The category. Either 10, 15 or 20.
#' @param msg_time `"early"` or `"late"`.
#' @param days_ago 0 is today, 1 is yesterday, 2 is the day before yesterday and
#'   so on.
#'
#' @noRd
clip_bets <- function(category, msg_time = "early", days_ago = 0) {
  category <- match_arg(toString(category), c("10", "15", "20"))
  assert_count(days_ago)
  assert_string(msg_time)
  msg_time %<>% match_arg(c("early", "late"), ignore_case = TRUE)
  req_date <- today() - days_ago
  date_after <- req_date + 1
  n <- 10
  enough <- FALSE
  while (!enough) {
    msgs <- messages(search = "sysanalyst", num_results = n)
    msg_ids <- gm_id(msgs)
    msgs <- map(msg_ids, gm_message)
    dates <- map(msgs, gmailr::date)
    if (min(unix_secs(dates)) <= unix_secs(req_date)) {
      enough <- TRUE
    } else {
      n <- 2 * n
    }
    if (n > 999) stop("Refusing to attempt to fetch 1,000 emails.")
  }
  msgs <- msgs[
    between(unix_secs(dates), unix_secs(req_date), unix_secs(date_after))
    ]
  msg_bodies <- map_chr(msgs, gmailr_msg_body_chr)
  msgs <- msgs[str_detect(msg_bodies, "Cat.+Time.+Crs.+Name.+Total Stake")]
  msg_cats <- map_chr(msgs, msg_category)
  msgs <- msgs[msg_cats == category]
  if (length(msgs) == 0) {
    rlang::abort(
      str_glue(
        "Could not find any cat {category} messages for the {msg_time} window."
      )
    )
  }
  usecs <- unix_secs(map(msgs, gmailr::date))
  usec_groups <- group_close(sort(usecs), max_gap = 30 * 60)
  if (length(usec_groups) %in% 1:2) {
    if (length(usec_groups) == 1) {
      usec_group <- usec_groups[[1]]
    } else {
      usec_group <- usec_groups[[match(msg_time, c("early", "late"))]]
    }
  } else {
    stop("Couldn't delimit message windows. You'll have to go manual :-(.")
  }
  msgs <- msgs[usecs %in% usec_group]
  msg <- msgs[[which.max(map_int(msgs, ~nrow(extract_table(.x))))]]
  out <- msg %>%
    extract_table() %>%
    mutate(date = dmy(date),
           date = str_glue("{month(date)}/{day(date)}"),
           place_stake = str_trim(as.character(place_stake)),
           place_stake = if_else(is.na(place_stake), "", place_stake)) %>%
    mutate(odds = "", bookmaker = "",
           places = if_else(as.logical(str_length(place_stake)), "", "NA"),
           ew_terms = if_else(places == "", "", "0"),
           time = as.character(time),
           time = if_else(str_count(time, coll(":")) == 2,
                          str_before_last(time, coll(":")),
                          time),
           placer = "") %>%
    select(date, time, crs, name, odds, bookmaker,
           places, ew_terms, placer, win_stake)
  write_clip(unname(as.matrix(out)))
  message(nrow(out), " cat ", category,
          " bet", if_else(nrow(out) == 1, "", "s"),
          " copied to clipbboard.")
  beep()
  invisible(out)
}
cb <- clip_bets
