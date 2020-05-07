# Monitors Beds and Ventilator usage and supply


#########################
# Set-up
#########################


pacman::p_load(extrafont, swatches, dplyr, tsibble, ggplot2, glue, ggtext)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))


# Indiana Data Hub
# state positives, deaths, tests counts
# Trys a sequence of dates, starting with today, and if the data download errors, it trys the previous day, and so on, until download succeeds.
c <- 0
while (TRUE) {
      try_result <- try({
            try_date <- lubridate::today() - c
            try_date_str <- try_date %>% 
                  stringr::str_extract(pattern = "-[0-9]{2}-[0-9]{2}") %>% 
                  stringr::str_remove_all(pattern = "-") %>% 
                  stringr::str_remove(pattern = "^[0-9]")
            try_address <- glue::glue("https://hub.mph.in.gov/dataset/5a905d51-eb50-4a83-8f79-005239bd108b/resource/882a7426-886f-48cc-bbe0-a8d14e3012e4/download/covid_report_bedvent_{try_date_str}.xlsx")
            try_destfile <- glue::glue("data/beds-vents-{try_date_str}.xlsx")
            download.file(try_address, destfile = try_destfile, mode = "wb")
      }, silent = TRUE)
      
      if (class(try_result) != "try-error"){
            break
      } else if (c >= 14) {
            stop("Uh, something's probably wrong with the Indiana Data Hub link. Might've changed the pattern.")
      } else {
            c <- c + 1
      }
}

bv_dat_current <- readxl::read_xlsx(try_destfile)






rate_plot <- ggplot(data = chart_dat,
                    aes(x = date, y = pos_test_rate)) +
      geom_point(color = deep_rooted[[4]]) +
      geom_line(color = deep_rooted[[4]]) +
      scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
      scale_x_date(date_breaks = "4 days",
                   date_labels = "%b %d") +
      ggrepel::geom_label_repel(data = chart_dat %>%
                                      filter(date == max(date)),
                                aes(label = scales::percent(pos_test_rate, accuracy = 0.1), size = 12),
                                nudge_x = -0.45, nudge_y = 0.02) +
      geom_text(data = data.frame(x = as.Date("2020-04-22"),
                                  y = 0.177,
                                  label = glue("US Average: {us_pos_rate}")),
                mapping = aes(x = x, y = y,
                              label = label),
                size = 4.8, angle = 0L,
                lineheight = 1L, hjust = 0.5,
                vjust = 0.5, colour = "white",
                family = "Roboto", fontface = "plain",
                inherit.aes = FALSE, show.legend = FALSE) +
      geom_text(data = data.frame(x = as.Date("2020-04-22"),
                                  y = 0.179,
                                  label = glue("
                                            Without Cass Co: {without_cass}")),
                mapping = aes(x = x, y = y,
                              label = label),
                size = 4.8, angle = 0L,
                lineheight = 1L, hjust = 0.5,
                vjust = 0.5, colour = "white",
                family = "Roboto", fontface = "plain",
                inherit.aes = FALSE, show.legend = FALSE) +
      labs(x = NULL, y = NULL,
           title = "Daily Rate",
           subtitle = "This font is awesome:
       <span style='font-family: \"Font Awesome 5 Free Solid\"; color: #B28330'>	&#xf0aa; &#xf062; &#xf357;</span>  
        other words",
           caption = "Sources: The Indiana Data Hub\nThe COVID Tracking Project") +
      theme(plot.title = element_textbox_simple(color = "white",
                                                family = "Roboto",
                                                size = 16),
            plot.subtitle = element_markdown(color = "white"),
            plot.caption = element_text(color = "white",
                                        size = 12),
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
rate_plot

