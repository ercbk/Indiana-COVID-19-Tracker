# Instantaneous Effective Reproduction Number Estimation

# Notes:
# 1. Values for the serial interval mean and standard deviation taken an example used in Tim Church's blog post. He got it from a Chinese paper.
# 2. facet_zoom doesn't like tsibbles and gives a funky error, so make sure you convert to df or tibble.
# 3. see comment in plot for details on labels drawing only in zoomed area



pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, ggtext, glue, EpiEstim)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv")

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
trippy <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Trippy.ase"))



# daily counts of positive cases
# EpiEstim pkg expects certain column names for models
ind_incidence <- nyt_dat %>% 
      filter(state == "Indiana") %>% 
      as_tsibble(index = "date") %>% 
      mutate(I = difference(cases),
             I = tidyr::replace_na(I, 1)) %>% 
      select(dates = date, I)

# current data date
data_date <- ind_incidence %>% 
      as_tibble() %>%
      summarize(dates = max(dates)) %>% 
      pull(dates)


# calc effective reproduction number
ind_res_parametric_si <- estimate_R(ind_incidence, 
                                      method = "parametric_si",
                                    config = make_config(
                                      list(mean_si = 7.5,
                                           std_si = 3.4))
                                    )


# getting the point est, and 95% credible intervals
r_chart_dat <- ind_incidence %>% 
  slice(-1:-7) %>% 
  bind_cols(ind_res_parametric_si$R) %>% 
  select(date = dates, estimate = `Mean(R)`,
         upper = `Quantile.0.975(R)`, lower = `Quantile.0.025(R)`) %>% 
  mutate(estimate = round(estimate, 2),
         label = as.character(estimate) %>% 
           paste("R[e] ==", .)) %>% 
  as_tibble()

zoom_yupper <- r_chart_dat %>% 
  filter(date == (max(date)-7)) %>% 
  summarize(upper_y = max(estimate)*1.5) %>% 
  pull(upper_y)



r_chart <- ggplot(r_chart_dat, aes(x = date, y = estimate)) +
  geom_point(color = trippy[[7]]) +
  geom_line(color = trippy[[7]]) +
  # hates tsibbles, data needs to be a tibble or df
  # zoom.data = zoom needed to only add label to zoomed area
  ggforce::facet_zoom(x = date > (max(date)-7),
                      ylim = c(0.5, zoom_yupper),
                      zoom.data = zoom,
                      zoom.size = 1.5,
                      show.area = FALSE,
                      horizontal = FALSE) +
  # adding zoom = TRUE col tells facet_zoom to only draw label in zoom area
  geom_label(data = r_chart_dat %>% 
               filter(date == max(date)) %>% 
               mutate(zoom = TRUE),
             aes(label = label),
             family="Roboto", fill = "black",
             size = 4, nudge_y = 0.20, parse = T,
             label.size = 0, color="white") +
  labs(x = NULL, y = NULL,
       title = "Estimated daily effective reproduction number",
       subtitle = glue("Last updated: {data_date}"),
       caption = "*Daily effective reproduction number calculated over a 7 day window\nSource: The New York Times, based on reports from state and local health agencies"
       ) +
  theme(
    legend.position = 'none',
    plot.title = element_text(color = "white",
                                        family = "Roboto"),
    plot.subtitle = element_text(color = "white",
                                           family = "Roboto"),
    plot.caption = element_text(color = "white",
                                size = rel(1),
                                family = "Roboto"),
    text = element_text(family = "Roboto"),
    axis.text.x = element_text(color = "white",
                               size = 12),
    axis.text.y = element_text(color = "white",
                               size = 12),
    axis.title.y = element_text(color = "white"),
    panel.background = element_rect(fill = "black",
                                    color = NA),
    plot.background = element_rect(fill = "black",
                                   color = NA),
    panel.border = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(color = deep_rooted[[7]])
    
  )


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/daily-re-line-{data_date}.png")
ggsave(plot_path, plot = r_chart, dpi = "print", width = 33, height = 20, units = "cm")
