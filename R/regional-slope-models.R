# regional slope estimation

# Fits and visualizes log-linear models for positive cases and deaths for states in Indiana's local region.

# Sections
# 1. Set-up
# 2. Process data
# 3. Models
# 4. Label data
# 5. Line charts




########################
# Set-up
########################


pacman::p_load(extrafont, swatches, dplyr, tsibble, fable, ggplot2, ggtext, glue)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
for_floor <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Forest Floor.ase"))
trippy <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Trippy.ase"))
kind <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Kindred Spirits.ase"))
haze <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Purple Haze.ase"))
queen <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Drama Queen.ase"))


# remove scientific notations
options(scipen=999)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv")

state_policy <- readr::read_csv(glue("{rprojroot::find_rstudio_root_file()}/data/covid-state-policy-database-boston-univ.csv"))

# get cumulative counts from midwest states (and Kentucky)
midwest_dat <- nyt_dat %>%
   filter(state %in% c("Indiana", "Kentucky", "Ohio", "Michigan", "Illinois")) %>%
   group_by(state, date) %>% 
   summarize(positives = sum(cases),
             deaths = sum(deaths)) %>% 
   as_tsibble(index = "date", key = "state")

# current date of data
data_date <- midwest_dat %>% 
   as_tibble() %>%
   summarize(date = max(date)) %>% 
   pull(date)




########################
# Process data
########################


# getting number of days after 100 cases was reached
pos_days_lengths <- midwest_dat %>% 
   filter(positives >= 100) %>%
   as_tibble() %>% 
   group_by(state) %>% 
   count(state) %>% 
   pull(n)

# creating a sequence for each number-of-days length
pos_days <- purrr::map_dfr(pos_days_lengths, function(x) seq(1:x) %>% as_tibble()) %>% rename(days = value)

# adding the days col to the data
pos_chart_dat <- midwest_dat %>% 
   filter(positives >= 100) %>% 
   bind_cols(pos_days)

# same for deaths
dea_days_lengths <- midwest_dat %>% 
   filter(deaths >= 5) %>%
   as_tibble() %>% 
   group_by(state) %>% 
   count(state) %>% 
   pull(n)
dea_days <- purrr::map_dfr(dea_days_lengths, function(x) seq(1:x) %>% as_tibble()) %>% rename(days = value)
dea_chart_dat <- midwest_dat %>% 
   filter(deaths >= 5) %>% 
   bind_cols(dea_days)




########################
# Models
########################

# log-linear model by state
# used early in pandemic when curves were exponential
# mw_pos_models <- midwest_dat %>% 
#    model(log_mod = TSLM(log(positives) ~ trend())) %>% 
#    mutate(coef_info = purrr::map(log_mod, broom::tidy)) %>% 
#    tidyr::unnest(coef_info) %>% 
#    filter(term == "trend()") %>% 
#    mutate(estimate = exp(estimate))
# 
# mw_dea_models <- midwest_dat %>% 
#    filter(deaths != 0) %>% 
#    model(log_mod = TSLM(log(deaths) ~ trend())) %>% 
#    mutate(coef_info = purrr::map(log_mod, broom::tidy)) %>% 
#    tidyr::unnest(coef_info) %>% 
#    filter(term == "trend()") %>% 
#    mutate(estimate = exp(estimate))



# 7, 14 day moving averages
pos_mov_avg <- midwest_dat %>%
   group_by(state) %>%
   mutate(daily_cases = difference(positives),
          daily_sevDy_ma = slide_dbl(daily_cases,
                              mean, na.rm = TRUE, .size = 7, .align = "right") %>% 
             round(., 2),
          daily_twoWk_ma = slide_dbl(daily_cases,
                              mean, na.rm = TRUE, .size = 14, .align = "right") %>% 
             round(., 2)) %>% 
   select(-deaths)


dea_mov_avg <- midwest_dat %>%
   group_by(state) %>%
   mutate(daily_cases = difference(deaths),
          daily_sevDy_ma = slide_dbl(daily_cases,
                              mean, na.rm = TRUE, .size = 7, .align = "right") %>% 
             round(., 2),
          daily_twoWk_ma = slide_dbl(daily_cases,
                              mean, na.rm = TRUE, .size = 14, .align = "right") %>% 
             round(., 2)) %>% 
   select(-positives)




########################
# Label data
########################


# positives
# filter current date of data
pos_lbl_dat <- pos_mov_avg %>% 
   group_by(state) %>% 
   filter(date == max(date))


# assemble label text
pos_mi_lbl <- glue("Michigan
                   7 day moving avg: {pos_lbl_dat$daily_sevDy_ma[[4]]}
                   14 day moving avg: {pos_lbl_dat$daily_twoWk_ma[[4]]}")
pos_in_lbl <- glue("Indiana
                   7 day moving avg: {pos_lbl_dat$daily_sevDy_ma[[2]]}
                   14 day moving avg: {pos_lbl_dat$daily_twoWk_ma[[2]]}")
pos_il_lbl <- glue("Illinois
                   7 day moving avg: {pos_lbl_dat$daily_sevDy_ma[[1]]}
                   14 day moving avg: {pos_lbl_dat$daily_twoWk_ma[[1]]}")
pos_oh_lbl <- glue("Ohio
                   7 day moving avg: {pos_lbl_dat$daily_sevDy_ma[[5]]}
                   14 day moving avg: {pos_lbl_dat$daily_twoWk_ma[[5]]}")
pos_ky_lbl <- glue("Kentucky
                   7 day moving avg: {pos_lbl_dat$daily_sevDy_ma[[3]]}
                   14 day moving avg: {pos_lbl_dat$daily_twoWk_ma[[3]]}")

# coordinates for the data pt that ggforce will use for label
pos_mark_circle_dat <- tibble(
   days = pos_chart_dat %>% 
      filter(date == max(date)) %>%
      as_tibble() %>% 
      pull(days),
   state = pos_chart_dat %>%
      as_tibble() %>% 
      select(state) %>% 
      distinct() %>% 
      pull(state),
   positives = pos_chart_dat %>% 
      filter(date == max(date)) %>%
      as_tibble() %>% 
      pull(positives),
   desc = c(pos_il_lbl, pos_in_lbl, pos_ky_lbl, pos_mi_lbl, pos_oh_lbl)
)



# deaths
# same thing
dea_lbl_dat <- dea_mov_avg %>% 
   group_by(state) %>%
   filter(date == max(date))


dea_mi_lbl <- glue("Michigan
                   7 day moving average: {dea_lbl_dat$daily_sevDy_ma[[4]]}
                   14 day moving average: {dea_lbl_dat$daily_twoWk_ma[[4]]}")
dea_in_lbl <- glue("Indiana
                   7 day moving average: {dea_lbl_dat$daily_sevDy_ma[[2]]}
                   14 day moving average: {dea_lbl_dat$daily_twoWk_ma[[2]]}")
dea_il_lbl <- glue("Illinois
                   7 day moving average: {dea_lbl_dat$daily_sevDy_ma[[1]]}
                   14 day moving average: {dea_lbl_dat$daily_twoWk_ma[[1]]}")
dea_oh_lbl <- glue("Ohio
                   7 day moving average: {dea_lbl_dat$daily_sevDy_ma[[5]]}
                   14 day moving average: {dea_lbl_dat$daily_twoWk_ma[[5]]}")
dea_ky_lbl <- glue("Kentucky
                   7 day moving average: {dea_lbl_dat$daily_sevDy_ma[[3]]}
                   14 day moving average: {dea_lbl_dat$daily_twoWk_ma[[3]]}")

dea_mark_circle_dat <- tibble(
   days = dea_chart_dat %>% 
      filter(date == max(date)) %>%
      as_tibble() %>% 
      pull(days),
   state = dea_chart_dat %>%
      as_tibble() %>% 
      select(state) %>% 
      distinct() %>% 
      pull(state),
   deaths = dea_chart_dat %>% 
      filter(date == max(date)) %>%
      as_tibble() %>% 
      pull(deaths),
   desc = c(dea_il_lbl, dea_in_lbl, dea_ky_lbl, dea_mi_lbl, dea_oh_lbl)
)

# gets a few policies for some states and does some cleaning
policy_dat <- state_policy %>% 
   filter(State %in% c("Indiana", "Kentucky", "Ohio", "Michigan", "Illinois")) %>% 
   select(1, 6, 7) %>% 
   tidyr::pivot_longer(cols = c(2,3), names_to = "policy", values_to = "date") %>%
   mutate(date = lubridate::mdy(date)) %>%
   rename(state = State) %>% 
   left_join(pos_chart_dat,
             by = c("state", "date")) %>% 
   tidyr::drop_na() %>% 
   # combines policy cells that occur on the same date
   aggregate(data = ., policy ~ date + days + state + positives + deaths, FUN = paste0, collapse = "\n") %>% 
   mutate(policy = ifelse(policy == "Stay at home/ shelter in place\nClosed non-essential businesses", "Shelter in place & Closed non-essential businesses", policy))




########################
# Line charts
########################


# positive test cases
mw_pos_line <- ggplot(pos_chart_dat, aes(x = days, y = positives, color = state)) + 
   geom_line() + 
   geom_point() +
   scale_color_manual(guide = FALSE, values = c(trippy[[6]], kind[[2]], haze[[7]], for_floor[[3]], queen[[5]])) +
   geom_point(data = policy_dat, aes(shape = policy), size = 3, stroke = 1.5) +
   # values arg says which shape types I want for each policy
   scale_shape_manual(name = NULL, values = c("Shelter in place & Closed non-essential businesses" = 15, "Closed non-essential businesses" = 17)) +
   # stroke gives a thicker shape symbol
   guides(shape = guide_legend(
      title = NULL,
      override.aes = list(color = "white",
                          stroke = 1.5)
   )) +
   scale_y_log10() +
   # needed to provide space to ggforce labels
   # just multiplying the max by a constant wasn't keeping me from having to continually adjust the constant, so I had to come-up with something else
   expand_limits(y = max(pos_chart_dat$positives)*nrow(pos_chart_dat)*0.05,
                 x = max(pos_chart_dat$days)+(nrow(pos_chart_dat)*0.03)) +
   labs(x = "Number of days since a total of 100 <b style='color:#B28330'>positive cases</b> first recorded", y = NULL,
        title = "Regional COVID-19 <b style='color:#B28330'> Cumulative Positive Test Results</b>",
        subtitle = glue("Last updated: {data_date}"),
        caption = "Source: The New York Times, based on reports from state and local health agencies") +
   ggforce::geom_mark_circle(aes(
      x = days, y = positives,
      group = state, description = desc),
      data = pos_mark_circle_dat,
      # shrinks circle around the data point
      expand = -0.1, radius = 0.01,
      con.colour = deep_rooted[[7]],
      # says how far from the data point I want the label
      label.buffer = unit(6, "mm"),
      label.colour = "white",
      label.fill = deep_rooted[[7]],
      color = deep_rooted[[7]]) +
   theme(plot.title = element_textbox_simple(size = rel(1.5),
                                             color = "white",
                                             family = "Roboto"),
         plot.subtitle = element_text(size = rel(0.95),
                                      color = "white"),
         plot.caption = element_text(color = "white",
                                     size = rel(1)),
         text = element_text(family = "Roboto"),
         legend.position = c(0.3, 0.9),
         legend.direction = "horizontal",
         legend.background = element_rect(fill = NA),
         legend.key = element_rect(fill = "black",
                                   color = NA),
         legend.text = element_text(color = "white",
                                    size = 11),
         axis.text.x = element_text(color = "white",
                                    size = 12),
         axis.text.y = element_text(color = "white",
                                    size = 12),
         axis.title.x = element_textbox_simple(color = "white"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/region-pos-line-{data_date}.png")
ggsave(plot_path, plot = mw_pos_line, dpi = "print", width = 33, height = 20, units = "cm")



# deaths line chart
# same thing
mw_dea_line <- ggplot(dea_chart_dat, aes(x = days, y = deaths, color = state)) + 
   geom_line() + 
   geom_point() +
   scale_y_log10() +
   # needed to provide space to ggforce labels
   expand_limits(y = max(pos_chart_dat$deaths)*nrow(pos_chart_dat)*0.05,
                 x = max(pos_chart_dat$days)+(nrow(pos_chart_dat)*0.02)) +
   labs(x = "Number of days since a total of 5 <b style='color:#BE454F'>deaths</b> first recorded", y = NULL,
        title = "Regional COVID-19 <b style='color:#BE454F'>Cumulative Deaths</b>",
        subtitle = glue("Last updated: {data_date}"),
        caption = "Source: The New York Times, based on reports from state and local health agencies") +
   scale_color_manual(guide = FALSE, values = c(trippy[[6]], kind[[2]], haze[[7]], for_floor[[3]], queen[[5]])) +
   ggforce::geom_mark_circle(aes(
      x = days, y = deaths, group = state,
      description = desc),
      data = dea_mark_circle_dat,
      expand = -0.1, radius = 0.01,
      con.colour = deep_rooted[[7]],
      label.buffer = unit(6, "mm"),
      label.colour = "white",
      label.fill = deep_rooted[[7]],
      color = deep_rooted[[7]]) +
   theme(plot.title = element_textbox_simple(size = rel(1.5),
                                             color = "white"),
         plot.subtitle = element_text(size = rel(1),
                                      color = "white"),
         plot.caption = element_text(color = "white",
                                     size = rel(0.95)),
         text = element_text(family = "Roboto"),
         legend.position = "none",
         axis.text.x = element_text(color = "white",
                                    size = 12),
         axis.text.y = element_text(color = "white",
                                    size = 12),
         axis.title.x = element_textbox_simple(color = "white"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/region-dea-line-{data_date}.png")
ggsave(plot_path, plot = mw_dea_line, dpi = "print", width = 33, height = 20, units = "cm")

