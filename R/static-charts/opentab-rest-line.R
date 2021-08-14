# OpenTable's State of the restaurant industry
# Visualizing the effects of COVID-19 on the restaurant industry


# Notes
# 1. The regular RSelenium server shutdown method isn't working. Github issue is recent-ish, so might not be a problem for long.
# 2. There will be a problem if the Github actions runner gets updated from Ubuntu 18.04 to 20.04. Will need to change chrome driver version to the newer version. See https://github.com/actions/virtual-environments/tree/master/images/linux



# Set-up
pacman::p_load(extrafont, swatches, dplyr, lubridate, purrr, ggplot2, glue, ggtext, patchwork)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
canyon <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Grand Canyon.ase"))



rest_dat_raw <- readr::read_csv(glue("{rprojroot::find_rstudio_root_file()}/data/YoY_Seated_Diner_Data.csv"))

# pivot date cols to a single col and clean; add weekend col
region_rest <- rest_dat_raw %>% 
   filter(Name %in% c("Indiana", "Illinois", "Michigan",
                      "Ohio", "Kentucky", "Missouri")) %>%
   select(-Type) %>% 
   tidyr::pivot_longer(cols = -Name,
                       names_to = "date",
                       values_to = "pct_diff") %>% 
   mutate(date = stringr::str_remove_all(date, "_1"),
          date = stringr::str_replace_all(date,
                                          pattern = "/",
                                          replacement = "-"),
          pct_diff = stringr::str_remove_all(pct_diff, "%") %>% 
             as.numeric()) %>% 
   group_by(Name) %>% 
   mutate(id = row_number(),
          date = lubridate::ymd(date),
          weekend = timeDate::isWeekend(date),
          pct_diff = pct_diff/100) %>% 
   ungroup() %>% 
   arrange(Name, date) %>% 
   select(-id)


# current date of data
data_date <- region_rest %>%
   summarize(date = max(date)) %>% 
   pull(date)

# data for indiana_chart
ind_chart_dat <- region_rest %>% 
   filter(Name == "Indiana")

# current percent difference value for Indiana (horizontal line)
ind_index <- region_rest %>% 
   filter(Name == "Indiana",
          date == max(date))

# upper limit for y-axis
y_upper <- region_rest %>%
   summarize(pct_diff = max(pct_diff, na.rm = TRUE)) %>%
   pull(pct_diff)


# creates plots for each state; keeps x axis for bottom level (patchwork) charts
gen_plots <- function(data, Name) {
   p <- ggplot(data = data, aes(x = date, y = pct_diff, group = Name)) + 
      geom_line(color = "#5a9dc4") +
      # geom_vline(data = data %>% 
      #               filter(weekend == TRUE),
      #            aes(xintercept = date),
      #            color = "#755c99",size = 1.5, alpha = 0.1) +
      ggrepel::geom_label_repel(data = data %>% 
                                   filter(date == max(date)),
                                aes(label = scales::percent(pct_diff, accuracy = 1)),
                                    color = "#5a9dc4", fill = "black",
                                nudge_x = .02, nudge_y = .40,
                                segment.color = NA, label.size = NA) +
      geom_hline(data = ind_index, 
                 aes(yintercept = pct_diff),
                 color = "#c47e5a", linetype = 8) +
      expand_limits(x = max(data$date)+2,
                    y = y_upper * 1.05) +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
      scale_x_date(date_labels = "%b") +
      labs(title = Name)
   if (Name == "Michigan" | Name == "Ohio" | Name == "Missouri"){
      p + theme(plot.title = element_text(color = "white",
                                          family = "Roboto"),
                text = element_text(family = "Roboto"),
                legend.position = "none",
                axis.text.x = element_text(color = "white",
                                           size = 11),
                axis.text.y = element_text(color = "white",
                                           size = 11),
                panel.background = element_rect(fill = "black",
                                                color = NA),
                plot.background = element_rect(fill = "black",
                                               color = NA),
                
                panel.border = element_blank(),
                panel.grid.minor = element_blank(),
                panel.grid.major = element_line(color = deep_rooted[[7]]))
   } else {
      p + theme(plot.title = element_text(color = "white",
                                          family = "Roboto"),
                text = element_text(family = "Roboto"),
                legend.position = "none",
                axis.text.x = element_blank(),
                axis.text.y = element_text(color = "white",
                                           size = 11),
                panel.background = element_rect(fill = "black",
                                                color = NA),
                plot.background = element_rect(fill = "black",
                                               color = NA),
                
                panel.border = element_blank(),
                panel.grid.minor = element_blank(),
                panel.grid.major = element_line(color = deep_rooted[[7]]))
   }
}

# Illinois, Michigan, Ohio, Missouri, Kentucky
region_plots <- region_rest %>%
   filter(Name != "Indiana") %>%
   group_by(Name) %>% 
   tidyr::nest() %>% 
   mutate(plots = map2(data, Name, ~gen_plots(.x, .y)))

# Indiana chart
indy_chart <- ggplot(data = ind_chart_dat, aes(x = date, y = pct_diff)) + 
   geom_line(color = canyon[[7]]) +
   # geom_vline(data = ind_chart_dat %>% 
   #               filter(weekend == TRUE),
   #            aes(xintercept = date),
   #            color = "#755c99",size = 1.5, alpha = 0.1) +
   expand_limits(x = max(ind_chart_dat$date)+2,
                 y = y_upper * 1.05) +
   ggrepel::geom_label_repel(data = ind_chart_dat %>% 
                                filter(date == max(date)),
                             aes(label = scales::percent(pct_diff, accuracy = 1),
                                 color = Name), fill = "black",
                             nudge_x = .02, nudge_y = .40,
                             segment.color = NA, label.size = NA) +
   scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
   labs(x = NULL, y = NULL,
        title = "<b style='color:#c47e5a'>Indiana</b>") +
   theme(plot.title = element_textbox_simple(family = "Roboto"),
         text = element_text(family = "Roboto"),
         legend.position = "none",
         axis.text.x = element_blank(),
         axis.text.y = element_text(color = "white",
                                    size = 11),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


caption_text <- glue("Last updated: {data_date}
                  Source: OpenTable The state of the restaurant industry")

# patchwork goodness
all_charts <- indy_chart + region_plots$plots[[1]] + region_plots$plots[[2]] + region_plots$plots[[3]] + region_plots$plots[[4]] + region_plots$plots[[5]] + 
   plot_annotation(title = "How COVID-19 is affecting the restaurant industry",
                   subtitle = "Daily percent difference from the previous year in seated diners",
                   caption = caption_text) &
   theme(plot.title = element_textbox_simple(color = "white",
                                             size = 16,
                                             family = "Roboto"),
         plot.subtitle = element_text(color = "white",
                                      size = 14,
                                      family = "Roboto"),
         plot.caption = element_text(color = "white",
                                     size = 12,
                                     family = "Roboto"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         panel.border = element_blank(),
         plot.background = element_rect(fill = "black",
                                        color = NA))


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/ot-rest-line-{data_date}.png")

ggsave(plot_path, plot = all_charts,
       dpi = "screen", width = 33, height = 20,
       units = "cm", device = ragg::agg_png())

# # ragg::agg_png(plot_path, width = 33, height = 20, res = 72, units = "cm")
# png(plot_path, width = 33, height = 20, res = 72, units = "cm", type = "cairo-png")
# all_charts
# dev.off()

