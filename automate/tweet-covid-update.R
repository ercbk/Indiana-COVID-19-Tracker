# Post tweets with updated charts


suppressPackageStartupMessages(suppressWarnings(library(dplyr)))

tweet_id <- rtweet::get_timeline("StateHealthIN", n = 150) %>% 
      tidyr::separate(col = "created_at", into = c("date", "time"), sep = " ") %>% 
      mutate(date = lubridate::as_date(date),
             time = hms::as_hms(time)) %>%
      select(date, status_id, text) %>% 
      filter(stringr::str_detect(text, pattern = "latest #COVID19 case information") | stringr::str_detect(text, pattern = "positive cases")) %>% 
      filter(date == lubridate::today()) %>% 
      pull(status_id)

# get plot paths, names, and dates
png_files <- tibble::tibble(paths = fs::dir_ls(here::here("plots"))) %>% 
      mutate(
            chart = stringr::str_extract(paths,
                                         pattern = "[a-z]*-[a-z]*-[a-z]*"),
            date = stringr::str_extract(paths,
                                        pattern = "[0-9]{4}-[0-9]{2}-[0-9]{2}") %>%
                  as.Date()
            ) %>%
      group_by(chart) %>% 
      filter(date == max(date)) %>% 
      ungroup()

      
pngs1 <- png_files %>%
      slice(1:3) %>% 
      pull(paths)

pngs2 <- png_files %>%
      slice(4:5) %>% 
      pull(paths)

png_dates <- png_files %>% 
      distinct(date) %>% 
      mutate(date = format(date, "%b %d")) %>% 
      pull(date)

msg <- glue::glue("Charts updated for {png_dates[[1]]} and {png_dates[[2]]}
                  https://github.com/ercbk/Indiana-COVID-19-Tracker")

# rtweet::post_tweet(msg,
#            in_reply_to_status_id = tweet_id,
#            media = pngs1)
# rtweet::post_tweet(msg,
#            in_reply_to_status_id = tweet_id,
#            media = pngs2)
