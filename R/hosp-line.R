# Monitors number of hospitalizations





squirrel <- readr::read_csv("data/daily.csv")

ind_sqrl <- squirrel %>% 
      filter(state == "IN")