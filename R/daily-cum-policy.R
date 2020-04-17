# Daily cases vs Cumulative Cases

# When line startes going vertical, it indicates the disease spread is coming under control.

pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, ggtext, glue)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv")

state_policy <- readr::read_csv(glue("{rprojroot::find_rstudio_root_file()}/data/covid-state-policy-database-boston-univ.csv"))

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))

deep_light <- prismatic::clr_lighten(deep_rooted, shift = 0.25)


cases_dat <- nyt_dat %>% 
      filter(state == "Indiana") %>% 
      as_tsibble(index = "date") %>% 
      mutate(daily_cases = difference(cases),
             daily_cases = tidyr::replace_na(daily_cases, 1)) %>% 
      rename(cumulative_cases = cases)


data_date <- cases_dat %>% 
   as_tibble() %>%
   summarize(date = max(date)) %>% 
   pull(date)


policy_dat <- state_policy %>% 
   filter(State == "Indiana") %>% 
   select(2, 3, 6, 7, 11, 12, 13, 14) %>% 
   tidyr::pivot_longer(cols = everything(), names_to = "policy", values_to = "date") %>% 
   mutate(date_text = date,
          date = lubridate::mdy(date),
          policy = stringr::str_replace(policy,
                                        pattern = "Date c",
                                        replacement = "C"))
   


# policy label data
# inner_join only keeps dates with a policy
# aggregate merges rows in policy that have same values in the other columns.
label_dat <- cases_dat %>% 
      as_tibble() %>% 
      inner_join(policy_dat, by = "date") %>% 
      select(-deaths, -fips, -state) %>% 
      filter(!policy %in% c("Closed movie theaters", "Closed gyms", "Froze evictions")) %>% 
      aggregate(data = .,
                policy ~ date + cumulative_cases + daily_cases,
                FUN = paste0, collapse = "\n") %>% 
   mutate(hjust = c(-0.2, -0.25, 1.3, 1),
          vjust = c(-7, 2, -1.32, -2.3))



arw <- arrow(length = unit(6, "pt"), type = "closed")


pos_policy_line <- ggplot(cases_dat, aes(x = cumulative_cases, y = daily_cases+1)) +
      geom_point(color = "#B28330") +
      geom_line(color = "#B28330") +
   expand_limits(y = 1000) +
   scale_x_log10(breaks = c(0, 10, 100, 1000, 10000),
                 labels = c("0", "10", "100", "1,000", "10,000")) +
   scale_y_log10(breaks = c(1,11,101,1001),
                 labels = c("0", "10", "100", "1,000")) +
   geom_label(aes(x=0, y=1000, label="Daily Cases"),
              family="Roboto", fill = "black",
              size=4, hjust=0, label.size=0, color="white") +
   geom_label(data=label_dat, aes(x = cumulative_cases, y = daily_cases, label= policy, hjust = hjust, vjust = vjust),
              family="Roboto", lineheight=0.95,
              size=4.5, label.size=0,
              color = "white", fill = "black") +
   geom_curve(
      data = data.frame(), aes(x = 1.2, xend = 0.96, yend = 2.7, y = 5.7), 
      color = deep_light[[7]], arrow = arw
   ) +
   geom_curve(
      data = data.frame(), aes(x = 110, xend = 25, yend = 4.5, y = 2.6), 
      color = deep_light[[7]], arrow = arw,
      curvature = -0.70
   ) +
   geom_curve(
      data = data.frame(), aes(x = 20, xend = 53, yend = 26, y = 36), 
      color = deep_light[[7]], arrow = arw,
      curvature = -0.70
   ) +
   geom_segment(
      data = data.frame(), aes(x = 110, xend = 300, yend = 126, y = 260),
      color = deep_light[[7]], arrow = arw
   ) +
   labs(x = "Cumulative Cases", y = NULL,
        title = "Daily <b style='color:#B28330'>Positive Test Results</b> vs. Cumulative <b style='color:#B28330'>Positive Test Results</b>",
        subtitle = glue("Last updated: {data_date}"),
        caption = "Source: The New York Times, based on reports from state and local health agencies\nJulia Raifman,  Kristen Nocka, et al at Boston University") +
   theme(plot.title = element_textbox_simple(size = rel(1.5),
                                             color = "white",
                                             family = "Roboto"),
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


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/pos-policy-line-{data_date}.png")

ggsave(plot_path, plot = pos_policy_line, dpi = "print", width = 33, height = 20, units = "cm")
# 11, 14, 19th value

