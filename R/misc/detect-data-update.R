# Tests whether Indy health department has tweeted updated COVID data between before the 57th minute of whichever hour I have set in the github action yaml

# returns true if it finds an updated-data-tweet with todays date.
# returns error if after ~1hr no such tweet is detected

# An error keeps the rest of the scripts from running in the noon workflow, then later in the day, the evening workflow will process the updates


suppressPackageStartupMessages(suppressWarnings(library(dplyr)))

# environment vars set in the yaml and in github secrets
token_stuff <- Sys.getenv(c("APPNAME", "APIKEY", "APISECRET", "ACCESSTOKEN", "ACCESSSECRET"))

rt_tok <- rtweet::create_token(
   app = token_stuff[[1]],
   consumer_key = token_stuff[[2]],
   consumer_secret = token_stuff[[3]],
   access_token = token_stuff[[4]],
   access_secret = token_stuff[[5]],
   set_renv = FALSE)

# need to set the initial value
tweet_rows <- 0

lubridate::hour(Sys.time())

# Runner uses UTC timezone so 4:00 should be 12pm ET
while (lubridate::hour(Sys.time()) <= 17 & tweet_rows == 0) {
   
   # detect pattern in tweet that has updated data
   in_health_tweets <- rtweet::get_timeline("StateHealthIN",
                                            n = 150,
                                            token = rt_tok) %>% 
      tidyr::separate(col = "created_at", into = c("date", "time"), sep = " ") %>% 
      mutate(date = lubridate::as_date(date),
             time = hms::as_hms(time)) %>%
      select(date, text) %>% 
      filter(stringr::str_detect(text, pattern = "latest #COVID19 case information") | stringr::str_detect(text, pattern = "positive cases")) %>% 
      filter(date == lubridate::today())
   
   # If detection successful, tweet_rows != 0
   tweet_rows <- nrow(in_health_tweets)
   
   # if detection unsuccessful, wait two min before trying again
   if (tweet_rows == 0) {
         Sys.sleep(120)
   }
   
}


