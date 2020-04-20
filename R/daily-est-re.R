# Instantaneous Effective Reproduction Number Estimation






pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, ggtext, glue, EpiEstim)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv")

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
trippy <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Trippy.ase"))

deep_light <- prismatic::clr_lighten(deep_rooted, shift = 0.35)



ind_incidence <- nyt_dat %>% 
      filter(state == "Indiana") %>% 
      as_tsibble(index = "date") %>% 
      mutate(I = difference(cases),
             I = tidyr::replace_na(I, 1)) %>% 
      select(dates = date, I)


data_date <- ind_incidence %>% 
      as_tibble() %>%
      summarize(dates = max(dates)) %>% 
      pull(dates)


ind_res_parametric_si <- estimate_R(ind_incidence, 
                                      method = "parametric_si", config = make_config(list(mean_si = 7.5, 
                                                                                          std_si = 3.4)))

r_chart_dat <- ind_incidence %>% 
  slice(-1:-7) %>% 
  bind_cols(ind_res_parametric_si$R) %>% 
  select(date = dates, estimate = `Mean(R)`,
         upper = `Quantile.0.975(R)`, lower = `Quantile.0.025(R)`) %>% 
  mutate(estimate = round(estimate, 2)) %>% 
  as_tibble()

zoom_yupper <- r_chart_dat %>% 
  filter(date == (max(date)-7)) %>% 
  summarize(upper_y = max(estimate)*1.5) %>% 
  pull(upper_y)



r_chart <- ggplot(r_chart_dat, aes(x = date, y = estimate)) +
  geom_point(color = trippy[[7]]) +
  geom_line(color = trippy[[7]]) +
  ggforce::facet_zoom(x = date > (max(date)-7),
                      ylim = c(0.5, zoom_yupper),
                      zoom.data = zoom,
                      zoom.size = 1.5,
                      show.area = FALSE,
                      horizontal = FALSE) +
  geom_label(data = r_chart_dat %>% 
               filter(date == max(date)) %>% 
               mutate(zoom = TRUE),
             aes(label = estimate %>%
                   as.character() %>% 
                   paste("R = ", .)),
             family="Roboto", fill = "black",
             size = 4, nudge_y = 0.20,
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
