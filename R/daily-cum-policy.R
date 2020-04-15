# Daily cases vs Cumulative Cases

# When line startes going vertical, it indicates the disease spread is coming under control.

pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, ggtext, glue)

nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv")

state_policy <- readr::read_csv("data/covid-state-policy-database-boston-univ.csv")


cases_dat <- nyt_dat %>% 
      filter(state == "Indiana") %>% 
      as_tsibble(index = "date") %>% 
      mutate(daily_cases = difference(cases),
             daily_cases = tidyr::replace_na(daily_cases, 1)) %>% 
      rename(cumulative_cases = cases)

policy_dat <- state_policy %>% 
      filter(State == "Indiana") %>% 
      select(2, 3, 6, 7, 11, 12, 13, 14) %>% 
      tidyr::pivot_longer(cols = everything(), names_to = "policy", values_to = "date") %>% 
      mutate(date = stringr::str_remove_all(date, "/") %>%
                   as.numeric(.) %>% 
                   lubridate::as_date(.))


pos_log_line <- ggplot(cases_dat, aes(x = cumulative_cases, y = daily_cases)) + 
      geom_line() + 
      geom_point() +
      scale_y_log10() +
      scale_x_log10()
pos_log_line
