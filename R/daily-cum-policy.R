# Daily cases vs Cumulative Cases


# Notes:
# 1. When line starts steadily going vertical, it indicates the disease spread is coming under control.
# 2. Snagged from a Aussie blog post mention in readme description of R_e
# 3. Policy data has other types of columns which maybe useful for other types of visuals/analysis
# 4. One of the triggers in the AEI/JHop guidelines for moving back to stage 1 is 5 consecutive days in which daily cases increases.


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

state_policy <- readr::read_csv(glue("{rprojroot::find_rstudio_root_file()}/data/covid-state-policy-database-boston-univ.csv"))

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))

# wanted something a little lighter for segments and curves
deep_light <- prismatic::clr_lighten(deep_rooted, shift = 0.25)



########################
# Cleaning
########################


# calculated daily positive cases
cases_dat <- nyt_dat %>% 
   filter(state == "Indiana") %>% 
   as_tsibble(index = "date") %>% 
   mutate(daily_cases = difference(cases),
          daily_cases = tidyr::replace_na(daily_cases, 1)) %>% 
   rename(cumulative_cases = cases)

# current date of data
data_date <- cases_dat %>% 
   as_tibble() %>%
   summarize(date = max(date)) %>% 
   pull(date)

# grabbing only a few of the policy columns + some cleaning
policy_dat <- state_policy %>% 
   filter(State == "Indiana") %>% 
   select(2, 3, 6, 7, 11, 12, 13, 14) %>% 
   tidyr::pivot_longer(cols = everything(), names_to = "policy", values_to = "date") %>% 
   mutate(date_text = date,
          date = lubridate::mdy(date),
          policy = stringr::str_replace(policy,
                                        pattern = "Date c",
                                        replacement = "C")) %>% 
   add_row(policy = "Resumes elective medical procedures",
           date = as.Date("2020-04-24"),
           date_text = "4/24/2020") %>%
   add_row(policy = "Stage 2 Re-opening",
           date = as.Date("2020-05-04"),
           date_text = "5/04/2020") %>% 
   add_row(policy = "Stage 3 Re-opening",
           date = as.Date("2020-05-22"),
           date_text = "5/22/2020")



########################
# AEI Snapback Trigger
########################


# calc difference between one day and the previous day
daily_change <- cases_dat %>%
   as_tibble() %>% 
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
   filter(!policy %in% c("Closed movie theaters", "Closed gyms", "Froze evictions", "Resumes elective medical porcedures")) %>% 
   # merges rows in policy that have same values in the other columns.
   aggregate(data = .,
             policy ~ date + cumulative_cases + daily_cases,
             FUN = paste0, collapse = "\n") %>% 
   # painstakingly searched-for values for nudging the labels
   mutate(hjust = c(-0.2, -0.25, 1.3, 1, 0.6, 1.2, 1.3),
          vjust = c(-7, 2, -1.32, -2.3, 7.0, 5.5, -2))


# arrow specification used below; trying to keep the ggplot mess to a minimum
arw <- arrow(length = unit(6, "pt"), type = "closed")

# multiline caption text; trying to keep ggplot code mess to a minimum
caption_text <- glue("Last updated: {data_date}
                     Sources: The New York Times, based on reports from state and local health agencies
                     Julia Raifman,  Kristen Nocka, et al at Boston University")



###########################
# Chart
###########################


# daily cases has some zeros and we're taking logs, so adding 1
pos_policy_line <- ggplot(cases_dat, aes(x = cumulative_cases, y = daily_cases+1)) +
   geom_point(color = "#B28330") +
   geom_line(color = "#B28330") +
   expand_limits(y = 1500, x = 50000) +
   scale_x_log10(breaks = c(0, 10, 100, 1000, 10000),
                 labels = c("0", "10", "100", "1,000", "10,000")) +
   # adding 1 to match the adjustment above
   scale_y_log10(breaks = c(1,11,101,1001),
                 labels = c("0", "10", "100", "1,000")) +
   # creates a y-axis label but inside the plotting area
   geom_label(aes(x=0, y=1000, label="Daily Cases"),
              family="Roboto", fill = "black",
              size=4, hjust=0, label.size=0, color="white") +
   # policy labels, hjust and vjust values depends on label
   geom_label(data=label_dat, aes(x = cumulative_cases,
                                  y = daily_cases,
                                  label= policy,
                                  hjust = hjust, vjust = vjust),
              family="Roboto", lineheight=0.95,
              size=4.5, label.size=0,
              color = "white", fill = "black") +
   # segments and curves connecting policy labels to points
   geom_curve(
      data = data.frame(), aes(x = 1.2, xend = 0.96,
                               yend = 2.7, y = 5.7), 
      color = deep_light[[7]], arrow = arw
   ) +
   geom_curve(
      data = data.frame(), aes(x = 110, xend = 25,
                               yend = 4.5, y = 2.6), 
      color = deep_light[[7]], arrow = arw,
      curvature = -0.70
   ) +
   geom_curve(
      data = data.frame(), aes(x = 20, xend = 53,
                               yend = 26, y = 36), 
      color = deep_light[[7]], arrow = arw,
      curvature = -0.70
   ) +
   geom_segment(
      data = data.frame(), aes(x = 110, xend = 300,
                               yend = 126, y = 260),
      color = deep_light[[7]], arrow = arw
   ) +
   geom_segment(
      data = data.frame(), aes(x = 7000, xend = 12000,
                               yend = 750, y = 1000),
      color = deep_light[[7]], arrow = arw
   ) +
   # stage 2
   geom_segment(
      data = data.frame(), aes(x = 10000, xend = 17000,
                               yend = 450, y = 170),
      color = deep_light[[7]], arrow = arw
   ) +
   # stage 3
   geom_segment(
      data = data.frame(), aes(x = 25000, xend = 30000,
                               yend = 330, y = 110),
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
                                               size = 12),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/pos-policy-line-{data_date}.png")

ggsave(plot_path, plot = pos_policy_line, dpi = "screen", width = 33, height = 20, units = "cm")


