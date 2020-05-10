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
png_files <- tibble::tibble(paths = fs::dir_ls(glue::glue("{rprojroot::find_rstudio_root_file()}/plots"))) %>% 
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
   slice(c(9,1,5)) %>% 
   pull(paths)

png_dates <- png_files %>% 
   distinct(date) %>% 
   mutate(date = format(date, "%b %d")) %>% 
   pull(date)


if (length(png_dates) > 2) {
   date_str <- glue::glue_collapse(png_dates, sep = ", ", last = ", and ")
} else {
   date_str <- glue::glue_collapse(png_dates, sep = " and ")
}


msg_e <- glue::glue("Indiana COVID-19 Tracker evening update: charts current for {date_str}. More charts and analysis at
                  https://github.com/ercbk/Indiana-COVID-19-Tracker #rstats")

msg_f <- glue::glue("Indiana COVID-19 Tracker evening update: charts current for {date_str}. More charts and analysis at
                  https://github.com/ercbk/Indiana-COVID-19-Tracker")



rtweet::post_tweet(msg_e,
                   media = pngs,
                   token = rt_tok_e)

rtweet::post_tweet(msg_f,
                   media = pngs,
                   token = rt_tok_f)
