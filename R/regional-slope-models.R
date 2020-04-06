# regional slope estimation

# Fits and visualizes log-linear models for positive cases and deaths for states in Indiana's local region.

# Sections
# 1. Set-up
# 2. Process data
# 3. Models
# 4. Chart data
# 5. Line charts




########################
# Set-up
########################


pacman::p_load(extrafont, swatches, dplyr, tsibble, fable, ggplot2, ggtext, glue)

deep_rooted <- swatches::read_palette("palettes/Deep Rooted.ase")
eth_mat <- swatches::read_palette("palettes/Ethereal Material.ase")
for_floor <- swatches::read_palette("palettes/Forest Floor.ase")
trippy <- swatches::read_palette("palettes/trippy.ase")

loadfonts()

# remove scientific notations
options(scipen=999)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv")

midwest_dat <- nyt_dat %>%
      filter(state %in% c("Indiana", "Kentucky", "Ohio", "Michigan", "Illinois")) %>%
   group_by(state, date) %>% 
   summarize(positives = sum(cases),
             deaths = sum(deaths)) %>% 
   as_tsibble(index = "date", key = "state")

data_date <- midwest_dat %>% 
   as_tibble() %>%
   summarize(date = max(date)) %>% 
   pull(date)




########################
# Process data
########################


pos_days_lengths <- midwest_dat %>% 
   filter(positives >= 100) %>%
   as_tibble() %>% 
   group_by(state) %>% 
   count(state) %>% 
   pull(n)
pos_days <- purrr::map_dfr(pos_days_lengths, function(x) seq(1:x) %>% as_tibble()) %>% rename(days = value)

pos_chart_dat <- midwest_dat %>% 
   filter(positives >= 100) %>% 
   bind_cols(pos_days)


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


mw_pos_models <- midwest_dat %>% 
   model(log_mod = TSLM(log(positives) ~ trend())) %>% 
   mutate(coef_info = purrr::map(log_mod, broom::tidy)) %>% 
   tidyr::unnest(coef_info) %>% 
   filter(term == "trend()") %>% 
   mutate(estimate = exp(estimate))

mw_dea_models <- midwest_dat %>% 
   filter(deaths != 0) %>% 
   model(log_mod = TSLM(log(deaths) ~ trend())) %>% 
   mutate(coef_info = purrr::map(log_mod, broom::tidy)) %>% 
   tidyr::unnest(coef_info) %>% 
   filter(term == "trend()") %>% 
   mutate(estimate = exp(estimate))




########################
# Chart data
########################


# positives
pos_lbl_dat <- mw_pos_models %>% 
   select(state, estimate) %>% 
   mutate(estimate = round((estimate - 1)*100, 1),
          est_text = ifelse(estimate > 0, as.character(estimate) %>% paste0("+", ., "% per day"),  as.character(estimate)))


pos_mi_lbl <- glue("Michigan
                   Estimated slope:
                   {pos_lbl_dat$est_text[[4]]}")
pos_in_lbl <- glue("Indiana
                   Estimated slope:
                   {pos_lbl_dat$est_text[[2]]}")
pos_il_lbl <- glue("Illinois
                   Estimated slope:
                   {pos_lbl_dat$est_text[[1]]}")
pos_oh_lbl <- glue("Ohio
                   Estimated slope:
                   {pos_lbl_dat$est_text[[5]]}")
pos_ky_lbl <- glue("Kentucky
                   Estimated slope:
                   {pos_lbl_dat$est_text[[3]]}")

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
dea_lbl_dat <- mw_dea_models %>% 
   select(state, estimate) %>% 
   mutate(estimate = round((estimate - 1)*100, 1),
          est_text = case_when(estimate > 0 ~ as.character(estimate) %>% paste0("+", ., "% per day"), estimate < 0 ~ as.character(estimate) %>% paste0("-", ., "% per day"), TRUE ~ as.character(estimate)),
          )


dea_mi_lbl <- glue("Michigan
                   Estimated slope:
                   {dea_lbl_dat$est_text[[4]]}")
dea_in_lbl <- glue("Indiana
                   Estimated slope:
                   {dea_lbl_dat$est_text[[2]]}")
dea_il_lbl <- glue("Illinois
                   Estimated slope:
                   {dea_lbl_dat$est_text[[1]]}")
dea_oh_lbl <- glue("Ohio
                   Estimated slope:
                   {dea_lbl_dat$est_text[[5]]}")
dea_ky_lbl <- glue("Kentucky
                   Estimated slope:
                   {dea_lbl_dat$est_text[[3]]}")

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




########################
# Line charts
########################


# positive test cases
mw_pos_line <- ggplot(pos_chart_dat, aes(x = days, y = positives, color = state)) + 
   geom_line() + 
   geom_point() +
   scale_y_log10() +
   # needed to provide space to ggforce labels
   expand_limits(y = max(pos_chart_dat$positives)*2.5) +
   labs(x = "Number of days since 100 <b style='color:#B28330'>positive cases</b> first recorded", y = NULL,
        title = "Regional COVID-19 <b style='color:#B28330'>Positive Test Results</b>",
        subtitle = glue("Last updated: {data_date}"),
        caption = "Source: The New York Times, based on reports from state and local health agencies") +
   scale_color_manual(guide = FALSE, values = c(trippy[[6]], eth_mat[[1]], for_floor[[3]], trippy[[1]], trippy[[3]])) +
   ggforce::geom_mark_circle(aes(
      x = days, y = positives, group = state,
      description = desc),
      data = pos_mark_circle_dat,
      expand = -0.1, radius = 0.01,
      con.colour = deep_rooted[[7]],
      label.buffer = unit(6, "mm"),
      label.colour = "white",
      label.fill = deep_rooted[[7]],
      color = deep_rooted[[7]]) +
   geom_text(data = tibble(x = 2.76224962490622,
                               y = 33322.4114933286,
                               label = latex2exp::TeX("$\\log(positives) = \\beta_0 + slope*date + \\epsilon_{date}$")),
             mapping = aes(x = x,
                           y = y,
                           label = label),
             size = 3.86605783866058,
             angle = 0L,
             lineheight = 1L,
             hjust = 0.5,
             vjust = 0.5,
             colour = "white",
             parse = TRUE,
             family = "sans",
             fontface = "plain",
             inherit.aes = FALSE,
             show.legend = FALSE) +
   theme(plot.title = element_textbox_simple(size = rel(1.5),
                                             color = "white"),
         plot.subtitle = element_text(size = rel(0.95),
                                      color = "white"),
         plot.caption = element_text(color = "white",
                                     size = rel(1)),
         text = element_text(family = "Roboto"),
         legend.position = "none",
         axis.text.x = element_text(color = "white"),
         axis.text.y = element_text(color = "white"),
         axis.title.x = element_textbox_simple(color = "white"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))



plot_path <- glue("plots/region-pos-line-{data_date}.png")
ggsave(plot_path, plot = mw_pos_line, dpi = "print", width = 33, height = 20, units = "cm")



# deaths line chart

mw_dea_line <- ggplot(dea_chart_dat, aes(x = days, y = deaths, color = state)) + 
   geom_line() + 
   geom_point() +
   scale_y_log10() +
   # needed to provide space to ggforce labels
   expand_limits(y = max(dea_chart_dat$deaths)*2.5) +
   labs(x = "Number of days since 5 <b style='color:#BE454F'>deaths</b> first recorded", y = NULL,
        title = "Regional COVID-19 <b style='color:#BE454F'>Deaths</b>",
        subtitle = glue("Last updated: {data_date}"),
        caption = "Source: The New York Times, based on reports from state and local health agencies") +
   scale_color_manual(guide = FALSE, values = c(trippy[[6]], eth_mat[[1]], for_floor[[3]], trippy[[1]], trippy[[3]])) +
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
   geom_text(data = tibble(x = 2.76224962490622,
                           y = (max(dea_chart_dat$deaths)*2.5)*0.95,
                           label = latex2exp::TeX("$\\log(deaths) = \\beta_0 + slope*date + \\epsilon_{date}$")),
             mapping = aes(x = x,
                           y = y,
                           label = label),
             size = 3.86605783866058,
             angle = 0L,
             lineheight = 1L,
             hjust = 0.5,
             vjust = 0.5,
             colour = "white",
             parse = TRUE,
             family = "sans",
             fontface = "plain",
             inherit.aes = FALSE,
             show.legend = FALSE) +
   theme(plot.title = element_textbox_simple(size = rel(1.5),
                                             color = "white"),
         plot.subtitle = element_text(size = rel(1),
                                      color = "white"),
         plot.caption = element_text(color = "white",
                                     size = rel(0.95)),
         text = element_text(family = "Roboto"),
         legend.position = "none",
         axis.text.x = element_text(color = "white"),
         axis.text.y = element_text(color = "white"),
         axis.title.x = element_textbox_simple(color = "white"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


plot_path <- glue("plots/region-dea-line-{data_date}.png")
ggsave(plot_path, plot = mw_dea_line, dpi = "print", width = 33, height = 20, units = "cm")

