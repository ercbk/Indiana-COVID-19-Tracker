# Instantaneous Effective Reproduction Number Estimation

# Notes:
# 1. Values for the serial interval, mean and standard deviation, taken from an example used in Tim Church's blog post. He got it from a Chinese paper.
# 2. facet_zoom doesn't like tsibbles and gives a funky error, so make sure you convert to df or tibble.
# 3. see comment in plot for details on labels drawing only in zoomed area
# 4. Updated si parameters: nature apr 15 paper, https://www.nature.com/articles/s41591-020-0869-5, gives si mean = 5.8 w/ 95% CI (4.8, 6.8), n = 77. Don't know how to get the sd for Gamma distr using mean and CIs though.



# pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, ggtext, glue, EpiEstim)
pacman::p_load(extrafont, swatches, dplyr, ggplot2, ggtext, glue)

# nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv")

rtlive_dat <- readr::read_csv("https://d14wlfuexuxgcm.cloudfront.net/covid/rt.csv")

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
trippy <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Trippy.ase"))


r_chart_dat <- rtlive_dat %>% 
  filter(region == "IN") %>% 
  mutate(mean = round(mean, 2),
         label = as.character(mean) %>% 
                      paste("R[e] ==", .))

# current data date
data_date <- r_chart_dat %>%
  summarize(date = max(date)) %>%
  pull(date)


zoom_yupper <- r_chart_dat %>%
  filter(date == (max(date)-7)) %>%
  summarize(upper_y = max(mean)*1.5) %>%
  pull(upper_y)



r_chart <- ggplot(r_chart_dat, aes(x = date, y = mean)) +
  geom_point(color = trippy[[7]]) +
  geom_line(color = trippy[[7]]) +
  geom_ribbon(aes(ymin = lower_80, ymax = upper_80),
              fill = trippy[[7]], alpha = 0.40) +
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
             aes(label = label, vjust = "top"),
             family="Roboto", fill = "black",
             size = 4, nudge_y = 0.10, parse = T,
             label.size = 0, color="white") +
  labs(x = NULL, y = NULL,
       title = "Estimated daily effective reproduction number",
       subtitle = glue("Last updated: {data_date}"),
       caption = "Source: rt.live"
  ) +
  theme(
    legend.position = 'none',
    plot.title = element_text(color = "white",
                              family = "Roboto",
                              size = 16),
    plot.subtitle = element_text(color = "white",
                                 family = "Roboto",
                                 size = 14),
    plot.caption = element_text(color = "white",
                                size = 12,
                                family = "Roboto"),
    text = element_text(family = "Roboto"),
    axis.text.x = element_text(color = "white",
                               size = 12),
    axis.text.y = element_text(color = "white",
                               size = 12,
                               margin = margin(l = 18)),
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
ggsave(plot_path, plot = r_chart,
       dpi = "screen", width = 33, height = 20,
       units = "cm", device = ragg::agg_png())
