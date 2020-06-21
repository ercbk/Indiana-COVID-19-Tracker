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




########################
# Set-up
########################


pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, ggtext, glue)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv")

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))

# wanted something a little lighter for segments and curves
deep_light <- prismatic::clr_lighten(deep_rooted, shift = 0.25)



########################
# Cleaning
########################


# calculated daily positive cases
cases_dat <- nyt_dat %>% 
   filter(state == "Indiana") %>% 
   mutate(daily_cases = difference(cases),
          daily_cases = tidyr::replace_na(daily_cases, 1)) %>%
   filter(date >= "2020-04-20") %>% 
   rename(cumulative_cases = cases)

# current date of data
data_date <- cases_dat %>%
   summarize(date = max(date)) %>% 
   pull(date)

policy_dat <- tibble(policy = "Stage 2 Reopening",
                     date = as.Date("2020-05-04"),
                     date_text = "5/04/2020") %>% 
   add_row(policy = "Stage 3 Reopening",
           date = as.Date("2020-05-22"),
           date_text = "5/22/2020") %>% 
   add_row(policy = "Stage 4 Reopening",
           date = as.Date("2020-06-12"),
           date_text = "6/12/2020") %>% 
   mutate(labels = glue("{policy}
                           ( {date_text} )     "))


########################
# AEI Snapback Trigger
########################


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




############################
# policy label data
############################


label_dat <- cases_dat %>% 
   as_tibble() %>% 
   # inner_join only keeps dates with a policy associated with it
   inner_join(policy_dat, by = "date") %>% 
   select(-deaths, -fips, -state) %>%
   mutate(hjust = c(1.0, 0.9, 0.7),
          vjust = c(3.1, 3.5, -2.5))


# arrow specification used below; trying to keep the ggplot mess to a minimum
arw <- arrow(length = unit(6, "pt"), type = "closed")

# multiline caption text; trying to keep ggplot code mess to a minimum
caption_text <- glue("Last updated: {data_date}
                     Source: The New York Times, based on reports from state and local health agencies")


xmax <- cases_dat %>% 
   filter(date == max(date)) %>% 
   mutate(xmax = cumulative_cases * 1.03) %>% 
   pull(xmax)



###########################
# Chart
###########################


# daily cases has some zeros and we're taking logs, so adding 1
pos_policy_line <- ggplot(cases_dat %>% 
                             as_tibble(), aes(x = cumulative_cases, y = daily_cases)) +
   geom_point(color = "#B28330") +
   geom_line(color = "#B28330") +
   scale_y_continuous(limits = c(0, 1200), labels = scales::label_comma()) +
   scale_x_continuous(limits = c(10000, xmax), labels = scales::label_comma()) +
   geom_text(aes(x = 10000, y = 1200, label="Daily Cases"),
             family="Roboto",
             size=4.5, hjust=0.5, color="white") +
   # policy labels, hjust and vjust values depends on label
   geom_label(data=label_dat, aes(x = cumulative_cases,
                                  y = daily_cases,
                                  label= labels,
                                  hjust = hjust, vjust = vjust),
              family="Roboto", lineheight=0.95,
              size=4.5, label.size=0,
              color = "white", fill = "black") +
   # segments connecting policy labels to points
   # stage 2
   geom_segment(
      data = data.frame(), aes(x = 18000, xend = 19500,
                               y = 429, yend = 565),
      color = deep_light[[7]], arrow = arw
   ) +
   # stage 3
   geom_segment(
      data = data.frame(), aes(x = 29000, xend = 30500,
                               y = 300, yend = 429),
      color = deep_light[[7]], arrow = arw
   ) +
   # stage 4
   geom_segment(
      data = data.frame(), aes(x = 39000, xend = 39750,
                               y = 588, yend = 470),
      color = deep_light[[7]], arrow = arw
   ) +
   labs(x = "Cumulative Cases", y = NULL,
        title = "Daily <b style='color:#B28330'>Positive Test Results</b> vs. Cumulative <b style='color:#B28330'>Positive Test Results</b>",
        subtitle = subtitle_dat$text[[1]],
        caption = caption_text) +
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


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/pos-policy-line-{data_date}.png")

ggsave(plot_path, plot = pos_policy_line, dpi = "screen", width = 33, height = 20, units = "cm")


