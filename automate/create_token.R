# Create rtweet token to use in github actions

library(rtweet)

token_stuff <- Sys.getenv(c("APPNAME", "APIKEY", "APISECRET", "ACCESSTOKEN", "ACCESSSECRET"))

create_token(
      app = token_stuff[[1]],
      consumer_key = token_stuff[[2]],
      consumer_secret = token_stuff[[3]],
      access_token = token_stuff[[4]],
      access_secret = token_stuff[[5]])