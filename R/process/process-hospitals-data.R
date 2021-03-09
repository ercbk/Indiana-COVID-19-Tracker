# CDC Hospital data processing



# Set-up ----

options(scipen = 999)


pacman::p_load(e1071, dplyr, glue, rvest, imputeTS)

cdc_hosp_url <- read_html("https://healthdata.gov/dataset/covid-19-reported-patient-impact-and-hospital-capacity-facility") %>%
      html_node(css = "#data-and-resources > div > div > ul > li > div > span > a") %>%
      html_attr("href")

cdc_staff_url <- read_html("https://healthdata.gov/dataset/covid-19-reported-patient-impact-and-hospital-capacity-state-timeseries") %>%
      html_node(css = "#data-and-resources > div > div > ul > li > div > span > a.btn.btn-primary.data-link") %>%
      html_attr("href")

# cdc_staff_url <- "https://beta.healthdata.gov/api/views/g62h-syeh/rows.csv?accessType=DOWNLOAD"
# cdc_hosp_url <- "https://beta.healthdata.gov/api/views/anag-cw7u/rows.csv?accessType=DOWNLOAD"

# historic staffing shortages
cdc_staff_raw <- readr::read_csv(cdc_staff_url)
# historic occupancy
cdc_hosp_raw <- readr::read_csv(cdc_hosp_url)

# regenstrief hospital mortality data
ind_mort_raw <- readr::read_rds(glue("{rprojroot::find_rstudio_root_file()}/data/mort-hosp-line.rds"))
# regenstrief hospital admissions by age data
hosp_age_raw <- readr::read_rds(glue("{rprojroot::find_rstudio_root_file()}/data/age-hosp-line.rds"))

# US county-city info
ind_county_city <- readr::read_csv(glue("{rprojroot::find_rstudio_root_file()}/data/uscities.csv")) %>% 
   filter(state_id == "IN") %>% 
   mutate(city = stringr::str_replace_all(city, "\\.", "")) %>% 
   select(city, county_name)



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# 1 Local Hospital Occupancy ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


hosp_vars <- c("collection_week", "state", "hospital_name", "address", "city",
               "zip", "fips_code", 
               "total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg",
               "all_adult_hospital_inpatient_beds_7_day_avg",
               "staffed_adult_icu_bed_occupancy_7_day_avg",
               "total_staffed_adult_icu_beds_7_day_avg",
               "staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg",
               "all_adult_hospital_inpatient_bed_occupied_7_day_avg")



#@@@@@@@@@@@@@@@@@@@@@@@@@@
# ** General Cleaning ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@

ind_hosp_clean <- cdc_hosp_raw %>%
   select(all_of(hosp_vars)) %>% 
   filter(state == "IN") %>% 
   mutate_at(vars(hospital_name:city), stringr::str_to_title) %>% 
   mutate(temp_city = paste0(city, ","),
          city_zip = paste(temp_city, state, zip),
          # typos
          hospital_name = case_when(hospital_name == "The Orthopaedic Hospital Of Lutheran Health Networ" ~
                                       "The Orthopedic Hospital Of Lutheran Health Network",
                                    hospital_name == "Women's Hospital The" ~ "The Women's Hospital" ,
                                    TRUE ~ hospital_name
          ),
          hospital_name = stringr::str_replace_all(hospital_name, "Iu ", "IU "), 
          hospital_name = stringr::str_replace_all(hospital_name, " Llc", " LLC"),
          # collection_week = lubridate::mdy_hms(collection_week),
          # collection_week = lubridate::as_date(collection_week),
          # collection_week is the start day and I prefer the end day
          collection_week = collection_week + 6) %>% 
   select(-temp_city) %>% 
   left_join(ind_county_city, by = "city") %>% 
   # sparklines don't print if data has any NAs, so coding as zeros
   mutate_if(is.numeric, ~replace(., is.na(.), 0)) %>%  
   arrange(collection_week)



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# ** Process Heatmap Columns ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# -999999 is code for the value being less than 4.
# Those values are changed to a reasonable value (2.0001) for calculation purposes
react_dd_heat <- ind_hosp_clean %>% 
   select(end_date = collection_week, hospital_name, address, city_zip, county_name,
          staffed_adult_icu_bed_occupancy_7_day_avg,
          total_staffed_adult_icu_beds_7_day_avg,
          all_adult_hospital_inpatient_bed_occupied_7_day_avg,
          all_adult_hospital_inpatient_beds_7_day_avg) %>% 
   
   # heatmap 1
   # Calc percent staffed adult ICU beds occupied (including COVID and non-COVID ICU usage)
   # if both values are 2.0001 then coded NA and hospital cell is black instead of part of heatmap
   mutate(staffed_adult_icu_bed_occupancy_7_day_avg_adj = ifelse(staffed_adult_icu_bed_occupancy_7_day_avg == -999999.0 |
                                                                    staffed_adult_icu_bed_occupancy_7_day_avg == -999999,
                                                                 2.0001,
                                                                 staffed_adult_icu_bed_occupancy_7_day_avg),
          total_staffed_adult_icu_beds_7_day_avg_adj = ifelse(total_staffed_adult_icu_beds_7_day_avg == -999999.0 |
                                                                 total_staffed_adult_icu_beds_7_day_avg == -999999,
                                                              2.0001,
                                                              total_staffed_adult_icu_beds_7_day_avg),
          sev_day_icu_perc_occup = ifelse(staffed_adult_icu_bed_occupancy_7_day_avg_adj == 2.0001 &
                                             total_staffed_adult_icu_beds_7_day_avg_adj == 2.0001,
                                          NA,
                                          staffed_adult_icu_bed_occupancy_7_day_avg_adj / 
                                             total_staffed_adult_icu_beds_7_day_avg_adj),
          # some hospitals are entering incorrect data, causing percents to be > 100%, they don't get a heat-cell
          sev_day_icu_perc_occup = ifelse(sev_day_icu_perc_occup >= 1, NA, sev_day_icu_perc_occup)) %>% 
   
   # heatmap 2
   # Calc percent staffed adult beds occupied (including ICU, covid, and non-covid)
   # if both values are 2.0001 then coded NA and hospital cell is black instead of part of heatmap
   mutate(all_adult_hospital_inpatient_bed_occupied_7_day_avg_adj = ifelse(all_adult_hospital_inpatient_bed_occupied_7_day_avg == -999999.0 |
                                                                              all_adult_hospital_inpatient_bed_occupied_7_day_avg == -999999,
                                                                           2.0001,
                                                                           all_adult_hospital_inpatient_bed_occupied_7_day_avg),
          all_adult_hospital_inpatient_beds_7_day_avg_adj = ifelse(all_adult_hospital_inpatient_beds_7_day_avg == -999999.0 |
                                                                      all_adult_hospital_inpatient_beds_7_day_avg == 999999,
                                                                   2.0001,
                                                                   all_adult_hospital_inpatient_beds_7_day_avg),
          sev_day_hosp_perc_occup = ifelse(all_adult_hospital_inpatient_bed_occupied_7_day_avg_adj == 2.0001 &
                                              all_adult_hospital_inpatient_beds_7_day_avg_adj == 2.0001,
                                           NA,
                                           all_adult_hospital_inpatient_bed_occupied_7_day_avg_adj /
                                              all_adult_hospital_inpatient_beds_7_day_avg_adj),
          # some hospitals are entering incorrect data, causing percents to be > 100%
          sev_day_hosp_perc_occup = ifelse(sev_day_hosp_perc_occup >= 1, NA, sev_day_hosp_perc_occup)) %>% 
   select(end_date:county_name, sev_day_icu_perc_occup, sev_day_hosp_perc_occup) %>% 
   group_by(hospital_name) %>%
   filter(end_date == max(end_date))



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# ** Process Sparkline Columns ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# divided city population by number of hospitals in that city
# median of adjusted population is 13736.75, so I'll use a "per 10K" transformation below.
# adj_pop_tbl <- ind_hosp_clean %>% 
#       distinct(hospital_name, city) %>% 
#       count(city, sort = TRUE) %>% 
#       mutate(pop_wt = 1 / n) %>% 
#       select(city, pop_wt) %>% 
#       left_join(ind_hosp_clean %>% 
#                       distinct(city, population), by = "city") %>% 
#       mutate(adj_pop = population * pop_wt) %>% 
#       select(city, adj_pop)


## *** 7-day avg covid hospitalized per 10K ----
# avgCovHospTenKList list column = list(list(endDate=end_date_1, avgCovHospTenK = avg_covid_hosp_10k_1), list(endDate=end_date_2, avgCovHospTenK=avg_covid_hosp_10k_2), ...) for each MSA
# required format for arrays in javascript
avg_covid_hosp_hist <- ind_hosp_clean %>% 
   select(end_date = collection_week, hospital_name, city,
          total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg) %>% 
   # left_join(adj_pop_tbl, by = "city") %>% 
   
   # change -999999 to 2.0001. (see react_dd_heat for explanation)
   mutate(total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg_adj =
             ifelse(total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg == -999999.0 |
                       total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg == -999999,
                    2.0001,
                    total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg),
          # indicator for whether value is missing/unknown
          miss_unk_ind = ifelse(total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg_adj == 2.0001 | total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg_adj == 0,
                                1, 0)) %>% 
   
   # Calc proportion of 0s (missing) and 2.0001s (unknowns) for each hospital
   add_count(hospital_name, miss_unk_ind, name = "n_unk_miss") %>% 
   add_count(hospital_name, name = "n_obs") %>% 
   mutate(unk_miss_prop = n_unk_miss / n_obs) %>%
   
   # calc 7-day avg covid hospitalized per 10K
   # If proportion of 2.0001s or 0s > 80%, then coded NA and hospital doesn't get a sparkline
   mutate(avg_covid_hosp_10k = ifelse((total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg_adj == 2.0001 & unk_miss_prop > 0.80) |
                                         (total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg_adj == 0 & unk_miss_prop > 0.80),
                                      NA,
                                      total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg_adj)) %>% 
   # mutate(avg_covid_hosp_10k = ifelse(unk_miss_prop > 0.80,
   #                                   NA,
   #                                   (10000*total_adult_patients_hospitalized_confirmed_and_suspected_covid_7_day_avg_adj) / adj_pop)) %>% 
   select(end_date, hospital_name, avg_covid_hosp_10k) %>%
   
   # wrangle data to js preferred format
   group_by(hospital_name) %>%
   summarize(avg_covid_hosp_10k_list = mapply(function (end_date, avg_covid_hosp_10k)
   {list(endDate = end_date, avgCovHospTenK = avg_covid_hosp_10k)},
   end_date, avg_covid_hosp_10k,
   SIMPLIFY = FALSE)) %>% 
   tidyr::nest() %>%
   mutate(data = purrr::map(data, ~as.list(.x))) %>%
   rename(avgCovHospTenKList = data)


## *** 7-day avg covid ICU per 10K ----
avg_covid_icu_hist <- ind_hosp_clean %>% 
   select(end_date = collection_week, hospital_name, city,
          staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg) %>% 
   # left_join(adj_pop_tbl, by = "city") %>% 
   
   # change -999999 to 2.0001. (see react_dd_heat for explanation)
   mutate(staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg_adj =
             ifelse(staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg == -999999.0 |
                       staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg == -999999,
                    2.0001,
                    staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg),
          # indicator for whether value is missing/unknown
          miss_unk_ind = ifelse(staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg_adj == 2.0001 | staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg_adj == 0,
                                1, 0)) %>% 
   
   # Calc proportion of 0s (missing) and 2.0001s (unknowns) for each hospital
   add_count(hospital_name, name = "n_obs") %>%
   add_count(hospital_name, miss_unk_ind, name = "n_unk_miss") %>% 
   mutate(unk_miss_prop = n_unk_miss / n_obs) %>% 
   
   # Calc 7-day avg covid hospitalized per 10K
   # If proportion of 2.0001s or 0s > 80%, then coded NA and hospital doesn't get a sparkline
   mutate(avg_covid_icu_10k = ifelse((staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg_adj == 2.0001 & unk_miss_prop > 0.80) |
                                        (staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg_adj == 0 & unk_miss_prop > 0.80),
                                     NA,
                                     staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg_adj)) %>% 
   # mutate(avg_covid_icu_10k = ifelse(unk_miss_prop > 0.80,
   #                                   NA,
   #                                   (10000*staffed_icu_adult_patients_confirmed_and_suspected_covid_7_day_avg_adj) / adj_pop)) %>% 
   select(end_date, hospital_name, avg_covid_icu_10k) %>%
   
   # wrangle data to js preferred format
   group_by(hospital_name) %>%
   summarize(avg_covid_icu_10k_list = mapply(function (end_date, avg_covid_icu_10k)
   {list(endDate = end_date, avgCovIcuTenK = avg_covid_icu_10k)},
   end_date, avg_covid_icu_10k,
   SIMPLIFY = FALSE)) %>% 
   tidyr::nest() %>%
   mutate(data = purrr::map(data, ~as.list(.x))) %>%
   rename(avgCovIcuTenKList = data)

## *** 7-day avg of staffed total beds available (didn't get used in react tbl) ----
avg_total_inpat_beds_hist <- ind_hosp_clean %>% 
   select(end_date = collection_week, hospital_name, city,
          all_adult_hospital_inpatient_beds_7_day_avg) %>% 
   
   # change -999999 to 2.0001. (see react_dd_heat for explanation)
   mutate(avg_total_inpat_beds =
             ifelse(all_adult_hospital_inpatient_beds_7_day_avg == -999999.0 |
                       all_adult_hospital_inpatient_beds_7_day_avg == -999999,
                    2.0001,
                    all_adult_hospital_inpatient_beds_7_day_avg),
          # indicator for whether value is missing/unknown
          miss_unk_ind = ifelse(avg_total_inpat_beds == 2.0001 | avg_total_inpat_beds == 0,
                                1, 0)) %>% 
   
   # Calc proportion of 0s (missing) and 2.0001s (unknowns) for each hospital
   # add_count(hospital_name, avg_total_inpat_beds, name = "n_val_types") %>%
   add_count(hospital_name, miss_unk_ind, name = "n_unk_miss") %>%
   add_count(hospital_name, name = "n_obs") %>% 
   mutate(unk_miss_prop = n_unk_miss / n_obs) %>%
   
   # If proportion of 2.0001s or 0s > 80%, then coded NA and hospital doesn't get a sparkline
   mutate(avg_total_inpat_beds = ifelse((avg_total_inpat_beds == 2.0001 & unk_miss_prop > 0.80) |
                                           (avg_total_inpat_beds == 0 & unk_miss_prop > 0.80),
                                        NA,
                                        avg_total_inpat_beds)) %>% 
   select(end_date, hospital_name, avg_total_inpat_beds) %>%
   
   # wrangle data to js preferred format
   group_by(hospital_name) %>%
   summarize(avg_total_impat_beds_list = mapply(function (end_date, avg_total_inpat_beds)
   {list(endDate = end_date, avgTotImpBeds = avg_total_inpat_beds)},
   end_date, avg_total_inpat_beds,
   SIMPLIFY = FALSE)) %>% 
   tidyr::nest() %>%
   mutate(data = purrr::map(data, ~as.list(.x))) %>%
   rename(avgTotImpBedsList = data)



# ** Combine and save ----

react_tbl_list <- list(react_dd_heat, avg_covid_icu_hist, avg_covid_hosp_hist, avg_total_inpat_beds_hist)

react_tab_final <- purrr::reduce(react_tbl_list, left_join, by = "hospital_name") %>% 
   ungroup()

readr::write_rds(react_tab_final, glue("{rprojroot::find_rstudio_root_file()}/data/hosp-react-tab.rds"))




#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# 2 State Mortality, Staffing, Admissions ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# ** Hospital Staffing Shortages ----

staff_vars <- c("state", "date",
                "critical_staffing_shortage_today_yes", "critical_staffing_shortage_today_no",
                "critical_staffing_shortage_today_not_reported")

# Rolling 7-day avg of daily shortages
ind_staff_clean <- cdc_staff_raw %>% 
   select(any_of(staff_vars)) %>% 
   filter(state == "IN") %>% 
   # mutate(date = lubridate::mdy_hms(date),
   #        date = lubridate::as_date(date)) %>% 
   arrange(date) %>% 
   mutate(staff_short_perc = critical_staffing_shortage_today_yes /
             (critical_staffing_shortage_today_yes + critical_staffing_shortage_today_no),
          # rolling 7-day avg staff shortage percentage
          roll_mean_staff_short_perc = slider::slide_dbl(staff_short_perc, .f = mean, .before = 6))



# ** Hospital Mortality Rate ----

# scraping regenstreif tableau dashboard isn't producing regular intervals of data, so need to fill the days in-between
ind_mort_filled <- ind_mort_raw %>% 
   tsibble::as_tsibble() %>% 
   tsibble::fill_gaps()


# calc avg daily hosp mort rate
# impute missing values deaths
rolling_mort_admiss <- purrr::map_dfc(ind_mort_filled[1:3], ~na_interpolation(.x, "stine")) %>%
   mutate(deaths_total = round(deaths_total, 0),
          admiss_total = round(hosp_total, 0),
          daily_deaths = tsibble::difference(deaths_total),
          daily_admiss = tsibble::difference(admiss_total),
          roll_sum_deaths = slider::slide_dbl(daily_deaths, .f = sum, .before = 13),
          roll_sum_admiss = slider::slide_dbl(daily_admiss, .f = sum, .before = 13),
          roll_mean_admiss = slider::slide_dbl(daily_admiss, .f = mean, .before = 6),
          # calc hosp mort rate
          mean_mort_rate = roll_sum_deaths / roll_sum_admiss)



# ** Age Skewness of Hospital Admissions ----

hosp_age_daily <- hosp_age_raw %>% 
   arrange(desc(date)) %>% 
   tsibble::as_tsibble(index = date, key = ages) %>% 
   group_by(ages) %>% 
   # calc daily admissions by age grp
   mutate(adm_tot_daily = tsibble::difference(admissions_total),
          adm_tot_daily = ifelse(adm_tot_daily < 0 , 0, adm_tot_daily),
          ages = ifelse(ages == "5-19", "05-19", ages)) %>% 
   select(date, ages, adm_tot_daily) %>% 
   # fill-in missing days
   tsibble::fill_gaps() %>% 
   purrr::map_dfc(., ~na_interpolation(.x, "stine")) %>% 
   # need to re-group after ~na_interpolation
   group_by(ages) %>% 
   # calc rolling 14 day sums by age grp
   mutate(adm_tot_daily = round(adm_tot_daily, 0),
          # .complete = T says no partial calcs --> NAs created
          roll_sum_adm = slider::slide_dbl(adm_tot_daily, .f = sum, .before = 13, .complete = TRUE)) %>% 
   tidyr::drop_na() %>% 
   select(-adm_tot_daily) %>% 
   ungroup()

# to calc skewness I need to de-aggregate admissions for each age group into one long numeric vector.
# Each element is a single admission. If age = 20-29 had 5 admissions --> c(20-29,20-29,20-29,20-29,20-29)
hosp_age_skew <- hosp_age_daily %>%
   mutate(ages = factor(ages, ordered = TRUE),
          # skewness fun requires the vec to be numeric
          ages_num = as.numeric(ages)) %>% 
   group_by(date) %>% 
   # nest data to calc skewness for each date
   tidyr::nest(data = c(ages, ages_num, roll_sum_adm)) %>% 
   mutate(data = purrr::map(data, function(dat) {
      rep_ages <- dat %>% 
         group_by(ages) %>%
         # create long vec for each age group
         summarize(age_list = mapply(function (x, y)
         {rep(x, y)},
         ages_num, roll_sum_adm),
         .groups = "drop")
      # combine all age long vectors into 1 long vector
      ages_vec <- purrr::reduce(rep_ages$age_list, .f = c)
      # calc skewness; type 3 alg by default
      ages_skewness <- e1071::skewness(ages_vec)
      return(ages_skewness)
   })) %>% 
   tidyr::unnest(cols = data) %>% 
   rename(skewness = data) %>% 
   # transforming it to a positive number so it's easier for the normals to interpret.
   mutate(skewness = -1 * skewness)


# ** Combine and Save ----

mort_staff_admiss_dat <- ind_staff_clean %>% 
   select(date, roll_mean_staff_short_perc) %>% 
   inner_join(rolling_mort_admiss %>% 
                 select(date, mean_mort_rate, roll_mean_admiss), by = "date") %>% 
   tidyr::drop_na() %>% 
   inner_join(hosp_age_skew, by = "date") %>% 
   mutate(# highcharter doesn't handle date class but ordered factor works
      date = factor(date, labels = format(unique(date), "%b %d"), ordered = TRUE))



readr::write_rds(mort_staff_admiss_dat, glue("{rprojroot::find_rstudio_root_file()}/data/hosp-msas-line.rds"))



