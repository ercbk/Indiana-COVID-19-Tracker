# Build some datasets

# Notes
# 1. The Indiana Data Hub only sources the current days counts of beds and ventilators, so this script saves each days counts and creates a dataset with the historical data
# 2. Race data from COVID Tracking Project



library(dplyr, warn.conflicts = F, quietly = T)



###########################
# Beds and ventilators
###########################


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


# keep a week's worth of files, delete anything older
delete_date <- todays_date - 7 
del_date_str <- delete_date %>% 
   stringr::str_extract(pattern = "-[0-9]{2}-[0-9]{2}") %>% 
   stringr::str_remove_all(pattern = "-") %>% 
   stringr::str_remove(pattern = "^[0-9]")

fs::file_delete(glue::glue("{rprojroot::find_rstudio_root_file()}/data/beds-vents-{del_date_str}.xlsx"))




#################
# Race
#################


race_dat_raw <- readr::read_csv("https://docs.google.com/spreadsheets/d/e/2PACX-1vR_xmYt4ACPDZCDJcY12kCiMiH0ODyx3E1ZvgOHB8ae1tRcjXbs_yWBOA4j4uoCEADVfC1PS2jYO68B/pub?gid=43720681&single=true&output=csv")

race_date <- race_dat_raw %>% 
   janitor::clean_names() %>% 
   filter(state == "IN") %>% 
   mutate(date = lubridate::ymd(date)) %>% 
   pull(date)

race_complete <- readr::read_csv("data/ind-race-complete.csv")

race_comp_date <- race_complete %>%
   filter(date == max(date)) %>% 
   pull(date)

if (race_date != race_comp_date) {
   
   ind_race <- race_dat_raw %>%
      janitor::clean_names() %>% 
      filter(state == "IN") %>% 
      mutate(date = lubridate::ymd(date))
   
   race_complete <- race_complete %>% 
      bind_rows(ind_race)
   
   readr::write_csv(race_complete, "data/ind-race-complete.csv")
   
}

