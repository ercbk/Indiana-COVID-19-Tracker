# Build some datasets

# Notes
# 1. The Indiana Data Hub only sources the current days counts of beds and ventilators, so this script saves each days counts and creates a dataset with the historical data




library(dplyr, warn.conflicts = F, quietly = T)

todays_date <- lubridate::today()

try_date_str <- todays_date %>% 
      stringr::str_extract(pattern = "-[0-9]{2}-[0-9]{2}") %>% 
      stringr::str_remove_all(pattern = "-") %>% 
      stringr::str_remove(pattern = "^[0-9]")

try_address <- glue::glue("https://hub.mph.in.gov/dataset/5a905d51-eb50-4a83-8f79-005239bd108b/resource/882a7426-886f-48cc-bbe0-a8d14e3012e4/download/covid_report_bedvent_{try_date_str}.xlsx")

try_destfile <- glue::glue("data/beds-vents-{try_date_str}.xlsx")
download.file(try_address, destfile = try_destfile, mode = "wb")

bv_dat_current <- readxl::read_xlsx(try_destfile) %>% 
      tidyr::pivot_wider(names_from = "STATUS_TYPE", values_from = "TOTAL") %>%
      mutate(date = todays_date) %>% 
      select(date, everything())


old_complete <- readr::read_rds("data/beds-vents-complete.rds")

new_complete <- old_complete %>% 
      bind_rows(bv_dat_current)

readr::write_rds(new_complete, "data/beds-vents-complete.rds")
readr::write_csv(new_complete, "data/beds-vents-complete.csv")




