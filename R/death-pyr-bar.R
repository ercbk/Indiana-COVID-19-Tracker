# Covid Deaths Pyramid Plot

pacman::p_load(dplyr, readxl, purrr, tidycensus)

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

# Just copied these from the Indiana State Health Dep dashboard
# They say they got them from a 2019 US Census report
race_pct <- tibble::tribble(
                                        ~Race, ~`%.of.Indiana.population`,
                                      "White",        85.1,
                  "Black or African American",        9.8,
                                 "Other Race",        2.6,
                                      "Asian",        2.5,
                                    "Unknown",        0
                  )
ethn_pct <- tibble::tribble(
                                ~Ethnicity, ~`%.of.Indiana.population`,
                  "Not Hispanic or Latino",        92.9,
                      "Hispanic or Latino",        7.1,
                                 "Unknown",        0
                  )

race_dat <- race_pct %>% 
      left_join(dem_sheets$Race, by = c("Race" = "RACE"))

ethn_dat <- ethn_pct %>% 
      left_join(dem_sheets$Ethnicity, by = c("Ethnicity" = "ETHNICITY"))


# 2018 is latest data available by tidycensus currently
census_dat_raw <- get_estimates(
      geography = "state",
      product = "characteristics",
      breakdown = c("SEX", "AGEGROUP"),
      breakdown_labels = TRUE,
      state = "IN",
      year = 2018
)

# removes some extraneous words in age group names
census_dat <- census_dat_raw %>% 
      slice(-58:-96) %>% 
      filter(SEX != "Both sexes",
             AGEGROUP != "All ages") %>% 
      mutate(AGEGROUP = stringr::str_remove(AGEGROUP,
                                            pattern = "Age ") %>% 
                   stringr::str_remove(., pattern = " years"))



# combine census 5 yr age groups into 10 yr age groups to match indy health data
slice_seqs <- list(seq(1:8), seq(9:12), seq(13:16),
               seq(17:20), seq(21:24), seq(25:28),
               seq(29:32), seq(33:36))
new_groups <- c("0 to 19", "20 to 29", "30 to 39",
               "40 to 49", "50 to 59", "60 to 69",
               "70 to 79", "80 and over")

# subsets rows needed for new age grouping, groups tibbles by sex, sums-up the population count
create_age_groups <- function(rows, ages) {
      census_dat %>% 
            select(value, SEX, AGEGROUP) %>% 
            slice(rows) %>% 
            group_by(SEX) %>% 
            tidyr::nest() %>% 
            mutate(data = map(data, ~summarize(.x,
                                               AGEGROUP = ages,
                                               value = sum(value)
            )
            )) %>% 
            tidyr::unnest(cols = c(data))
}


# cols: sex, agegroup, value (count)
clean_age_groups <- map2_dfr(slice_seqs, new_groups, create_age_groups)











# pyr_plot <- ggplot() +
#    geom_bar(data = pop_data %>% filter(Group == "jeff"),
#             aes(x = Age, y = Proportion, fill = Group),
#             width = .77,
#             stat = "identity",
#             position = "identity"
#    ) +
#    geom_bar(data = pop_data %>% filter(Group == "lmdc"),
#             aes(x = Age, y = Proportion, fill = Group),
#             width = 0.4,
#             stat = "identity",
#             position = "identity"
#    ) +
#    coord_flip() +
#    # think abs is just the absolute value function
#    scale_y_continuous(labels = abs) +
#    geom_hline(yintercept = 0) +
#    facet_wrap(.~Race, scales = "free") +
#    theme_minimal(base_family = "Roboto") +
#    theme(legend.position = c(0.89, 0.25), axis.text = element_text(face = "bold")) +
#    scale_fill_manual(values = c("gray", "darkred"), labels = c("Jefferson County", "LMDC")) +
#    ylab("Male | Female (%)") +
#    labs(title = "Demographic comparision between Jefferson County and Louisville Metro Correctional populations",
#         subtitle = "2015",
#         fill = "",
#         caption = "Source: Louisville Metro Government Open Data. Daily LMDC Population Snapshots. 2019\nSource: US Census Bureau population estimates & tidycensus R package"
#    )

      
# comp - #4fbe45
# split.comp  - #45beaa, #8cbe45
# tri - #4559be, #beba45 
# quad - comp, #4559be, #be7e45