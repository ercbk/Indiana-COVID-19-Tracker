# Daily positive tests' growith rates comparison

# Comparison between states with similar population densitives as Indiana

# from Hyndman article on comparing COVID-19 interventions, https://robjhyndman.com/hyndsight/logratios-covid19/




pacman::p_load(extrafont, swatches, dplyr, tsibble, fable, ggplot2, ggtext, glue)

deep_rooted <- swatches::read_palette("palettes/Deep Rooted.ase")
for_floor <- swatches::read_palette("palettes/Forest Floor.ase")
trippy <- swatches::read_palette("palettes/trippy.ase")
kind <- swatches::read_palette("palettes/Kindred Spirits.ase")

# remove scientific notations
options(scipen=999)

# ggrepel is random
set.seed(2020)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv")



density_dat <- nyt_dat %>%
   filter(state %in% c("Indiana", "Georgia", "Michigan")) %>%
   group_by(state, date) %>% 
   summarize(positives = sum(cases),
             deaths = sum(deaths)) %>% 
   as_tsibble(index = "date", key = "state")


# current date of data
data_date <- density_dat %>% 
   as_tibble() %>%
   summarize(date = max(date)) %>% 
   pull(date)


# slope of a log curve is the same as the log of the ratios of successive values
pos_lor_dat <- density_dat %>%
   mutate(pos_logratio = difference(log(positives)),
          pos_doub = log(2)/pos_logratio) %>%
   filter(date >= "2020-03-21")


# coordinates for labeling loess curves
pos_lbl_dat <- pos_lor_dat %>% 
   mutate(date = as.numeric(date)) %>% 
   group_by(state) %>% 
   tidyr::nest() %>%
   mutate(preds = purrr::map(data, function(d) {
      mod <- loess(pos_logratio ~ date, data = d)
      preds <- predict(mod, newdata = min(as.numeric(d$date)))
   })) %>% 
   bind_cols(date = as.Date(rep("2020-03-21", 3))) %>%
   ungroup() %>% 
   mutate(state = as.factor(state),
          preds = as.numeric(preds)) %>% 
   select(state, preds, date)
   

pos_lor_line <- ggplot(data = pos_lor_dat,
                       aes(x = date, y = pos_logratio,
                           col = state)) +
   geom_hline(yintercept = log(2)/c(2:7,14,21),
              col = deep_rooted[[7]],
              lty = "1f",
              alpha = 10
   ) +
   geom_smooth(formula = y ~ x, aes(group = state),
               method = "loess", se = FALSE,
               span = 0.38) +
   ggrepel::geom_text_repel(data = pos_lbl_dat, 
                             aes(x = date, y = preds, 
                                 label = state,
                                 group = state),
                            direction = "y",
                            point.padding = unit(3, "mm"),
                            segment.colour = NA) +
   scale_y_continuous(breaks = log(1+seq(0,60,by=10)/100),
                      labels = paste0(seq(0,60,by=10),"%"),
                      minor_breaks = NULL,
                      sec.axis = sec_axis(~ log(2)/(.),
                                          breaks = c(2:7,14,21),
                                          name = "Doubling time (days)")
   ) +
   scale_x_date(date_breaks = "2 days",
                date_labels = "%b %d") +
   scale_color_manual(guide = FALSE, values = c(trippy[[4]], kind[[2]], for_floor[[3]])) +
   labs(x = NULL, y = NULL,
        title = "Daily changes in cumulative <b style='color:#B28330'>positive tests</b> of states with similar population densities",
        subtitle = glue("Last updated: {data_date}"),
        caption = "Curves fitted using LOESS regression\nSource: The New York Times, based on reports from state and local health agencies") +
   theme(
      legend.position = 'none',
      plot.title = element_textbox_simple(color = "white"),
      plot.subtitle = element_textbox_simple(color = "white"),
      plot.caption = element_text(color = "white",
                                  size = rel(1)),
      text = element_text(family = "Roboto"),
      axis.text.x = element_text(color = "white"),
      axis.text.y = element_text(color = "white"),
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

plot_path <- glue("plots/density-pos-line-{data_date}.png")
ggsave(plot_path, plot = pos_lor_line, dpi = "print", width = 33, height = 20, units = "cm")


