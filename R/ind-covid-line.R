# Indiana COVID-19 
# statewide positive cases and deaths

# Takes NY Times data and tweets from the Indiana Health Department and charts cumulative counts for positive test results and deaths

# Sections
# 1. Set-up
# 2. Process data
# 3. Charts
# 4. Grobs
# 5. Assemble visual



#######################
# Set-up
#######################


pacman::p_load(grid, extrafont, prismatic, ggtext, dplyr, glue, lubridate, stringr, ggplot2)

deep_rooted <- swatches::read_palette("palettes/Deep Rooted.ase")

loadfonts()


nyt_dat <- readr::read_csv("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv")

# date of latest Indiana info that's been uploaded to the nyt repo
latest_date <- nyt_dat %>% 
   filter(state == "Indiana") %>% 
   summarize(max_date = max(date)) %>% 
   pull(max_date)


# get Indiana Health Department's last 150 tweets
in_health_tweets <- rtweet::get_timeline("StateHealthIN", n = 150) %>% 
   tidyr::separate(col = "created_at", into = c("date", "time"), sep = " ") %>% 
   mutate(date = as_date(date),
          time = hms::as_hms(time))




#######################
# Process data
#######################


# filter tweets that have the updated info, create columns for covid data
ind_tweet_dat <- in_health_tweets %>% 
   mutate(hour = hour(time)) %>% 
   select(date, hour, text) %>% 
   filter(str_detect(text, pattern = "latest #COVID19 case information") | str_detect(text, pattern = "positive cases")) %>% 
   mutate(
      text = str_remove_all(text, ","),
      positives = str_extract(text, pattern = "cases: [0-9]*") %>% 
         str_remove("cases:") %>% 
         as.numeric(),
      deaths = str_extract(text, pattern = "deaths: [0-9]*") %>% 
         str_remove("deaths:") %>% 
         as.numeric(),
      num_tests = str_extract(text, pattern = "(ISDH: [0-9]*)|(tested: [0-9]*)") %>% 
         str_remove("ISDH:") %>%
         str_remove("tested: ") %>% 
         as.numeric()
      ) %>% 
   filter(date > latest_date) %>% 
   select(date, positives, deaths)


# Filter Indiana data, calc percent change
ind_dat <- nyt_dat %>% 
   filter(state == "Indiana") %>% 
   group_by(date) %>% 
   summarize(positives = sum(cases),
             deaths = sum(deaths)) %>% 
   bind_rows(ind_tweet_dat) %>% 
   mutate(pos_pct_change = round((positives/lag(positives) - 1) * 100, 1),
          dea_pct_change = round((deaths/lag(deaths) - 1) * 100, 1),
          pos_pct_txt = ifelse(pos_pct_change > 0, as.character(pos_pct_change) %>% paste0("+", ., "%"), as.character(pos_pct_change)),
          dea_pct_txt = ifelse(dea_pct_change > 0, as.character(dea_pct_change) %>% paste0("+", ., "%"), as.character(dea_pct_change)),
          doub_pos = round(log(2)/log((pos_pct_change/100)+1), 1) %>%
             as.character() %>%
             paste0(., " days"),
          doub_dea = round(log(2)/log((dea_pct_change/100)+1), 1) %>%
             as.character() %>%
             paste0(., " days"),
          pos_pct_txt = ifelse(pos_pct_txt == "NA%", NA, pos_pct_txt),
          dea_pct_txt = ifelse(dea_pct_txt == "NaN%" | dea_pct_txt == "Inf%" | dea_pct_txt == "NA%", NA, dea_pct_txt),
          doub_pos = ifelse(doub_pos == "NaN days" | doub_pos == "Inf days" | doub_pos == "NA days", NA, doub_pos),
          doub_dea = ifelse(doub_dea == "NaN days" | doub_dea == "Inf days" | doub_dea == "NA days", NA, doub_dea)
   )

# calc % change between current count and 1 day ago, 2 days, 3 days, etc.
tab_dat <- ind_dat %>%
   tail(6) %>%
   select(date, positives, deaths) %>%
   mutate(pos_hist_pct_chg = round((positives[[6]]/lag(positives)-1)*100, 1),
          dea_hist_pct_chg = round((deaths[[6]]/lag(deaths)-1)*100, 1)) %>% 
   arrange(desc(date)) %>%
   mutate(pos_hist_pct_chg = lag(pos_hist_pct_chg),
          dea_hist_pct_chg = lag(dea_hist_pct_chg)) %>% 
   slice(3:6) %>% 
   mutate(Date = c("2 days ago", "3 days ago", "4 days ago", "5 days ago" ))




#######################
# Charts
#######################


# current data
label_dat <- ind_dat %>%
   filter(date == max(date))

# annotations
pos_lbl <- glue("Date: {label_dat$date[[1]]}
Count: {label_dat$positives[[1]]}
Change from yesterday: {label_dat$pos_pct_txt[[1]]}
Doubling time at the current pace:
{label_dat$doub_pos[[1]]}
")
dea_lbl <- glue("Date: {label_dat$date[[1]]}
Count: {label_dat$deaths[[1]]}
Change from yesterday: {label_dat$dea_pct_txt[[1]]}
Doubling time at the current pace:
{label_dat$doub_dea[[1]]}
")


# positive cases line chart
ind_statewide_pos <- ggplot(ind_dat, aes(x = date, y = positives)) +
   geom_line(color = deep_rooted[[4]]) +
   geom_point(color = deep_rooted[[4]]) +
   ggforce::geom_mark_circle(aes(
                        filter = date == label_dat$date[[1]],
                        description = pos_lbl),
                    expand = -0.02, radius = 0.02,
                    con.colour = deep_rooted[[7]],
                    label.colour = "white",
                    label.fill = deep_rooted[[7]],
                    color = deep_rooted[[7]]) +
   labs(x = NULL, y = NULL, title = "<b style='color:#B28330'>Positive Test Results</b>") +
   theme(plot.title = element_textbox_simple(size = rel(0.9)),
         text = element_text(family = "Roboto"),
         legend.position = "none",
         axis.text.x = element_text(color = "white"),
         axis.text.y = element_text(color = "white"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         plot.subtitle = element_text(size = rel(0.85),
                                      color = "white"),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


# deaths line chart
ind_statewide_dea <- ggplot(ind_dat, aes(x = date, y = deaths)) + 
   geom_line(color = deep_rooted[[2]]) +
   geom_point(color = deep_rooted[[2]]) +
   ggforce::geom_mark_circle(aes(
      filter = date == label_dat$date[[1]],
      description = dea_lbl),
      expand = -0.02, radius = 0.02,
      con.colour = deep_rooted[[7]],
      label.colour = "white",
      # label.buffer = unit(20, 'mm'),
      label.fill = deep_rooted[[7]],
      color = deep_rooted[[7]]) +
   labs(x = NULL, y = NULL, title = "<b style='color:#BE454F'>Deaths</b>") +
   theme(plot.title = element_textbox_simple(size = rel(0.9)),
         text = element_text(family = "Roboto"),
         legend.position = "none",
         axis.text.x = element_text(color = "white"),
         axis.text.y = element_text(color = "white"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         plot.subtitle = element_text(size = rel(0.85),
                                      color = "white"),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))




#######################
# Grobs
#######################


# line chart grobs
dea_plot_grob <- ggplotGrob(ind_statewide_dea)
pos_plot_grob <- ggplotGrob(ind_statewide_pos)


# table theme
theme_table <- gridExtra::ttheme_minimal(
   core = 
      list(fg_params =
              list(col = "white", fontsize = 12, fontface = "plain"),
           bg_params = list(fill = deep_rooted[[7]])),
   colhead = 
      list(fg_params = 
              list(col = "white",
                   fontsize = 12, fontface = "plain"),
           bg_params = list(fill = deep_rooted[[7]])),
   base_family = "Roboto"
)


# table grobs for each line chart
pos_tab_grob <- gridExtra::tableGrob(tab_dat %>%
                                        select(Date, pos_hist_pct_chg) %>%
                                        mutate(pos_hist_pct_chg = as.character(pos_hist_pct_chg) %>% paste0(., "%")) %>% 
                                        rename(`% change from\npast to today` = pos_hist_pct_chg),
                                     rows = NULL, theme = theme_table)


dea_tab_grob <- gridExtra::tableGrob(tab_dat %>%
                                        select(Date, dea_hist_pct_chg) %>%
                                        mutate(dea_hist_pct_chg = as.character(dea_hist_pct_chg) %>% paste0(., "%")) %>% 
                                        rename(`% change from\npast to today` = dea_hist_pct_chg),
                                     rows = NULL, theme = theme_table)


# title and caption text grobs
# when finding hjust values, note that png looks different that visual in the plots pane
title_grob <- grobTree(rectGrob(gp = gpar(fill = "black")), textGrob("Indiana COVID-19", hjust = 3.75, gp = gpar(fontsize = 15, col = "white")))

# An absolute bitch to align both data source strings. Can only add spaces at the end of the string and \s doesn't work.
caption_grob <- grobTree(rectGrob(gp = gpar(fill = "black")), textGrob("Sources: The New York Times, according to reports from state and local health agencies\nIndiana State Department of Health Twitter account, @StateHealthIN", just = "left", hjust = 0.5, gp = gpar(fontsize = 10, col = "white")))

# its easier align caption text if its confined in a few cells instead of spanning entire layout. So, another black rectangle is needed to take up the extra white space
black_rect_grob <- rectGrob(gp = gpar(fill = "black"))




#######################
# Assemble visual
#######################


# construct layout
gtab <- gtable::gtable(widths = unit(c(0.4, 0.6, 1, 0.4, 0.6, 1), "null"), heights = unit(c(0.12, 0.51, 0.42, 0.83, 0.10), "null"))

# add plots
gtab <- gtable::gtable_add_grob(gtab, pos_plot_grob, t = 2, b = 4, l = 1, r = 3)
gtab <- gtable::gtable_add_grob(gtab, dea_plot_grob, t = 2, b = 4, l = 4, r = 6)

# add title, caption, rectangle
gtab <- gtable::gtable_add_grob(gtab, title_grob, t = 1, b = 1, l = 1, r = 6)
gtab <- gtable::gtable_add_grob(gtab, caption_grob, t = 5, b = 5, l = 4, r = 6)
gtab <- gtable::gtable_add_grob(gtab, black_rect_grob, t = 5, b = 5, l = 1, r = 3)

# find cell coordinates to place tables
# gtable::gtable_show_layout(gtab)

# add tables, only need two coord since we don't want to table to span more than one cell
gtab <- gtable::gtable_add_grob(gtab, pos_tab_grob, t = 3, l = 2)
gtab <- gtable::gtable_add_grob(gtab, dea_tab_grob, t = 3, l = 5)

# grid.draw(gtab)
# grid.newpage()

plot_path <- glue("plots/ind-line-{label_dat$date[[1]]}.png")
ggsave(plot_path, plot = gtab, dpi = "print", width = 33, height = 20, units = "cm")


