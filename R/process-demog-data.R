# Process Demographic Data


# Notes
# 1. There were 10 days where I didn't collect age-deaths data. Indy data hub was having problems keeping their column names consistent and I forgot to reactivate the data building script after one of the incidents. Imputing the missing data.


# Sections:
# 1. Median Age Bubble
# 2. Age Cases Heatmap
# 3. Age Deaths Line


pacman::p_load(dplyr, glue, imputeTS)


# Indiana data hub, COVID-19 CASE DATA dataset
# https://hub.mph.in.gov/dataset/covid-19-case-data
# county case counts by age (and gender)
url <- "https://hub.mph.in.gov/dataset/6b57a4f2-b754-4f79-a46b-cff93e37d851/resource/46b310b9-2f29-4a51-90dc-3886d9cf4ac1/download/covid_report.xlsx"
download.file(url, destfile = glue("{rprojroot::find_rstudio_root_file()}/data/cases-age.xlsx"), mode = "wb")
age_cases_raw <- readxl::read_xlsx(glue("{rprojroot::find_rstudio_root_file()}/data/cases-age.xlsx"))

# state deaths, tests counts

# hub_dat_url <- "https://hub.mph.in.gov/dataset/covid-19-case-trend/resource/182b6742-edac-442d-8eeb-62f96b17773e" %>%
#       xml2::read_html() %>%
#       rvest::html_nodes(xpath = "//*[@id='content']/div[3]/div/section[1]/div[1]/p/a") %>% 
#       rvest::html_text()
# 
# download.file(hub_dat_url, destfile = glue("{rprojroot::find_rstudio_root_file()}/data/test-case-trend.xlsx"), mode = "wb")
# test_dat_raw <- readxl::read_xlsx(glue("{rprojroot::find_rstudio_root_file()}/data/test-case-trend.xlsx"))

hub_dat_url <- "https://hub.mph.in.gov/dataset/bd08cdd3-9ab1-4d70-b933-41f9ef7b809d/resource/afaa225d-ac4e-4e80-9190-f6800c366b58/download/covid_report_county_date.xlsx"

download.file(hub_dat_url, destfile = "data/county-test-case-trend.xlsx", mode = "wb")
test_dat_raw <- readxl::read_xlsx("data/county-test-case-trend.xlsx")


# tidycensus pkg, 2018 age populations for Indiana
ind_age_pop <- readr::read_rds(glue("{rprojroot::find_rstudio_root_file()}/data/ind-age-pop.rds"))



# clean and calc weekly cases per age group
age_cases_clean <- age_cases_raw %>% 
      janitor::clean_names() %>% 
      filter(agegrp != "Unknown") %>% 
      # calculate daily cases for each agegrp
      group_by(date, agegrp) %>% 
      summarize(daily_cases = sum(covid_count)) %>% 
      # some agegrps not present for some dates
      # wider then longer fills in the missing agegrps
      tidyr::pivot_wider(names_from = "agegrp",
                         values_from = "daily_cases",
                         values_fill = list(daily_cases = 0)) %>% 
      select(1,3,7,8,2,4,5,9,6) %>% 
      tidyr::pivot_longer(cols = -date,
                          names_to = "age_grp",
                          values_to = "daily_cases") %>% 
      arrange(date) %>% 
      # calculate weekly cases for each agegrp
      mutate(week = lubridate::week(date)) %>% 
      group_by(week) %>% 
      mutate(end_date = last(date)) %>%
      group_by(end_date, age_grp) %>% 
      summarize(weekly_cases = sum(daily_cases)) %>% 
      ungroup() %>% 
      # <age to age>, "80 and older" format
      mutate(age_grp = stringr::str_replace(age_grp, "-", " to "),
             age_grp = stringr::str_replace(age_grp, "\\+", " and older"))



#@@@@@@@@@@@@@@@@@@@@@@@@@
# Median Age Bubble ----
#@@@@@@@@@@@@@@@@@@@@@@@@@


# Calc weekly tests and deaths
test_dea <- test_dat_raw %>% 
   select(date = DATE,
          county_daily_tests = COVID_TESTS_ADMINISTRATED,
          county_daily_deaths = COVID_DEATHS) %>%
   mutate(date = lubridate::ymd(date)) %>% 
   group_by(date) %>% 
   summarize(daily_tests = sum(county_daily_tests),
             daily_deaths = sum(county_daily_deaths),
             .groups = "drop") %>%
   mutate(week = lubridate::week(date)) %>% 
   group_by(week) %>% 
   mutate(end_date = last(date)) %>% 
   group_by(end_date) %>% 
   summarize(weekly_tests = sum(daily_tests),
             weekly_deaths = sum(daily_deaths))


# calc cumulative cases for each week
cumul_cases <- age_cases_clean %>% 
      group_by(end_date) %>% 
      mutate(cumul_cases = cumsum(weekly_cases))

# calculate median of the cumulative cases for each week
median_cases <- age_cases_clean %>% 
      group_by(end_date) %>% 
      mutate(cumul_cases = cumsum(weekly_cases)) %>% 
      summarize(med_cases = last(cumul_cases)/2)


med_age_tbl <- cumul_cases %>% 
      left_join(median_cases, by = "end_date") %>% 
      # once I have median cum_cases, I know age range containing median age. Need first number of that age range
      tidyr::separate(col = "age_grp",
                      into = c("first_age", "last_age"),
                      sep = " to ",
                      remove = F,
      ) %>% 
      # same for "80 and older" category
      mutate(first_age = stringr::str_remove(first_age, " and older") %>% 
                   as.numeric(.),
             # using 10 as constant below, so using 90 for last_age of 80 and older (shouldn't matter much in most cases)
             last_age = stringr::str_replace_na(last_age, 90) %>% 
                   as.numeric(.),
             # need the cumulative cases value prior to the median age range
             lag_cumul_cases = lag(cumul_cases, default = 0)) %>% 
      # pull row with median age range which now has all values needed for calc
      filter(cumul_cases >= med_cases) %>% 
      filter(cumul_cases == min(cumul_cases)) %>% 
      # calc median age for each week (tbl still grouped by end_date); 10 is length of age range
      summarize(median_age = first_age + 10 * ((med_cases - lag_cumul_cases) / weekly_cases),
                end_date = as.Date(end_date)) %>% 
      left_join(test_dea, by = "end_date") %>% 
      mutate(end_date = factor(end_date, labels = format(unique(end_date), "%b %d"), ordered = TRUE))


readr::write_rds(med_age_tbl, glue("{rprojroot::find_rstudio_root_file()}/data/median-age-bubble.rds"))



#@@@@@@@@@@@@@@@@@@@@@@@@@
# Age Cases Heatmap ----
#@@@@@@@@@@@@@@@@@@@@@@@@@


# calc cases per 1000, format end_date
heat_dat <- age_cases_clean %>% 
      left_join(ind_age_pop, by = "age_grp") %>% 
      arrange(end_date) %>% 
      mutate(prop_cases = (weekly_cases * 1000) / pop,
             end_date = factor(end_date, labels = format(unique(end_date), "%b %d"), ordered = TRUE))


# get data date and formate into "month day, year"
heat_bubble_data_date <- age_cases_clean %>% 
   filter(end_date == max(end_date)) %>% 
   mutate(date_text = format(end_date, "%B %d, %Y")) %>% 
   slice(n()) %>% 
   pull(date_text)


readr::write_rds(heat_dat, glue("{rprojroot::find_rstudio_root_file()}/data/age-cases-heat.rds"))
readr::write_rds(heat_bubble_data_date, glue("{rprojroot::find_rstudio_root_file()}/data/heat-bubble-data-date.rds"))



#@@@@@@@@@@@@@@@@@@@@@@@
# Age Deaths Line ----
#@@@@@@@@@@@@@@@@@@@@@@@


# cumulative deaths for each age group
ind_age_raw <- readr::read_csv(glue("{rprojroot::find_rstudio_root_file()}/data/ind-age-complete.csv"))


# df with the missing dates
missing_dates <- expand.grid(
   date = as.Date("2020-07-09") + c(1:10),
   agegrp = unique(ind_age_raw$agegrp),
   covid_deaths = NA
)

# add-in missing dates, wide format to run each age grp through imputation loop
ind_age_missing <- ind_age_raw %>% 
   select(date, agegrp, covid_deaths) %>% 
   bind_rows(missing_dates) %>%
   filter(agegrp != "Unknown") %>% 
   arrange(date) %>% 
   tidyr::pivot_wider(names_from = "agegrp",
                      values_from = "covid_deaths",
                      values_fill = NA)


# using Stineman interpolation; fewer negatives, patterns look reasonable; subsetting date var out
ind_age_imputed_st <- purrr::map_dfc(ind_age_missing[2:9], ~na_interpolation(.x, "stine") %>% round(., 0)) %>% 
   # calc daily deaths for each age group
   mutate_all(tsibble::difference) %>%
   # 1st row is NA after daily calc, so running it through imputation alg again
   purrr::map_dfc(., ~na_interpolation(.x, "stine") %>% round(., 0)) %>% 
   # add date var back
   bind_cols(ind_age_missing %>% select(date)) %>% 
   tidyr::pivot_longer(cols = -date,
                       names_to = "agegrp",
                       values_to = "covid_deaths")

# calc weekly totals for each age group
ind_age_clean <- ind_age_imputed_st %>% 
   mutate(week = lubridate::week(date)) %>% 
   group_by(week) %>% 
   mutate(end_date = last(date)) %>% 
   group_by(end_date, agegrp) %>% 
   summarize(weekly_total = sum(covid_deaths), .groups = "drop") %>% 
   # <age to age>, "80 and older" format
   mutate(weekly_total = ifelse(weekly_total < 0, 0, weekly_total),
          agegrp = stringr::str_replace(agegrp, "-", " to "),
          agegrp = stringr::str_replace(agegrp, "\\+", " and older"),
          date_text = format(end_date, "%B %d"),
          tooltip = glue("{date_text}
                         Deaths: {weekly_total}"))

line_data_date <- ind_age_clean %>% 
   filter(end_date == max(end_date)) %>% 
   slice_tail() %>% 
   pull(end_date)

readr::write_rds(ind_age_clean, glue("{rprojroot::find_rstudio_root_file()}/data/age-death-line.rds"))
readr::write_rds(line_data_date, glue("{rprojroot::find_rstudio_root_file()}/data/age-death-line-data-date.rds"))

