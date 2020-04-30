# Covid Deaths Pyramid Plot

pacman::p_load(dplyr, readxl, purrr)

case_dat <- readr::read_csv("https://hub.mph.in.gov/dataset/6b57a4f2-b754-4f79-a46b-cff93e37d851/resource/46b310b9-2f29-4a51-90dc-3886d9cf4ac1/download/covid_report_stratified_20200429.csv")

download.file("https://hub.mph.in.gov/dataset/62ddcb15-bbe8-477b-bb2e-175ee5af8629/resource/2538d7f1-391b-4733-90b3-9e95cd5f3ea6/download/covid_report_demographics_429.xlsx", destfile = "data/ind-demographic-data.xlsx", mode = "wb")

download.file("https://hub.mph.in.gov/dataset/ab9d97ab-84e3-4c19-97f8-af045ee51882/resource/182b6742-edac-442d-8eeb-62f96b17773e/download/covid-19_statewidetestcasedeathtrends_429.xlsx", destfile = "data/test-case-trend.xlsx", mode = "wb")
download.file("https://hub.mph.in.gov/dataset/89cfa2e3-3319-4d31-a60d-710f76856588/resource/8b8e6cd7-ede2-4c41-a9bd-4266df783145/download/covid_report_county.xlsx", destfile = "data/covid-county.xlsx", mode = "wb")
download.file("https://hub.mph.in.gov/dataset/5a905d51-eb50-4a83-8f79-005239bd108b/resource/882a7426-886f-48cc-bbe0-a8d14e3012e4/download/covid_report_bedvent_429.xlsx", destfile = "data/beds-vent.xlsx", mode = "wb")

path <- "data/ind-demographic-data.xlsx"
dem_sheets <- path %>%
      excel_sheets() %>%
      set_names() %>%
      map(read_excel, path = path)


county_dat <- readxl::read_xlsx("data/covid-county.xlsx")

trend_dat <- readxl::read_xlsx("data/test-case-trend.xlsx")

bv_dat <- readxl::read_xlsx("data/beds-vent.xlsx")

