# Estimate levels of social distancing using Google Maps data


# Notes
# 1. The baseline is the median value, for the corresponding day of the week,during the 5-week period Jan 3 to Feb 6, 2020
# 2. The .pdf report for Indiana has county level data. The .csv has a column for County (sub_region_2), but it's filled with NAs. There are multiple values per date, so I assume these are county indexes.
# 3. Website: https://www.google.com/covid19/mobility/





pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, glue, ggtext)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
light_deep <- prismatic::clr_lighten(deep_rooted, shift = 0.2)

goog_raw <- readr::read_csv("https://www.gstatic.com/covid19/mobility/Global_Mobility_Report.csv")

# Filter Indiana; cols: date, activity, index; calc median index of all counties
ind_goog <- goog_raw %>% 
   filter(sub_region_1 == "Indiana") %>% 
   select(date,
          `Retail and Recreation` = retail_and_recreation_percent_change_from_baseline,
          Workplace = workplaces_percent_change_from_baseline,
          Residential = residential_percent_change_from_baseline) %>% 
   tidyr::drop_na() %>% 
   group_by(date) %>% 
   summarize(`Retail and Recreation` = median(`Retail and Recreation`)/100,
             Workplace = median(Workplace)/100,
             Residential = median(Residential)/100) %>% 
   tidyr::pivot_longer(cols = -date, names_to = "activity", values_to = "index") %>% 
   mutate(Activity = factor(activity),
          weekend = timeDate::isWeekend(date))

# current date of data
data_date <- ind_goog %>% 
   as_tibble() %>%
   summarize(date = max(date)) %>% 
   pull(date)

# grouped line chart
goog_plot <- ggplot(data = ind_goog %>% 
          filter(date > "2020-03-07"), aes(x = date, y = index,
                            group = activity, color = Activity)) + 
   geom_line(key_glyph = "timeseries") +
   # emphasize y = 0 a little bit
   geom_hline(aes(yintercept = 0),
              color = light_deep[[7]], size = 1) +
   # add vertical bars to show the weekends
   geom_vline(data = ind_goog %>% 
                 filter(weekend == TRUE),
              aes(xintercept = date),
              color = "#755c99", size = 5.1,
              alpha = 0.15) +
   # viridis pal is continuous, begin, [0, 1], says where rightside endpt is
   scale_color_viridis_d(option = "magma", direction = 1,
                         begin = 0.5) +
   scale_x_date(limits = c(as.Date("2020-03-07"), max(ind_goog$date)+7),
                date_breaks = "1 month", date_labels = "%b %d") +
   scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
   ggrepel::geom_text_repel(data = ind_goog %>% 
                               filter(date == max(date)),
                            aes(label = scales::percent(index, accuracy = 1)),
                            point.padding = 0.5,direction = "both",
                            segment.size = NA, nudge_x = 0.2,
                            show.legend = FALSE, size = 5) +
   labs(x = NULL, y = NULL,
        title = "Approximating levels of social distancing in Indiana using Google Maps data",
        subtitle = "Values are the percent difference from a mobility baseline calculated earlier in the year before the pandemic",
        caption = glue("Last updated: {data_date}
                       Source: Google Community Mobility Reports")) +
   theme(plot.title = element_textbox_simple(color = "white",
                                             family = "Roboto",
                                             size = 16),
         plot.subtitle = element_markdown(color = "white",
                                          family = "Roboto",
                                          size = 14),
         plot.caption = element_text(color = "white",
                                     size = 12),
         text = element_text(family = "Roboto"),
         legend.position = "top",
         legend.direction = "horizontal",
         legend.background = element_rect(fill = "black"),
         legend.key = element_rect(fill = "black"),
         legend.text = element_text(color = "white",
                                    size = 12),
         legend.title = element_blank(),
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


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/goog-mob-line-{data_date}.png")

ggsave(plot_path, plot = goog_plot, dpi = "screen", width = 33, height = 20, units = "cm")
