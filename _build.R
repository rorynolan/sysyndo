pacman::p_load(tidyverse, git2r, lubridate, knitr, conflicted, here)

need_to_push <- function() {
  last_commit_message <- last_commit()$message
  last_commit_was_travis <- str_detect(last_commit_message, "Travis build")
  ntp <- TRUE
  if (last_commit_was_travis) {
    secs_since_last_commit <- as.period(
      now() - ymd_hms(git2r::when(last_commit()))
    ) %>%
      period_to_seconds()
    if (secs_since_last_commit < 60 * 60) {  # one hour
      ntp <- FALSE
    }
  }
  ntp
}

# Sync with remote
checkout(repository(), branch = "master")
remote_set_url(name = "origin",
               url = str_c("http", "s", ":", "//",
                           Sys.getenv("GITHUB_PAT"),
                           "@github.com/",
                           "rorynolan/sysyndo.git"))
branch_set_upstream(branch = branches()$master, "origin/master")
git2r::pull()

# knit
knit(here("report.Rmd"))

# commit and push
if (need_to_push()) {
  print("Attempting push of auto travis build.")
  commit(message = str_c("Daily auto build of report.md. ",
                         "Travis build: ",
                         Sys.getenv("TRAVIS_BUILD_NUMBER"),
                         "."),
         all = TRUE
  )
  push()
}
