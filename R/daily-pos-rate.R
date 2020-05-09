

# Notes
# 1. Positive test rate as a spread indicator should be most informative when testing has leveled off, and it's value isn't mostly due to testing increases. For this reason I'm only including data at the daily testing peak and after, Apr 20th.




#########################
# Set-up
#########################


pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, glue, ggtext)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))

us_pos_rate <- readr::read_csv("https://covidtracking.com/api/v1/us/current.csv") %>% 
   select(lastModified, positive, totalTestResults) %>% 
   mutate(pos_rate = positive/totalTestResults,
          pos_rate_text = scales::percent(pos_rate, accuracy = 0.1)) %>% 
   pull(pos_rate_text)


# Indiana Data Hub
# state positives, deaths, tests counts
# Trys a sequence of dates, starting with today, and if the data download errors, it trys the previous day, and so on, until download succeeds.
c <- 0
while (TRUE) {
   try_result <- try({
      try_date <- lubridate::today() - c
      try_date_str <- try_date %>% 
         stringr::str_extract(pattern = "-[0-9]{2}-[0-9]{2}") %>% 
         stringr::str_remove_all(pattern = "-") %>% 
         stringr::str_remove(pattern = "^[0-9]")
      try_address <- glue::glue("https://hub.mph.in.gov/dataset/ab9d97ab-84e3-4c19-97f8-af045ee51882/resource/182b6742-edac-442d-8eeb-62f96b17773e/download/covid-19_statewidetestcasedeathtrends_{try_date_str}.xlsx")
      download.file(try_address, destfile = "data/test-case-trend.xlsx", mode = "wb")
   }, silent = TRUE)
   
   if (class(try_result) != "try-error"){
      break
   } else if (c >= 14) {
      stop("Uh, something's probably wrong with the Indiana Data Hub link. Might've changed the pattern.")
   } else {
      c <- c + 1
   }
}

# county data: same but only most recent cumulative counts
download.file("https://hub.mph.in.gov/dataset/89cfa2e3-3319-4d31-a60d-710f76856588/resource/8b8e6cd7-ede2-4c41-a9bd-4266df783145/download/covid_report_county.xlsx", destfile = "data/covid-county.xlsx", mode = "wb")


county_dat <- readxl::read_xlsx("data/covid-county.xlsx")

test_dat_raw <- readxl::read_xlsx("data/test-case-trend.xlsx")

# rename cols, make tsibble
test_dat <- test_dat_raw %>% 
      select(date = DATE,
             daily_tests = COVID_TEST,
             cum_tests = COVID_TEST_CUMSUM,
             cum_postives = COVID_COUNT_CUMSUM) %>%
      mutate(date = lubridate::ymd(date)) %>% 
      as_tsibble(index = date)



#############################
# Rate Without Cass County
#############################


# make sure both data sources have the same test total
test_dat_total <- test_dat %>% 
   filter(date == max(date)) %>% 
   pull(cum_tests)
county_dat_total <- county_dat %>% 
   summarize(test_total = sum(COVID_TEST)) %>% 
   pull(test_total)

if (test_dat_total == county_dat_total) {
   without_cass <- county_dat %>% 
      filter(COUNTY_NAME != "CASS") %>% 
      summarize(total_positives = sum(COVID_COUNT),
                total_tests = sum(COVID_TEST),
                pos_test_rate = total_positives/total_tests,
                pos_rate_text = scales::percent(pos_test_rate, accuracy = 0.1)) %>% 
      pull(pos_rate_text)
} else {
   without_cass <- NA
}



#######################
# Chart
#######################


# current date of data
data_date <- test_dat %>% 
      as_tibble() %>%
      summarize(date = max(date)) %>% 
      pull(date)

# 2020-04-20 was the testing peak after about a month (see Notes)
max_test_date <- test_dat %>% 
      filter(daily_tests == max(daily_tests)) %>% 
      pull(date)

chart_dat <- test_dat %>% 
      filter(date >= "2020-04-20") %>% 
      mutate(pos_test_rate = cum_postives/cum_tests)

# y-coord for geom_text
text_coord <- chart_dat %>% 
   filter(date == max(date)) %>% 
   pull(pos_test_rate)



rate_plot <- ggplot(data = chart_dat,
                    aes(x = date, y = pos_test_rate)) +
   geom_point(color = deep_rooted[[4]]) +
   geom_line(color = deep_rooted[[4]]) +
   scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
   scale_x_date(date_breaks = "4 days",
                date_labels = "%b %d") +
   ggrepel::geom_label_repel(data = chart_dat %>% 
                                filter(date == max(date)),
                             aes(label = scales::percent(pos_test_rate, accuracy = 0.1), size = 12),
                             nudge_x = -0.45, nudge_y = 0.002) +
   geom_text(data = data.frame(x = as.Date("2020-04-22"),
                               y = text_coord + 0.002,
                               label = glue("US Average: {us_pos_rate}")),
             mapping = aes(x = x, y = y,
                           label = label),
             size = 4.8, angle = 0L,
             lineheight = 1L, hjust = 0.5,
             vjust = 0.5, colour = "white",
             family = "Roboto", fontface = "plain",
             inherit.aes = FALSE, show.legend = FALSE) +
   geom_text(data = data.frame(x = as.Date("2020-04-22"),
                               y = text_coord + 0.004,
                               label = glue("
                                            Without Cass Co: {without_cass}")),
             mapping = aes(x = x, y = y,
                           label = label),
             size = 4.8, angle = 0L,
             lineheight = 1L, hjust = 0.5,
             vjust = 0.5, colour = "white",
             family = "Roboto", fontface = "plain",
             inherit.aes = FALSE, show.legend = FALSE) +
   labs(x = NULL, y = NULL,
        title = "Daily <b style='color:#B28330'>Positive Test</b> Rate",
        subtitle = glue("Last updated: {data_date}"),
        caption = "Sources: The Indiana Data Hub\nThe COVID Tracking Project") +
   theme(plot.title = element_textbox_simple(color = "white",
                                             family = "Roboto",
                                             size = 16),
         plot.subtitle = element_text(color = "white",
                                      family = "Roboto",
                                      size = 13),
         plot.caption = element_text(color = "white",
                                     size = 12),
         text = element_text(family = "Roboto"),
         legend.position = "none",
         axis.text.x = element_text(color = "white",
                                    size = 11),
         axis.text.y = element_text(color = "white",
                                    size = 11),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/pos-rate-line-{data_date}.png")
ggsave(plot_path, plot = rate_plot, dpi = "screen", width = 33, height = 20, units = "cm")



