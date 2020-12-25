

# Notes
# 1. Box and Holcomb have stated they're using a seven-day data sample to calc their positive test rate, so that's what I'm using.
# 2. Data is contiually being collected. This incompleteness makes for some pretty large and misleading positivity rates. Even though there is enough data to calculate the rates for the last couple days, I'm not including them. The rates from 3 or more days prior continue to change but are much more stable than the most recent couple rates.



#########################
# Set-up
#########################


pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, glue, ggtext)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))

us_pos_rate <- readr::read_csv("https://covidtracking.com/api/v1/us/daily.csv") %>% 
   select(date, positiveIncrease, totalTestResultsIncrease) %>% 
   arrange(date) %>% 
   # .before = 2 says take the current value and the 2 before it.
   mutate(pos_rate = slider::slide2_dbl(positiveIncrease, totalTestResultsIncrease,
                                        ~sum(.x)/sum(.y), .before = 6),
          pos_rate_text = scales::percent(pos_rate, accuracy = 0.1)) %>% 
   slice(n()) %>% 
   pull(pos_rate_text)



# Indiana Data Hub
# state positives, deaths, tests counts
hub_dat_url <- "https://hub.mph.in.gov/dataset/bd08cdd3-9ab1-4d70-b933-41f9ef7b809d/resource/afaa225d-ac4e-4e80-9190-f6800c366b58/download/covid_report_county_date.xlsx"

download.file(hub_dat_url, destfile = "data/county-test-case-trend.xlsx", mode = "wb")
test_dat_raw <- readxl::read_xlsx("data/county-test-case-trend.xlsx")


# rename cols, make tsibble, calc 7-day moving positive rate
test_dat <- test_dat_raw %>% 
   select(date = DATE,
          county_daily_tests = COVID_TESTS_ADMINISTRATED,
          county_daily_positives = COVID_COUNT) %>%
   mutate(date = lubridate::ymd(date)) %>% 
   group_by(date) %>% 
   summarize(daily_tests = sum(county_daily_tests),
             daily_positives = sum(county_daily_positives),
             .groups = "drop") %>%
   mutate(pos_test_rate = slider::slide2_dbl(daily_positives, daily_tests,
                                             ~sum(.x)/sum(.y), .before = 6)) %>% 
   as_tsibble(index = date) %>% 
   # removing the last couple rows. Not enough data makes them misleading
   slice(-(n()-1):-n())





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
   filter(date >= "2020-04-20")

# y-coord for geom_text
text_coord <- chart_dat %>% 
   filter(date == max(date) | date == "2020-04-26") %>%
   transmute(max_pos_rate = ifelse(pos_test_rate[[1]] < pos_test_rate[[2]], pos_test_rate[[2]], pos_test_rate[[1]])) %>% 
   slice(1) %>% 
   pull(max_pos_rate)



rate_plot <- ggplot(data = chart_dat,
                    aes(x = date, y = pos_test_rate)) +
   geom_point(color = deep_rooted[[4]]) +
   geom_line(color = deep_rooted[[4]]) +
   expand_limits(y = c(0, max(chart_dat$pos_test_rate) + 0.05)) +
   geom_ribbon(aes(ymin = 0.00, ymax = 0.05), fill = "#8db230", alpha = 0.2) +
   scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
   scale_x_date(date_breaks = "14 days",
                date_labels = "%b %d") +
   ggrepel::geom_label_repel(data = chart_dat %>% 
                                filter(date == max(date)),
                             aes(label = scales::percent(pos_test_rate, accuracy = 0.1), size = 12),
                             # "lines" = lines of text
                             nudge_x = -0.45, nudge_y = 0.002, point.padding = unit(1.5, "lines"),
                             direction = "y") +
   geom_text(data = data.frame(x = as.Date("2020-04-27"),
                               y = text_coord + 0.03,
                               label = glue("US Average: {us_pos_rate}")),
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



