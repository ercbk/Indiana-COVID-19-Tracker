# Build some datasets

# Notes
# 1. The Indiana Data Hub only sources the current days counts of beds and ventilators, so this script saves each days counts and creates a dataset with the historical data
# 2. Race data from COVID Tracking Project



library(dplyr, warn.conflicts = F, quietly = T)



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Beds and ventilators ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@


todays_date <- lubridate::today()

try_date_str <- todays_date %>% 
      stringr::str_extract(pattern = "-[0-9]{2}-[0-9]{2}") %>% 
      stringr::str_remove_all(pattern = "-") %>% 
      stringr::str_remove(pattern = "^[0-9]")

# Indiana Data Hub
try_address <- glue::glue("https://hub.mph.in.gov/dataset/5a905d51-eb50-4a83-8f79-005239bd108b/resource/882a7426-886f-48cc-bbe0-a8d14e3012e4/download/covid_report_bedvent_{try_date_str}.xlsx")

try_destfile <- glue::glue("data/beds-vents-{try_date_str}.xlsx")
download.file(try_address, destfile = try_destfile, mode = "wb")

bv_dat_current <- readxl::read_xlsx(try_destfile) %>%
      tidyr::pivot_wider(names_from = "STATUS_TYPE", values_from = "TOTAL") %>%
      mutate(date = todays_date) %>%
      select(date, everything())

# indy data hub changed col names mid-pandemic, so I needed to revert them back to maintain consistency with scripts and past data 
bv_dat_current <- readxl::read_xlsx(try_destfile) %>%
   # rename(beds_icu_occupied_beds_covid_19,
   #        beds_icu_total,
   #        bed_occupied_icu_non_covid = m2b_hospitalized_icu_occupied_non_covid,
   #        beds_available_icu_beds_total = m2b_hospitalized_icu_available,
   #        vents_all_available_vents_not_in_use = m2b_hospitalized_vent_available,
   #        vents_total = m2b_hospitalized_vent_supply,
   #        vents_all_in_use_covid_19 = m2b_hospitalized_vent_occupied_covid,
   #        vents_non_covid_pts_on_vents = m2b_hospitalized_vent_occupied_non_covid) %>%
   tidyr::pivot_wider(names_from = STATUS_TYPE, values_from = TOTAL) %>% 
   janitor::clean_names() %>% 
      mutate(date = lubridate::today()) %>%
      select(date, beds_icu_total, beds_icu_occupied_covid_19,
             beds_available_icu_beds_total,
             vents_total, vents_all_use_covid_19,
             vents_non_covid_pts_on_vents, vents_all_available_vents_not_in_use)


old_complete <- readr::read_csv("data/beds-vents-complete.csv")

new_complete <- old_complete %>%
      bind_rows(bv_dat_current)

readr::write_csv(new_complete, "data/beds-vents-complete.csv")


bv_data_files <- tibble::tibble(paths = fs::dir_ls(glue::glue("{rprojroot::find_rstudio_root_file()}/data"), regexp = "beds-vents-[0-9]")) %>% 
   mutate(date = stringr::str_extract(paths,
                                  pattern = "[0-9]{3}") %>%
         as.numeric()
   )


if (nrow(bv_data_files) > 7) {
   # clean-up old files
   bv_data_files %>% 
      slice_min(date) %>% 
      pull(paths) %>% 
      fs::file_delete(.)
}



#@@@@@@@@@@@@
# Race ----
#@@@@@@@@@@@@


# The Covid Tracking Project
race_dat_raw <- readr::read_csv("https://docs.google.com/spreadsheets/d/e/2PACX-1vS8SzaERcKJOD_EzrtCDK1dX1zkoMochlA9iHoHg_RSw3V8bkpfk1mpw4pfL5RdtSOyx_oScsUtyXyk/pub?gid=43720681&single=true&output=csv")

race_date <- race_dat_raw %>% 
   janitor::clean_names() %>% 
   filter(state == "IN") %>% 
   mutate(date = lubridate::ymd(date)) %>% 
   slice_max(date) %>% 
   pull(date)

race_complete <- readr::read_csv("data/ind-race-complete.csv")

race_comp_date <- race_complete %>%
   filter(date == max(date)) %>% 
   pull(date)

if (race_date != race_comp_date) {
   
   ind_race <- race_dat_raw %>%
      janitor::clean_names() %>% 
      filter(state == "IN") %>% 
      mutate(date = lubridate::ymd(date),
             cases_black = as.numeric(cases_black))
   
   race_complete <- race_complete %>% 
      bind_rows(ind_race)
   
   readr::write_csv(race_complete, "data/ind-race-complete.csv")
   
}




#@@@@@@@@@@@
# Age ----
#@@@@@@@@@@@


age_hist_url <- "https://hub.mph.in.gov/dataset/6bcfb11c-6b9e-44b2-be7f-a2910d28949a/resource/7661f008-81b5-4ff2-8e46-f59ad5aad456/download/covid_report_death_date_agegrp.xlsx"
download.file(url, destfile = glue::glue("{rprojroot::find_rstudio_root_file()}/data/age-deaths-historic.xlsx"), mode = "wb")
age_death_hist <- readxl::read_xlsx(glue::glue("{rprojroot::find_rstudio_root_file()}/data/age-deaths-historic.xlsx"))

age_hist_dat <- age_death_hist %>% 
   tidyr::pivot_wider(names_from = agegrp,
                      values_from = covid_deaths,
                      values_fill = 0) %>% 
   tidyr::pivot_longer(cols = !matches("date"),names_to = "agegrp", values_to = "covid_deaths") %>% 
   mutate(date = lubridate::as_date(date))

readr::write_csv(age_hist_dat, "data/ind-age-hist-complete.csv")


# # Indiana Data Hub
# age_url <- "https://hub.mph.in.gov/dataset/62ddcb15-bbe8-477b-bb2e-175ee5af8629/resource/2538d7f1-391b-4733-90b3-9e95cd5f3ea6/download/covid_report_demographics.xlsx"
# 
# age_dest <- glue::glue("data/ind-demog-{try_date_str}.xlsx")
# age_dest <- glue::glue("data/ind-demog-819.xlsx")
# 
# download.file(age_url, destfile = age_dest, mode = "wb")
# 
# # Has multiple sheets, but this is fine since I only need the first one.
# age_raw <- readxl::read_xlsx(age_dest, col_types = c("text", "numeric", "numeric",
#                                                      "numeric", "numeric", "numeric", "numeric"))
# 
# # indyhub changed col names and order mid-pandemic, so need to revert names to keep scripts/data consistent
# age_dat <- age_raw %>% 
#    janitor::clean_names() %>%
#    mutate(date = lubridate::today()) %>%
#    rename_at(vars(-date), ~stringr::str_remove(.,"m1d_")) %>%
#    # rename(covid_count = covid_cases, covid_count_pct = covid_cases_pct,
#    #        covid_test = covid_tests, covid_test_pct = covid_tests_pct) %>% 
#    select(date, agegrp, covid_count, covid_deaths,
#           covid_test, covid_count_pct, covid_deaths_pct,
#           covid_test_pct)
# 
# 
# age_comp <- readr::read_csv("data/ind-age-complete.csv")
# 
# # Make sure data is new before adding it
# # test the last rows from both datasets
# age_comp_test <- age_comp %>% 
#    filter(agegrp == "30-39") %>% 
#    select(-date) %>% 
#    slice(n())
# age_dat_test <- age_dat %>% 
#    filter(agegrp == "30-39") %>% 
#    select(-date) %>% 
#    slice(n())
# 
# if (!isTRUE(all.equal(age_comp_test, age_dat_test))) {
#    
#    age_comp <- age_comp %>%
#       bind_rows(age_dat)
#    
#    readr::write_csv(age_comp, "data/ind-age-complete.csv")
#    
# }



demog_data_files <- tibble::tibble(paths = fs::dir_ls(glue::glue("{rprojroot::find_rstudio_root_file()}/data"), regexp = "ind-demog-[0-9]")) %>% 
   mutate(date = stringr::str_extract(paths,
                                      pattern = "[0-9]{3}") %>%
             as.numeric()
   )

if (nrow(demog_data_files) > 7) {
   # clean-up old files
   demog_data_files %>% 
      slice_min(date) %>% 
      pull(paths) %>% 
      fs::file_delete(.)
}
