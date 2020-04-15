# Tests whether Indy health department has tweeted updated COVID data between 10:01am and 10:59am

# returns true if it finds an updated-data-tweet with todays date.
# returns error if after ~1hr if no such tweet is detected

# An error keeps the rest of the scripts from running
# True value == script runs successfully --> task scheduler detects succussful run --> other scripts triggered to run.


suppressPackageStartupMessages(suppressWarnings(library(dplyr)))

# need to set the initial value
tweet_rows <- 0

while (lubridate::minute(Sys.time()) < 55 & tweet_rows == 0) {
   
   in_health_tweets <- rtweet::get_timeline("StateHealthIN", n = 150) %>% 
      tidyr::separate(col = "created_at", into = c("date", "time"), sep = " ") %>% 
      mutate(date = lubridate::as_date(date),
             time = hms::as_hms(time)) %>%
      select(date, text) %>% 
      filter(stringr::str_detect(text, pattern = "latest #COVID19 case information") | stringr::str_detect(text, pattern = "positive cases")) %>% 
      filter(date == lubridate::today())
   
   tweet_rows <- nrow(in_health_tweets)
   
   if (tweet_rows == 0) {
         Sys.sleep(120)
   }
   
}

attempt::stop_if(tweet_rows, ~.x == 0, "Time ran out. No data update detected")


