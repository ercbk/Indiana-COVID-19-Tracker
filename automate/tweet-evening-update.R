# Post tweets with updated charts


# necessary for github actions
token_stuff_e <- Sys.getenv(c("APPNAMEE", "APIKEYE", "APISECRETE", "ACCESSTOKENE", "ACCESSSECRETE"))

rt_tok_e <- rtweet::create_token(
      app = token_stuff_e[[1]],
      consumer_key = token_stuff_e[[2]],
      consumer_secret = token_stuff_e[[3]],
      access_token = token_stuff_e[[4]],
      access_secret = token_stuff_e[[5]],
      set_renv = FALSE)

token_stuff_f <- Sys.getenv(c("APPNAMEF", "APIKEYF", "APISECRETF", "ACCESSTOKENF", "ACCESSSECRETF"))

rt_tok_f <- rtweet::create_token(
      app = token_stuff_f[[1]],
      consumer_key = token_stuff_f[[2]],
      consumer_secret = token_stuff_f[[3]],
      access_token = token_stuff_f[[4]],
      access_secret = token_stuff_f[[5]],
      set_renv = FALSE)


suppressPackageStartupMessages(suppressWarnings(library(dplyr)))


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


pngs <- png_files %>%
      slice(c(1,4,7)) %>% 
      pull(paths)

png_dates <- png_files %>% 
      distinct(date) %>% 
      mutate(date = format(date, "%b %d")) %>% 
      pull(date)


msg <- glue::glue("Evening update: charts current for {png_dates[[1]]} and {png_dates[[2]]}. More charts and analysis at
                  https://github.com/ercbk/Indiana-COVID-19-Tracker")



rtweet::post_tweet(msg,
                   media = pngs,
                   token = rt_tok_e)

rtweet::post_tweet(msg,
                   media = pngs,
                   token = rt_tok_f)
