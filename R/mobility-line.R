# Apple mobility data
# Approximating levels of social distancing with Apple's driving index


# Notes
# 1. Apple decided to make it programmatically difficult to download their mobility data. They had download button that didn't give an address to the data when you right-click it. "Inspected" the button in the browser to get the download address. Apple has 3 parts in the address that change. Hence the nested monstrosity below. Had to shorten the sequences to keep the loop time down to a couple mins, so still isn't guaranteed to get the damn data.
# 2. Chart lifted form Kieren Healy blog post





pacman::p_load(extrafont, swatches, dplyr, tsibble, purrr, ggplot2, glue, ggtext, patchwork)

deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))
eth_mat <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Ethereal Material.ase"))
light_eth <- prismatic::clr_lighten(eth_mat, shift = 0.1)


# Using rev to start at the larger numbers so as to avoid contacting older data before the newest data
# str_pad adds 0s in front of single digit numbers
# sequence for hotfix part of data address
hf_seq <- rev(stringr::str_pad(1:10, pad = 0,width = 2 , "left"))
# sequence for dev part of data address
dev_seq <- rev(stringr::str_pad(20:60, pad = 0,width = 2 , "left"))

# heinous loop to get apple's data
get_apple_data <- function(h_seq, d_seq){
   
   # hotfix number loop
   for (i in 1:length(h_seq)){
      
      # dev number loop
      for (j in 1:length(d_seq)){
         
         c <- 0
         # Trys a sequence of dates, starting with today, and if the data download errors, it trys the previous day, and so on, until download succeeds or limit reached.
         while (TRUE) {
            dat <- try({
               try_date <- lubridate::today() - c
               try_address <- glue::glue("https://covid19-static.cdn-apple.com/covid19-mobility-data/20{h_seq[[i]]}HotfixDev{d_seq[[j]]}/v2/en-us/applemobilitytrends-{try_date}.csv")
               readr::read_csv(try_address)
            }, silent = TRUE)
            # no error then exit and return data
            if (class(dat) != "try-error"){
               return(dat)
            } else if (c >= 5) {
               # if try_date reaches 5 days ago, then break to next dev number
               break
            } else {
               # try next earlier day
               c <- c + 1
            }
         }
         
      }
   }
}

mob_dat <- get_apple_data(hf_seq, dev_seq)


# Filter regional cities; gather date columns; date is arbitrary - just wanted enough days to show index values before pandemic
region_mob <- mob_dat %>% 
   filter(region %in% c("Chicago", "Indianapolis", "Detroit", "Cincinnati", "Louisville", "St. Louis"),
          transportation_type == "driving") %>% 
   select(-c(1,3,4)) %>% 
   mutate(region = factor(region)) %>% 
   tidyr::pivot_longer(cols = -region,
                       values_to = "mob_index",
                       names_to = "date") %>% 
   mutate(date = lubridate::ymd(date),
          weekend = timeDate::isWeekend(date)) %>% 
   filter(date >= "2020-02-15") %>% 
   as_tsibble(index = date, key = region)

# current date of data
data_date <- region_mob %>% 
   as_tibble() %>%
   summarize(date = max(date)) %>% 
   pull(date)

# data for indy_chart
ind_chart_dat <- region_mob %>% 
   filter(region == "Indianapolis")

# current driving index value for Indianapolis (horizontal line)
ind_index <- region_mob %>% 
   filter(region == "Indianapolis",
          date == max(date))

# creates plots for each city; keeps x axis for bottom level (patchwork) charts
gen_plots <- function(data, region) {
   p <- ggplot(data = data, aes(x = date, y = mob_index, group = region)) + 
      geom_line(color = light_eth[[6]]) +
      geom_vline(data = data %>% 
                    filter(weekend == TRUE),
                 aes(xintercept = date),
                 color = "#755c99",size = 3.9, alpha = 0.1) +
      geom_hline(data = ind_index, 
                 aes(yintercept = mob_index),
                 color = "#995c61", linetype = 8) +
      expand_limits(x = max(data$date)+2) +
      labs(title = region)
   if (region == "Detroit" | region == "Louisville" | region == "St. Louis"){
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

# chicago, cincy, detroit, louisville, stl
region_plots <- region_mob %>% 
   mutate(region = as.character(region)) %>% 
   filter(region != "Indianapolis") %>%
   group_by(region) %>% 
   tidyr::nest() %>% 
   mutate(plots = map2(data, region, ~gen_plots(.x, .y)))



# indy chart
indy_chart <- ggplot(data = ind_chart_dat, aes(x = date, y = mob_index, group = region, color = region)) + 
   geom_line(color = "#995c61") +
   geom_vline(data = ind_chart_dat %>% 
                 filter(weekend == TRUE),
              aes(xintercept = date),
              color = "#755c99",size = 3.9, alpha = 0.1) +
   expand_limits(x = max(ind_chart_dat$date)+2) +
   ggrepel::geom_text_repel(data = ind_chart_dat %>% 
                               filter(date == max(date)),
                            aes(label = mob_index),
                            nudge_x = 2, nudge_y = -7,
                            segment.color = NA) +
   labs(x = NULL, y = NULL,
        title = "<b style='color:#995c61'>Indianapolis</b>") +
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
                  Source: Apple Mobility Trends Reports")
# patchwork goodness
all_charts <- indy_chart + region_plots$plots[[1]] + region_plots$plots[[2]] + region_plots$plots[[3]] + region_plots$plots[[4]] + region_plots$plots[[5]] + 
   plot_annotation(title = "Approximating levels of social distancing using Apple maps data",
                   subtitle = "Lower values for Apple's driving index indicate higher levels of social distancing",
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


plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/soc-dist-line-{data_date}.png")
ggsave(plot_path, plot = all_charts, dpi = "screen", width = 33, height = 20, units = "cm")
