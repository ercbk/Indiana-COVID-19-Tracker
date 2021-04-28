# Daily cases vs Cumulative Cases


# Notes:
# 1. Snagged from a Aussie blog post mention in readme description of R_e
# 2. One of the triggers in the AEI/JHop guidelines for moving back to stage 1 is 5 consecutive days in which daily cases increases.


# Sections
# 1. Set-up
# 2. Cleaning
# 3. AEI Snapback Trigger
# 4. Policy label data
# 5. Chart





# Set-up ----



pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, ggtext, glue, ggrepel)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv")

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))

# wanted something a little lighter for segments and curves
deep_light <- prismatic::clr_lighten(deep_rooted, shift = 0.25)

light_orange <- prismatic::clr_lighten("#B28330", shift = 0.30)

options(scipen = 999)



#@@@@@@@@@@@@@@@@
# Cleaning ----
#@@@@@@@@@@@@@@@@


# calculated daily positive cases
cases_dat <- nyt_dat %>% 
      filter(state == "Indiana") %>% 
      mutate(daily_cases = difference(cases),
             daily_cases = tidyr::replace_na(daily_cases, 1),
             sev_day_avg = slider::slide_dbl(daily_cases, .f = mean, .before = 6L),
             # for facet_zoom
             fall_wave = ifelse(date > as.Date("2020-09-26"), "fwave", "not_fwave")) %>%
      filter(date >= "2020-04-20") %>% 
      rename(cumulative_cases = cases)

# current date of data
data_date <- cases_dat %>%
      summarize(date = max(date)) %>% 
      pull(date)

policy_dat <- tibble(policy = "Stage 2",
                     date = as.Date("2020-05-04"),
                     date_text = "5/04/2020") %>% 
      add_row(policy = "Stage 3",
              date = as.Date("2020-05-22"),
              date_text = "5/22/2020") %>% 
      add_row(policy = "Stage 4",
              date = as.Date("2020-06-12"),
              date_text = "6/12/2020") %>% 
      add_row(policy = "Stage 4.5",
              date = as.Date("2020-07-03"),
              date_text = "7/3/2020") %>% 
      add_row(policy = "Conditional Mask Requirement",
              date = as.Date("2020-07-27"),
              date_text = "7/27/2020") %>% 
      add_row(policy = "Stage 5",
              date = as.Date("2020-09-26"),
              date_text = "9/26/2020") %>% 
      add_row(policy = "County-score Gathering Restrictions",
              date = as.Date("2020-11-14"),
              date_text = "11/14/2020") %>%
      add_row(policy = "Mask Requirement Ends",
              date = as.Date("2021-04-06"),
              date_text = "04/06/2021") %>% 
      mutate(labels = c("2", "3", "4", "4.5", "CMR", "5", "CGR", "Mask Requirement Ends"))

holiday_dat <- tibble(holiday = c("Memorial Day", "Independence Day", "Labor Day", "Thanksgiving",
                                  "Christmas", "New Years Eve", "Super Bowl", "Easter"),
                      date = as.Date(c("2020-05-25", "2020-07-04", "2020-09-07", "2020-11-26",
                                       "2020-12-25", "2020-12-31", "2021-02-07", "2021-04-04"))) %>% 
      inner_join(cases_dat %>% 
                       select(date, cumulative_cases, daily_cases), by = "date")

vax_dat <- tibble(age = c("80+", "70+", "65-69", "60-64",
                          "55-59", "50-54", "45-49",
                          "40-44", "30-39", "16+"),
                  date = as.Date(c("2021-01-08", "2021-01-13", "2021-02-01",
                                   "2021-02-23", "2021-03-02", "2021-03-03",
                                   "2021-03-16", "2021-03-22", "2021-03-29", "2021-03-31")),
                  labels = c("80", "70", "65", "60", "55",
                             "50", "45", "40", "30", "16")) %>% 
      inner_join(cases_dat %>% 
                       select(date, cumulative_cases, daily_cases), by = "date")


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# AEI Snapback Trigger ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# calc difference between one day and the previous day
daily_change <- cases_dat %>%
      mutate(cases_diff = difference(daily_cases)) %>%
      arrange(desc(date)) %>% 
      pull(cases_diff)

# calculate how many consecutive days of increasing/decreasing daily cases
count_consec_days <- function(x) {
      # rle: "run length encoding," counts runs of same value or in this case, the same sign
      pos_runs <- rle(sign(x))
      conseq_days <- tibble(
            num_days = pos_runs$lengths,
            sign = pos_runs$values
      ) %>% 
            mutate(trend = case_when(sign == 1 ~ "increased",
                                     sign == -1 ~ "decreased",
                                     TRUE ~ "no change in")) %>% 
            slice(1) %>% 
            select(-sign)
}

consec_days <- count_consec_days(daily_change)


# text styled depending on number of consecutive days and increasing or decreasing trend
neg_one <- glue("<b style='color: #33a532'>{consec_days$num_days[[1]]}</b> day of {consec_days$trend[[1]]} new cases")
pos_one <- glue("<b style='color: #cf142b'>{consec_days$num_days[[1]]}</b> day of {consec_days$trend[[1]]} new cases")
zero_days <- glue("{consec_days$trend[[1]]} new cases")
under_five <- glue("<b style='color: #cf142b'>{consec_days$num_days[[1]]}</b> consecutive days of {consec_days$trend[[1]]} new cases")
five_over <- glue("<b style='color: #cf142b'>{consec_days$num_days[[1]]}</b> consecutive days of {consec_days$trend[[1]]} new cases <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #cf142b'>&#xf071;</span>")
under_neg_one <- glue("<b style='color: #33a532'>{consec_days$num_days[[1]]}</b> consecutive days of {consec_days$trend[[1]]} new cases")


# choose the subtitle text based number of consecutive days and trend
subtitle_dat <- consec_days %>% 
      mutate(text = case_when(num_days == 1 & trend == "increased" ~
                                    pos_one,
                              num_days == 1 & trend == "decreased" ~
                                    neg_one,
                              between(num_days, 2, 4) & trend == "increased" ~
                                    under_five,
                              num_days >= 5 & trend == "increased" ~
                                    five_over,
                              num_days > 1 & trend == "decreased" ~
                                    under_neg_one,
                              TRUE ~ zero_days))




#@@@@@@@@@@@@@@@@@@@@@@@@@
# policy label data ----
#@@@@@@@@@@@@@@@@@@@@@@@@@


label_dat <- cases_dat %>%
      as_tibble() %>%
      # inner_join only keeps dates with a policy associated with it
      inner_join(policy_dat, by = "date") %>%
      select(-deaths, -fips, -state)


# arrow specification used below; trying to keep the ggplot mess to a minimum
arw <- arrow(length = unit(6, "pt"), type = "closed")

# multiline caption text; trying to keep ggplot code mess to a minimum
caption_text_20 <- glue("Source: The New York Times, based on reports from state and local health agencies")
caption_text_21 <- glue("Last updated: {data_date}")

holiday_text <- "<span style='font-family: \"Font Awesome 5 Free Solid\"; color: #D5AB62FF; font-size:18pt'>&#9830;</span> Holiday"
vax_text <- "<span style='font-family: \"Font Awesome 5 Free Solid\"; color: #30b278; font-size:18pt'>&#9679;</span> Age group becomes eligible for vaccine"
pol_text <- "<span style='font-family: \"Font Awesome 5 Free Solid\"; color: #306bb2; font-size:18pt'>&#9679;</span> Mask Requirement Ends"



xmax <- cases_dat %>% 
      filter(date == max(date)) %>% 
      mutate(xmax = cumulative_cases * 1.03) %>% 
      pull(xmax)
ymax <- cases_dat %>% 
      filter(daily_cases == max(daily_cases)) %>% 
      mutate(ymax = daily_cases * 1.06) %>% 
      pull(ymax)

policy_text <- glue("
                    <b style= 'font-size: 16px'>Reopening Stages</b><br><br>
                    <b><i style= 'font-size:18px'>2</i></b> : Stage 2 (5/04/2020)<br>
                    <b><i style= 'font-size:18px'>3</i></b> : Stage 3 (5/22/2020)<br>
                    <b><i style= 'font-size:18px'>4</i></b> : Stage 4 (6/12/2020)<br>
                    <b><i style= 'font-size:18px'>4.5</i></b> : Stage 4.5 (7/3/2020)<br>
                    <b><i style= 'font-size:18px'>CMR</i></b> : Conditional Mask Requirement (7/27/2020)<br>
                    <b><i style= 'font-size:18px'>5</i></b> : Stage 5 (9/26/2020)<br>
                    <b><i style= 'font-size:18px'>CGR</i></b> : County-score Gathering Restrictions (11/14/2020)<br>
                    ")



#@@@@@@@@@@@@@@
# Chart ----
#@@@@@@@@@@@@@@


## 2020 Chart (no longer needs updated) ----

# # daily cases has some zeros and we're taking logs, so adding 1
# pos_policy_zero <- ggplot(cases_dat %>%
#                              as_tibble() %>%
#                              filter(date <= as.Date("2020-12-31")), aes(x = cumulative_cases, y = daily_cases)) +
#    geom_point(color = "#B28330") +
#    # must specify color arg for shapes to show-up
#    geom_point(data = holiday_dat %>%
#                  filter(date <= as.Date("2020-12-31")) %>%
#                  mutate(zoom = TRUE), color = light_orange, shape = 18, size = 4, stroke = 1.5) +
#    # for holidays outside of zoom_facet range
#    geom_point(data = holiday_dat %>%
#                  filter(between(date, as.Date("2020-09-07"), as.Date("2020-12-31"))), color = light_orange, shape = 18, size = 4, stroke = 1.5) +
#    geom_line(color = "#B28330") +
#    # expand_limits(y = max(cases_dat$daily_cases) + 1000) +
#    # experiments with adding smoothing lines
#    # geom_line(aes(y = sev_day_avg), color = "#B28330", alpha = 0.45, size = 1) +
#    # stat_smooth(method = "loess", geom = "line", se = FALSE, formula = "y ~ x",
#    # alpha = 0.45, color = "#B28330", size = 0.9) +
#    # facet_zoom doesn't play nice with scale_y or x_continuous
#    # scale_y_continuous(limits = c(0, ymax), labels = scales::label_comma()) +
#    # scale_x_continuous(limits = c(10000, xmax), labels = scales::label_comma()) +
#    # hates tsibbles, data needs to be a tibble or df
#    # zoom.data = zoom needed to only add label to zoomed area
#    ggforce::facet_zoom(
#       # x = cumulative_cases > 120000,
#       x = fall_wave == "fwave",
#       xlim = c(10000, 118000), ylim = c(0, 2000),
#       zoom.data = zoom,
#       show.area = FALSE, zoom.size = 0.5,
#       horizontal = FALSE) +
#    geom_richtext(data = tibble(x = 65000, y = 1800, zoom = TRUE),
#                  aes(x = x, y = y, label = holiday_text,
#                      label.color = NA, size = 12, fontface = "bold"),
#                  fill = "black", color = "white") +
#    geom_text(aes(x = 10000, y = ymax, label="Daily Cases"),
#              family="Roboto",
#              size=4.5, hjust=0.35, color="white") +
#    geom_textbox(aes(10000, ymax-2200),
#                 label = policy_text, halign = 0,
#                 col = "white", fill = "black",
#                 # both are for box, hjust = 0 says align left edge of box with x coord
#                 width = 0.30, hjust = 0.09) +
#    # policy labels, hjust and vjust values depends on label
#    geom_richtext(data = label_dat %>%
#                     filter(policy != "Stage 5") %>%
#                     # zoom = F is so CGR is only in the top panel
#                     mutate(zoom = c(rep(TRUE,5), FALSE)),
#                  aes(x = cumulative_cases,
#                      y = daily_cases,
#                      label= labels, fontface = "bold.italic",
#                      label.colour = "black",
#                      hjust = "middle", vjust = "center"),
#                  family="Roboto", lineheight=0.95,
#                  size=4.5, label.size=0,
#                  color = "white", fill = "black",
#                  nudge_x = c(-800, 2800, -11000, 10100, 6500, 49000),
#                  nudge_y = c(-550, -475, 900, 880, -320, 0)) +
#    # I want Stage 5 to be in both panels, so had give it's own geom. Using zoom = F for this stage didn't work when I tried to do it in one geom.
#    geom_richtext(data = label_dat %>%
#                     filter(policy == "Stage 5"),
#                  aes(x = cumulative_cases,
#                      y = daily_cases,
#                      label= labels, fontface = "bold.italic",
#                      label.colour = "black",
#                      hjust = "middle", vjust = "center"),
#                  family="Roboto", lineheight=0.95,
#                  size=4.5, label.size=0,
#                  color = "white", fill = "black",
#                  nudge_x = -15000,
#                  nudge_y = 800) +
#    # # segments connecting policy labels to points
#    # stage 2
#    geom_curve(
#       data = data.frame(x = 18500, xend = 18000,
#                         y = 150, yend = 450, zoom = TRUE),
#       aes(x = x, xend = xend,
#           y = y, yend = yend),
#       color = deep_light[[7]], arrow = arw,
#       curvature = -0.70
#    ) +
#    # stage 3
#    geom_curve(
#       data = data.frame(x = 31000, xend = 29300,
#                         y = 0, yend = 300, zoom = TRUE),
#       aes(x = x, xend = xend,
#           y = y, yend = yend),
#       color = deep_light[[7]], arrow = arw,
#       curvature = -0.80
#    ) +
#    # stage 4
#    geom_curve(
#       data = data.frame(x = 32000, xend = 39950,
#                         y = 1250, yend = 700, zoom = TRUE),
#       aes(x = x, xend = xend,
#           y = y, yend = yend),
#       color = deep_light[[7]], arrow = arw,
#       curvature = -0.40
#    ) +
#    # stage 4.5
#    geom_curve(
#       data = data.frame(x = 54000, xend = 48000,
#                         y = 1380, yend = 805, zoom = TRUE),
#       aes(x = x, xend = xend,
#           y = y, yend = yend),
#       color = deep_light[[7]], arrow = arw,
#       curvature = 0.40
#    ) +
#    # cond. mask requirement
#    geom_curve(
#       data = data.frame(x = 69000, xend = 64000,
#                         y = 35, yend = 300, zoom = TRUE),
#       aes(x = x, xend = xend,
#           y = y, yend = yend),
#       color = deep_light[[7]], arrow = arw,
#       curvature = -0.80
#    ) +
#    # stage 5
#    geom_curve(
#       data = data.frame(x = 110000, xend = 119000,
#                         y = 1970, yend = 1450),
#       aes(x = x, xend = xend,
#           y = y, yend = yend),
#       color = deep_light[[7]], arrow = arw,
#       curvature = -0.50
#    ) +
#    # County-score Gathering Restrictions
#    geom_segment(
#       data = data.frame(x = 280000, xend = 255000,
#                         y = 8327, yend = 8327, zoom = FALSE),
#       aes(x = x, xend = xend,
#           y = y, yend = yend),
#       color = deep_light[[7]], arrow = arw
#    ) +
#    labs(x = "Cumulative Cases", y = NULL,
#         title = "2020: Daily <b style='color:#B28330'>Positive Test Results</b> vs. Cumulative <b style='color:#B28330'>Positive Test Results</b>",
#         caption = caption_text_20) +
#    theme(plot.title = element_textbox_simple(size = 16,
#                                              color = "white",
#                                              family = "Roboto"),
#          plot.subtitle = element_textbox_simple(size = 14,
#                                                 color = "white"),
#          plot.caption = element_text(color = "white",
#                                      size = 12),
#          text = element_text(family = "Roboto"),
#          legend.position = "none",
#          axis.text.x = element_text(color = "white",
#                                     size = 12),
#          axis.text.y = element_text(color = "white",
#                                     size = 12),
#          axis.title.x = element_textbox_simple(color = "white",
#                                                size = 13),
#          panel.background = element_rect(fill = "black",
#                                          color = NA),
#          plot.background = element_rect(fill = "black",
#                                         color = NA),
#          panel.border = element_blank(),
#          panel.grid.minor = element_blank(),
#          panel.grid.major = element_line(color = deep_rooted[[7]]))
# 
# 
# 
# plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/pos-policy-zero-{data_date}.png")
# 
# 
# # with facet_zoom, need to make it taller
# ggsave(plot_path, plot = pos_policy_zero,
#        dpi = "screen", width = 33, height = 30,
#        device = ragg::agg_png(), units = "cm")
# 
# 




## 2021 chart ----

pos_policy_one <- ggplot(cases_dat %>% 
                               as_tibble() %>% 
                               filter(date > as.Date("2020-12-31")), aes(x = cumulative_cases, y = daily_cases)) +
      geom_point(color = "#B28330") +
      geom_point(data = holiday_dat %>% 
                       filter(date > "2020-12-31"), color = light_orange, shape = 18, size = 4, stroke = 1.5) +
      geom_point(data = vax_dat, color = "#30b278", size = 3) +
      geom_point(data = tibble(x = 695532, y = 614), aes(x, y),
                 color = "#306bb2", size = 3) +
      geom_line(color = "#B28330") +
      scale_y_continuous(limits = c(0, ymax), labels = scales::label_comma()) +
      scale_x_continuous(limits = c(515000, xmax), labels = scales::label_comma()) +
      geom_text_repel(data = vax_dat, aes(label = labels),
                      color = "#30b278", fontface = "bold.italic", point.padding = 14,
                      size = 5, direction = "y", seed = 10) +
      geom_richtext(data = tibble(x = 600000, y = ymax, zoom = TRUE),
                    aes(x = x, y = y, label = holiday_text, hjust = "left",
                        label.color = NA, size = 12, fontface = "bold"),
                    fill = "black", color = "white") +
      geom_richtext(data = tibble(x = 600000, y = ymax-500),
                    aes(x = x, y = y, label = vax_text, hjust = "left",
                        label.color = NA, size = 12, fontface = "bold"),
                    fill = "black", color = "white") +
      geom_richtext(data = tibble(x = 600000, y = ymax-1000),
                    aes(x = x, y = y, label = pol_text, hjust = "left",
                        label.color = NA, size = 12, fontface = "bold"),
                    fill = "black", color = "white") +
      geom_text(aes(x = 515000, y = ymax, label="Daily Cases"),
                family="Roboto",
                size=4.5, hjust=0.35, color="white") +
labs(x = "Cumulative Cases", y = NULL,
     title = "2021: Daily <b style='color:#B28330'>Positive Test Results</b> vs. Cumulative <b style='color:#B28330'>Positive Test Results</b>",
     subtitle = subtitle_dat$text[[1]],
     caption = caption_text_21) +
      theme(plot.title = element_textbox_simple(size = 16,
                                                color = "white",
                                                family = "Roboto"),
            plot.subtitle = element_textbox_simple(size = 14,
                                                   color = "white"),
            plot.caption = element_text(color = "white",
                                        size = 12),
            text = element_text(family = "Roboto"),
            legend.position = "none",
            axis.text.x = element_text(color = "white",
                                       size = 12),
            axis.text.y = element_text(color = "white",
                                       size = 12),
            axis.title.x = element_textbox_simple(color = "white",
                                                  size = 13),
            panel.background = element_rect(fill = "black",
                                            color = NA),
            plot.background = element_rect(fill = "black",
                                           color = NA),
            panel.border = element_blank(),
            panel.grid.minor = element_blank(),
            panel.grid.major = element_line(color = deep_rooted[[7]]))


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/pos-policy-one-{data_date}.png")

ggsave(plot_path, plot = pos_policy_one,
       dpi = "screen", width = 33, height = 20,
       device = ragg::agg_png(), units = "cm")


