# Counties

# Fits and visualizes log-linear models to positive cases for  Indiana counties.

# Notes
# 1. Going to ranking counties by rate of positive cases. Limiting to counties with > 5 positive cases for longer than a week. Want to try and smooth out any large rate jumps due to a spike in increased testing. Will probably need to adjust this in future.





# Set-up

pacman::p_load(extrafont, dplyr, tsibble, fable, ggplot2, ggtext, glue)

palette <- pals::brewer.oranges(100)
loadfonts()

# remove scientific notations
options(scipen=999)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv")



# Process data

counties_dat <- nyt_dat %>%
      filter(state == "Indiana") %>%
      group_by(county, date) %>% 
      summarize(positives = sum(cases),
                deaths = sum(deaths)) %>% 
      as_tsibble(index = "date", key = "county")

data_date <- counties_dat %>% 
      as_tibble() %>%
      summarize(date = max(date)) %>% 
      pull(date)


# counties that have had at least 5 positive cases for a week
chosen_counties <- counties_dat %>% 
      filter(positives >= 5) %>%
      as_tibble() %>% 
      group_by(county) %>% 
      count(county) %>% 
      filter(n > 7) %>% 
      pull(county)


# Models
county_pos_models <- counties_dat %>%
      filter(county %in% chosen_counties) %>% 
      model(log_mod = TSLM(log(positives) ~ trend())) %>% 
      mutate(coef_info = purrr::map(log_mod, broom::tidy)) %>% 
      tidyr::unnest(coef_info) %>% 
      filter(term == "trend()") %>% 
      mutate(estimate = exp(estimate))


# Labels
pos_lbl_dat <- county_pos_models %>% 
      select(county, estimate) %>% 
      mutate(pos_estimate = round((estimate - 1)*100, 1),
             pos_est_text = as.character(pos_estimate) %>% 
                   paste0(., "%")) %>% 
      select(-estimate)

# Chart data
pos_bar_dat <- counties_dat %>% 
      filter(county %in% chosen_counties,
             date == max(date)) %>% 
      left_join(pos_lbl_dat, by = "county") %>% 
      ungroup() %>% 
      mutate(county = as.factor(county)) %>% 
      top_n(20, wt = pos_estimate)




county_pos_bar <- ggplot(pos_bar_dat, aes(y = reorder(county, pos_estimate), x = pos_estimate)) +
      geom_col(aes(fill = pos_estimate)) +
      expand_limits(x = max(pos_bar_dat$pos_estimate)*1.05) +
      geom_text(aes(label = pos_est_text), hjust = -0.3,  size = 4, color = "white", fontface = "bold") +
      geom_text(aes(label = positives), hjust = 1.3,  size = 4, color = "black", fontface = "bold") +
      scale_fill_gradientn(colors = palette,
                           guide = 'none') +
      labs(x = NULL, y = NULL,
           title = "Estimated change in <b style='color:#B28330'>cumulative positive tests</b> per day",
           subtitle = glue("Last updated: {data_date}\nNumber of positive tests in black"),
           caption = "*Limited to counties with more than 5 positive cases for longer than a week in order\n to smooth out any large rate jumps due to spikes in testing.\nSource: The New York Times, based on reports from state and local health agencies") +
      theme(plot.title = element_textbox_simple(size = rel(1.5),
                                                color = "white"),
            plot.subtitle = element_text(size = rel(1),
                                         color = "white"),
            plot.caption = element_text(color = "white",
                                        size = rel(1)),
            text = element_text(family = "Roboto"),
            axis.ticks = element_blank(),
            axis.text.x = element_blank(),
            # axis.title.x = element_textbox_simple(color = "white"),
            axis.text.y = element_text(color = "white",
                                       size = 11),
            panel.background = element_rect(fill = "black",
                                            color = NA),
            plot.background = element_rect(fill = "black",
                                           color = NA),
            panel.border = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank())


plot_path <- glue("plots/county-pos-bar-{data_date}.png")
ggsave(plot_path, plot = county_pos_bar, dpi = "print", width = 33, height = 20, units = "cm")
