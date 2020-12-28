# Monitors number of hospitalizations, availabilty of icu beds and ventilators


# Notes
# 1. The "triggers" are benchmarks for hospitalizations, icu beds, and ventilators that I'm monitoring. Discussed further in the readme.


# Sections
# 1. Set-up
# 2. hospitalizations: clean, calculate trigger
# 3. Hospitalizations chart
# 4. ICU, Vents: clean, calculate triggers
# 5. Gauge Plots
# 6. Trigger Plot
# 7. Combine all charts





# Set-up ----



pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, glue, patchwork, ggtext)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
purp_haz <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Purple Haze.ase"))
light_haz <- prismatic::clr_lighten(purp_haz, shift = 0.25)

# hospitalizations data
ct_dat_raw <- readr::read_csv("https://covidtracking.com/api/v1/states/daily.csv")
# beds, ventilators data
iv_dat_raw <- readr::read_csv(glue("{rprojroot::find_rstudio_root_file()}/data/beds-vents-complete.csv"))



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# 1 hospitalizations: clean, calculate trigger ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# Get Indiana, cols = date, hospitalizedCurrently
ind_hosp <- ct_dat_raw %>% 
  filter(state == "IN" & hospitalizedCurrently != "NA") %>% 
  select(date, hospitalizedCurrently) %>% 
  mutate(date = lubridate::ymd(date)) %>%
  as_tsibble(index = date)

# current date of data
data_date <- ind_hosp %>% 
  as_tibble() %>%
  summarize(date = max(date)) %>% 
  pull(date)

# calc difference between one day and the previous day
hosp_changes <- ind_hosp %>% 
  as_tibble() %>% 
  mutate(hosp_diff = difference(hospitalizedCurrently)) %>% 
  arrange(desc(date)) %>% 
  pull(hosp_diff)

# calculate how many consecutive days of increasing/decreasing daily cases
count_consec_days <- function(x) {
  # rle: "run length encoding," counts runs of same value
  hosp_runs <- rle(sign(x))
  consec_days <- tibble(
    num_days = hosp_runs$lengths,
    sign = hosp_runs$values
  ) %>% 
    mutate(trend = case_when(sign == 1 ~ "increased",
                             sign == -1 ~ "decreased",
                             TRUE ~ "No change in")) %>% 
    slice(1) %>% 
    select(-sign)
}

consec_days <- count_consec_days(hosp_changes)



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# 2 Hospitalizations chart ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# Trigger
# text styled depending on number of consecutive days and increasing or decreasing trend

# 1 day of decreased hospitalizations
neg_one <- glue("<b style='color: #33a532'>{consec_days$num_days[[1]]}</b> day of {consec_days$trend[[1]]} COVID-19 hospitializations")
# 1 day of increased hospitalizations
pos_one <- glue("<b style='color: #cf142b'>{consec_days$num_days[[1]]}</b> day of {consec_days$trend[[1]]} COVID-19 hospitializations")
# no change from yesterday
zero_days <- glue("{consec_days$trend[[1]]} COVID-19 hospitializations")
# between 2 and 6 days of increased hospitalizations
under_ft <- glue("<b style='color: #cf142b'>{consec_days$num_days[[1]]}</b> consecutive days of {consec_days$trend[[1]]} COVID-19 hospitializations")
# more than threshold of 14 days of increased hospitalizations
ft_over <- glue("<b style='color: #cf142b'>{consec_days$num_days[[1]]}</b> consecutive days of {consec_days$trend[[1]]} COVID-19 hospitializations <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #cf142b'>&#xf06A;</span>")
# between 7 and 13 days of increased hospitalizations
ft_over_sev <- glue("<b style='color: #cf142b'>{consec_days$num_days[[1]]}</b> consecutive days of {consec_days$trend[[1]]} COVID-19 hospitializations <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #ffae42'>&#xf071;</span>")
# more than 1 day of decreased hospitalizations
under_neg_one <- glue("<b style='color: #33a532'>{consec_days$num_days[[1]]}</b> consecutive days of {consec_days$trend[[1]]} COVID-19 hospitalizations")

# choose the subtitle text based number of consecutive days and trend light_haz[[2]]
trigger_dat_h <- consec_days %>% 
  mutate(text = case_when(num_days == 1 & trend == "increased" ~
                            pos_one,
                          num_days == 1 & trend == "decreased" ~
                            neg_one,
                          between(num_days, 2, 6) & trend == "increased" ~
                            under_ft,
                          between(num_days, 7, 13) & trend == "increased" ~
                            ft_over_sev,
                          num_days >= 14 & trend == "increased" ~
                            ft_over,
                          num_days > 1 & trend == "decreased" ~
                            under_neg_one,
                          TRUE ~ zero_days),
         type = "hosp")


caption_text <- glue("Last updated: {data_date}
                     Source: The COVID Tracking Project")

hosp_plot <- ggplot(data = ind_hosp,
                    aes(x = date, y = hospitalizedCurrently)) +
  geom_point(color = "#32a5a3") +
  geom_line(color = "#32a5a3") +
  expand_limits(y = c(min(ind_hosp$hospitalizedCurrently)-60, max(ind_hosp$hospitalizedCurrently) + 60),
                x = max(ind_hosp$date) + 8) +
  scale_x_date(date_breaks = "1 month",
               date_labels = "%b") +
  ggrepel::geom_label_repel(data = ind_hosp %>%
                              filter(date == max(date)),
                            aes(label = hospitalizedCurrently, size = 12),
                            nudge_x = 0, nudge_y = 18, point.padding = 1,
                            direction = "x", seed = 125) +
  geom_label(aes(x = as.Date("2020-04-24"),
                 y = max(hospitalizedCurrently) + 60,
                 label="Current COVID-19 Hospitalizations"),
             family="Roboto", fill = "black",
             size = 5, hjust = 0,
             label.size = 0, color = "white") +
  labs(x = NULL, y = NULL) +
  theme(text = element_text(family = "Roboto"),
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




#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# 3 ICU, Vents: clean, calculate triggers ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# calcs percentages, assigns 1 for above threshold, -1 for below (needed for sign() fun below)
iv_dat <- iv_dat_raw %>%
  mutate(icu_beds_pct = beds_available_icu_beds_total/beds_icu_total,
         vent_pct = vents_all_available_vents_not_in_use/vents_total,
         icu_status = ifelse(icu_beds_pct >= 0.400, 1, -1),
         vent_status = ifelse(vent_pct >= 0.700, 1, -1)) %>% 
  arrange(desc(date))

# count consecutive days above and below threshold
count_consec_days_iv <- function(x) {
  # rle: "run length encoding," counts runs of same value
  iv_runs <- rle(sign(x))
  consec_days <- tibble(
    num_days = iv_runs$lengths,
    sign = iv_runs$values
  ) %>% 
    mutate(trend = case_when(sign == 1 ~ "above",
                             sign == -1 ~ "below",
                             TRUE ~ "no change in")) %>% 
    slice(1) %>% 
    select(-sign)
}

consec_days_i <- count_consec_days_iv(iv_dat$icu_status)
consec_days_v <- count_consec_days_iv(iv_dat$vent_status)



# text styled depending on number of consecutive days and above or below trend

# ICU Beds text
# 1 day above 40%
pos_one_i <- glue("<b style='color: #33a532'>{consec_days_i$num_days[[1]]}</b> day {consec_days_i$trend[[1]]} 40% availability for ICU beds")
# 1 day below 40%
neg_one_i <- glue("<b style='color: #cf142b'>{consec_days_i$num_days[[1]]}</b> day {consec_days_i$trend[[1]]} 40% availability for ICU beds")
# 0 days == no change
zero_days_i <- glue("{consec_days_i$trend[[1]]} in availability of ICU beds from yesterday")
# between 2 and 6 days below 40%
under_ft_i <- glue("<b style='color: #cf142b'>{consec_days_i$num_days[[1]]}</b> consecutive days of being {consec_days_i$trend[[1]]} 40% availability for ICU beds")
# 14 days and over days below 40%
ft_over_i <- glue("<b style='color: #cf142b'>{consec_days_i$num_days[[1]]}</b> consecutive days of being {consec_days_i$trend[[1]]} 40% availability for ICU beds <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #cf142b'>&#xf06A;</span>")
# between 7 and 13 days below 40%
ft_over_i_sev <- glue("<b style='color: #cf142b'>{consec_days_i$num_days[[1]]}</b> consecutive days of being {consec_days_i$trend[[1]]} 40% availability for ICU beds <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #ffae42'>&#xf071;</span>")
# more than 1 day above 40%
above_pos_one_i <- glue("<b style='color: #33a532'>{consec_days_i$num_days[[1]]}</b> consecutive days of being {consec_days_i$trend[[1]]} 40% availability for ICU beds")

# choose the subtitle text based number of consecutive days and trend
trigger_dat_i <- consec_days_i %>% 
  mutate(text = case_when(num_days == 1 & trend == "above" ~
                            pos_one_i,
                          num_days == 1 & trend == "below" ~
                            neg_one_i,
                          between(num_days, 2, 6) & trend == "below" ~
                            under_ft_i,
                          between(num_days, 7, 13) & trend == "below" ~
                            ft_over_i_sev,
                          num_days >= 14 & trend == "below" ~
                            ft_over_i,
                          num_days > 1 & trend == "above" ~
                            above_pos_one_i,
                          TRUE ~ zero_days_i),
         type = "icu")



# Ventilators text
# 1 day above 70%
pos_one_v <- glue("<b style='color: #33a532'>{consec_days_v$num_days[[1]]}</b> day {consec_days_v$trend[[1]]} 70% availability for ventilators")
# 1 day below 70%
neg_one_v <- glue("<b style='color: #cf142b'>{consec_days_v$num_days[[1]]}</b> day {consec_days_v$trend[[1]]} 70% availability for ventilators")
# 0 days == no change
zero_days_v <- glue("{consec_days_v$trend[[1]]} in availability of ventilators from yesterday")
# between 2 and 6 days below 70%
under_ft_v <- glue("<b style='color: #cf142b'>{consec_days_v$num_days[[1]]}</b> consecutive days of being {consec_days_v$trend[[1]]} 70% availability for ventilators")
# 14 and over days below 70%
ft_over_v <- glue("<b style='color: #cf142b'>{consec_days_v$num_days[[1]]}</b> consecutive days of being {consec_days_v$trend[[1]]} 70% availability for ventilators <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #cf142b'>&#xf06A;</span>")
# betweeen 7 and 13 days below 70%
ft_over_v_sev <- glue("<b style='color: #cf142b'>{consec_days_v$num_days[[1]]}</b> consecutive days of being {consec_days_v$trend[[1]]} 70% availability for ventilators <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #ffae42'>&#xf071;</span>")
# more than 1 day above 70%
above_pos_one_v <- glue("<b style='color: #33a532'>{consec_days_v$num_days[[1]]}</b> consecutive days of being {consec_days_v$trend[[1]]} 70% availability for ventilators")

# choose the subtitle text based number of consecutive days and trend
trigger_dat_v<- consec_days_v %>% 
  mutate(text = case_when(num_days == 1 & trend == "above" ~
                            pos_one_v,
                          num_days == 1 & trend == "below" ~
                            neg_one_v,
                          between(num_days, 2, 6) & trend == "below" ~
                            under_ft_v,
                          between(num_days, 7, 13) & trend == "below" ~
                            ft_over_v_sev,
                          num_days >= 14 & trend == "below" ~
                            ft_over_v,
                          num_days > 1 & trend == "above" ~
                            above_pos_one_v,
                          TRUE ~ zero_days_v),
         type = "vent")



#@@@@@@@@@@@@@@@@@@@
# 4 Gauge Plots ----
#@@@@@@@@@@@@@@@@@@@

# used for both gauge plots
# cols: type (icu or vent), percent, title, label (text of percent col)
gauge_dat <- iv_dat %>% 
  slice(1) %>% 
  select(icu_beds_pct, vent_pct) %>% 
  tidyr::pivot_longer(cols = everything(),
                      names_to = "type",
                      values_to = "percent") %>% 
  mutate(title = c("ICU Beds Available", "Ventilators Available"),
         label = scales::percent(percent, accuracy = 0.1))


icu_gauge <- ggplot(data = gauge_dat %>% 
                      filter(type == "icu_beds_pct")) +
  # green bar
  geom_rect(aes(ymax=1, ymin=0, xmax=2, xmin=1), fill ="#33a532") +
  # red bar that overlays the green bar
  geom_rect(aes(fill = type, ymax = 0.4, ymin = 0, xmax = 2, xmin = 1)) + 
  # bends bars to a half circle
  coord_polar(theta = "y",start=-pi/2) + xlim(c(0, 2)) + ylim(c(0,2)) +
  # segments the bar between red and green; black blends with black background
  geom_hline(aes(yintercept = 0.40),
             color = "black", size = 1.3) +
  # the "needle"
  geom_hline(aes(yintercept = percent),
             color = "white", size = 1.3) +
  # percent text
  geom_text(aes(x = 0.85, y = 1.5, label = label), colour="white", size=6.5, fontface = "bold", family = "Roboto") +
  # title depending on type
  geom_text(aes(x=1.5, y=1.5, label=title), size=6.2, family = "Roboto", color = "white") +
  theme_void() +
  # not sure why there's two values
  scale_fill_manual(values = c("#cf142b", "#cf142b")) +
  # maybe this the stroke for the bars?
  scale_colour_manual(values = c("#cf142b", "#cf142b")) +
  theme(legend.position = "none",
        axis.ticks = element_blank(),
        axis.line = element_blank(),
        axis.text = element_blank(),
        panel.background = element_rect(fill = "black",
                                        color = NA),
        plot.background = element_rect(fill = "black",
                                       color = NA))



vents_gauge <- ggplot(data = gauge_dat %>% 
                        filter(type == "vent_pct")) +
  geom_rect(aes(ymax=1, ymin=0, xmax=2, xmin=1), fill ="#33a532") +
  geom_rect(aes(fill = type, ymax = 0.7, ymin = 0, xmax = 2, xmin = 1)) + 
  coord_polar(theta = "y",start=-pi/2) + xlim(c(0, 2)) + ylim(c(0,2)) +
  geom_hline(aes(yintercept = 0.70),
             color = "black", size = 1.3) +
  geom_hline(aes(yintercept = percent),
             color = "white", size = 1.3) +
  geom_text(aes(x = 0.85, y = 1.5, label = label), colour="white", size=6.5, fontface = "bold", family = "Roboto") +
  geom_text(aes(x=1.5, y=1.5, label=title), size=6.2, family = "Roboto", color = "white") +
  theme_void() +
  scale_fill_manual(values = c("#cf142b", "#cf142b")) +
  scale_colour_manual(values = c("#cf142b", "#cf142b")) +
  theme(legend.position = "none",
        axis.ticks = element_blank(),
        axis.line = element_blank(),
        axis.text = element_blank(),
        panel.background = element_rect(fill = "black",
                                        color = NA),
        plot.background = element_rect(fill = "black",
                                       color = NA))



#@@@@@@@@@@@@@@@@@@@@
# 5 Trigger plot ----
#@@@@@@@@@@@@@@@@@@@@



status_dat <- trigger_dat_h %>%
  bind_rows(trigger_dat_i) %>%
  bind_rows(trigger_dat_v)

status_plot <- ggplot(status_dat, aes(y = text)) +
  ggtext::geom_richtext(data = status_dat %>% 
                          slice(1), 
                        aes(label= text,
                           x = 0,y = 0.8,
                           label.color = NA),
                        fill = "black",
                        color = "white",
                        size = 5, hjust = "left") +
  ggtext::geom_richtext(data = status_dat %>% 
                          slice(2), 
                        aes(label= text,
                           x = 0, y = 0.50,
                           label.color = NA),
                        fill = "black",
                        color = "white",
                        size = 5, hjust = "left") +
  ggtext::geom_richtext(data = status_dat %>% 
                          slice(3), 
                        aes(label= text,
                           x = 0, y = 0.20,
                           label.color = NA),
                        fill = "black",
                        color = "white",
                        size = 5, hjust = "left") +
  # sets the range of the grid, so you have some idea of coord system for text.
xlim(0, 1) + ylim(0, 1) +
  theme_void() +
  theme(panel.background = element_rect(fill = "black",
                                        color = NA),
        panel.border = element_blank(),
        plot.background = element_rect(fill = "black",
                                       color = NA))



#@@@@@@@@@@@@@@@@@@@@@@@@@@
# 6 Combine all charts ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@

# Pay attention to groupings by parentheses
# 1st plot_layout affects left col; 2nd plot_layout affects entire chart
# see gtable notes for "null" explanation
all_charts <- ((hosp_plot/status_plot + plot_layout(heights = unit(c(13, 1), c('cm', 'null')))) | 
                 (icu_gauge/vents_gauge)) +
  plot_layout(widths = c(2,1)) +
  plot_annotation(title = "Tracking COVID-19 Hospitalizations, ICU and Ventilator Availability",
                  subtitle = glue("Last updated: {data_date}"),
                  caption = glue("Sources: The Indiana Data Hub
                                 The COVID Tracking Project")) &
  theme(plot.title = element_text(color = "white",
                                  size = 16,
                                  family = "Roboto"),
        plot.subtitle = element_text(color = "white",
                                     size = 14,
                                     family = "Roboto"),
        plot.caption = element_text(color = "white",
                                    size = 12,
                                    family = "Roboto"),
        panel.background = element_rect(fill = "black",
                                        color = NA),
        panel.border = element_blank(),
        plot.background = element_rect(fill = "black",
                                       color = NA))


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/hosp-icu-vent-{data_date}.png")

ggsave(plot_path, plot = all_charts, dpi = "screen", width = 33, height = 20, units = "cm")

