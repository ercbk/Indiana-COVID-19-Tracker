# Excess deaths and excess causes of death




# Notes
# 1. Data for pneumonia is sporadic with some weeks missing.
# 2. Started data at the beginning of January since the first US recorded case is in that month
# 3. There are few different combinations in the types of data included in the excess dataset. I chose to use the weighted, excluding covid deaths data with the excess deaths calculation that uses the point estimate, because that combination had the lowest MAE between the model estimate and the observed number of deaths


# Sections
# 1. Set-up
# 2. Causes of deaths
# 3. Excess Deaths




#################
# Set-up
#################


pacman::p_load(extrafont, swatches, dplyr, lubridate, ggplot2, glue, patchwork, ggtext)


deep_rooted <- swatches::read_palette(glue("{rprojroot::find_rstudio_root_file()}/palettes/Deep Rooted.ase"))

deep_light <- prismatic::clr_lighten(deep_rooted[[7]], shift = .3)
deep_light2 <- prismatic::clr_lighten(deep_rooted[[7]], shift = .2)
purp_light <- prismatic::clr_lighten("#be458c", shift = .15)

natstat_excess_raw <- readr::read_csv("https://data.cdc.gov/api/views/xkkf-xrst/rows.csv?accessType=DOWNLOAD&bom=true&format=true%20target=") %>% 
   janitor::clean_names()

state_wk_cause_raw <- readr::read_csv("https://data.cdc.gov/api/views/u6jv-9ijr/rows.csv?accessType=DOWNLOAD&bom=true&format=true%20target=")
 


###################
# Causes of deaths
###################


ind_cause_raw <- state_wk_cause_raw %>%
   janitor::clean_names() %>%
   filter(jurisdiction == "Indiana")


# get the last week for this year where all diseases have data 
data_week <- ind_cause_raw %>%
   # get only this year's weekly counts
   filter(year == year(today())) %>% 
   group_by(cause_group) %>%
   # last week for each cause (value repeated for each row)
   mutate(final_week = max(week)) %>% 
   # gets rid of those redundant rows
   distinct(final_week, cause_group) %>%
   ungroup() %>% 
   # get whichever final week is the earliest
   filter(final_week == min(final_week)) %>% 
   pull(final_week)

# the number of years in this data that are prior to this year
data_prev_years <- ind_cause_raw %>% 
   distinct(year) %>% 
   summarize(prev_years = n()-1) %>% 
   pull(prev_years)


# calculate percent difference from the totals this year to the avg of years 2015 to 2019 during the same portion of the year
# Individual diseases
ind_cause <- ind_cause_raw %>%
   # only use weeks that have data
   filter(week <= data_week) %>%
   select(-jurisdiction, -state_abbreviation, -suppress, -note, -type) %>%
   # creates 2 groups: current year and years prior to this year
   mutate(period = ifelse(year < year(today()), "prev_years", "this_year")) %>%
   group_by(period, cause_group) %>%
   # calc up-to-date totals for each group and each disease
   summarize(yr_to_date_totals = sum(number_of_deaths)) %>%
   # calcs average for the yearly, up-to-date, prev_years group and leaves this_year's counts alone
   mutate(yr_to_date_avgs = ifelse(period == "prev_years",
                                      yr_to_date_totals/data_prev_years,
                                      yr_to_date_totals),
          cause_group = recode(cause_group, "Alzheimer disease and dementia" = "Alzheimer's disease and dementia",
                               "Hypertensive dieases" = "Hypertensive diseases")) %>%
   select(-yr_to_date_totals) %>%
   # splitting the two groups' avgs into two cols
   tidyr::pivot_wider(id_cols = "cause_group",
                      names_from = "period",
                      values_from = "yr_to_date_avgs") %>%
   # calc percent difference between this years deaths and avg deaths from years prior
   mutate(pct_diff = round(((this_year - prev_years) / prev_years)*100, 1),
          labels = scales::percent(pct_diff/100, accuracy = 0.1),
          cause_group = factor(cause_group) %>%
             forcats::fct_reorder(pct_diff)) %>% 
   top_n(pct_diff, n = 6)


# lollipop plot
# individual diseases
excess_lol <- ggplot(ind_cause, aes(x = pct_diff, y = cause_group,
                      label = labels)) +
   expand_limits(x = max(ind_cause$pct_diff * 1.6)) +
   geom_segment(aes(x = 0, xend = pct_diff, y = cause_group, yend = cause_group),
                color = "white") +
   geom_point(color = "#61c8b7", size=4) +
   # percent difference text
   geom_text(nudge_x = 11.0, col = "white", fontface = "bold") +
   labs(x = NULL, y = NULL,
        title = "Causes of death that are above historic averages",
        subtitle = "*Percent above average*") +
   theme(text = element_text(family = "Roboto"),
         plot.title = element_text(color = "white",
                              family = "Roboto",
                              face = "bold",
                              size = 11),
         plot.subtitle = element_textbox_simple(color = "white",
                              family = "Roboto",
                              face = "bold",
                              size = 10),
         legend.position = "none",
         axis.text.x = element_text(color = "white",
                                    size = 9),
         axis.text.y = element_text(color = "white",
                                    size = 10,
                                    face = "bold",
                                    family = "Roboto"),
         axis.ticks.y = element_blank(),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = "white",
                                        size = 1.0),
         plot.margin = margin(12, 12, 12, 12, "pt"),
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major.y = element_blank(),
         panel.grid.major.x = element_line(color = deep_rooted[[7]]))


# Convert plot to grob
inset_plot <- ggplotGrob(excess_lol)

# left-align title, subtitle with y labels
inset_plot$layout[which(inset_plot$layout$name == "title"),]$l <- 2
inset_plot$layout[which(inset_plot$layout$name == "subtitle"),]$l <- 2

# change sharp corners of the border to rounded ones
bg <- inset_plot$grobs[[1]]
round_bg <- grid::roundrectGrob(x=bg$x, y=bg$y, width=bg$width, height=bg$height,
                          r=unit(0.1, "snpc"),
                          just=bg$just, name=bg$name, gp=bg$gp, vp=bg$vp)
inset_plot$grobs[[1]] <- round_bg



#####################
# Excess deaths
#####################


# filtering, selecting, and getting data into long format for ggplot
ind_excess <- natstat_excess_raw %>%
   # combines 2 descriptions of data to create a unique col
   tidyr::unite(col = "condition", type, outcome) %>%
   filter(state == "Indiana",
          week_ending_date > "2020-01-01",
          condition == "Predicted (weighted)_All causes, excluding COVID-19"
   ) %>% 
   select(week_ending_date, average_expected_count, excess_higher_estimate) %>% 
   tidyr::pivot_longer(cols = c("average_expected_count", "excess_higher_estimate"), names_to = "type", values_to = "value") %>% 
   mutate(type = factor(type, levels = c("excess_higher_estimate", "average_expected_count")),
          # only want labels for excess deaths, otherwise blank
          label = ifelse(value == 0, "", value),
          label = ifelse(type == "average_expected_count", "", label))

# current data date
data_date <- ind_excess %>%
   summarize(week_ending_date = max(week_ending_date)) %>% 
   pull(week_ending_date)

# summary stats (totals)
excess_summary <- ind_excess %>%
   group_by(type) %>% 
   summarize(val_sum = sum(value)) %>%
   mutate(pct = scales::percent(round(val_sum/sum(val_sum), 2)),
          sum_text = scales::comma(val_sum))

summary_text <- glue("
Totals<br>
<b style='color: #C8619DFF'>Excess Deaths</b>: {excess_summary$sum_text[[1]]} ({excess_summary$pct[[1]]})<br>
                     <b style='color: #7F7E84FF'>Expected Deaths</b>: {excess_summary$sum_text[[2]]} ({excess_summary$pct[[2]]})<br>
                     <b>Non-COVID Classified Deaths</b>: {scales::comma(excess_summary$val_sum[[1]]+excess_summary$val_sum[[2]])}")


excess_bar <- ggplot(ind_excess, aes(x = week_ending_date, y = value,
                       fill = type, label = label)) +
   expand_limits(y = 2500) +
   geom_col() +
   scale_y_continuous(labels = scales::label_comma()) +
   scale_fill_manual(values = list(excess_higher_estimate = purp_light[[1]],
                                   average_expected_count = deep_light[[1]])) +
   # excess death values
   ggfittext::geom_bar_text(col = "white",
                            position = "stack",
                            outside = TRUE,
                            min.size = 9) +
   # summary annotation
   geom_textbox(aes(as.Date("2020-01-25"), 1900),
                 label = summary_text, halign = 0,
                 col = "white", fill = "black",
                width = 0.30, size = 5, hjust = 0.45) +
   labs(x = NULL, y = NULL,
        title = "Estimating potentially misclassified deaths by comparing this year's deaths with historic trends",
        subtitle = glue("Bars represent deaths in Indiana where COVID-19 is not recorded as the underlying or multiple cause of death\nLast updated: {data_date}"),
        caption = "Source: National Center for Health Statistics, & Centers for Disease Control and Prevention") +
   theme(text = element_text(family = "Roboto"),
         plot.title = element_text(family = "Roboto",
                              color = "white",
                              size = 16,
                              face = "bold"),
         plot.subtitle = element_text(family = "Roboto",
                                 color = "white",
                                 size = 13),
         plot.caption = element_text(family = "Roboto",
                                color = "white",
                                size = 12),
         legend.position = "none",
         axis.text.x = element_text(color = "white",
                                    size = 11,
                                    face = "bold"),
         axis.text.y = element_text(color = "white",
                                    size = 11,
                                    face = "bold"),
         panel.background = element_rect(fill = "black",
                                         color = NA),
         plot.background = element_rect(fill = "black",
                                        color = NA),
         
         panel.border = element_blank(),
         panel.grid.minor = element_blank(),
         panel.grid.major = element_line(color = deep_rooted[[7]]))


# need to programmatically figure out the inset plot coordinates
coord_constant <- ind_excess %>% 
   # estimation of plot length date range from original plot
   slice((n()-18):(n()-2)) %>% 
   # 61 days was original plot length
   # %/% is integer arithmetic so I don't get a decimal
   summarize(date_len = as.numeric(last(week_ending_date) - first(week_ending_date)),
             constant = (61 - date_len) %/% 2) %>% 
   pull(constant)

# coordinate dates of inset plot
coord_dates <- ind_excess %>% 
   # estimation of plot length range from original plot
   slice((n()-18):(n()-2)) %>% 
   summarize(xmin = first(week_ending_date) - coord_constant,
             xmax = last(week_ending_date) + coord_constant)


# insert lollipop plot into the bar chart
both_charts <- excess_bar +
   annotation_custom(grob = inset_plot,
                     xmin = coord_dates$xmin[[1]],
                     xmax = coord_dates$xmax[[1]],
                     ymin = 1675, ymax = 2575)

# plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/excess-death-col-{data_date}.png")
plot_path <- glue("{rprojroot::find_rstudio_root_file()}/plots/excess-death-col-{data_date}-test.png")
ggsave(plot_path, plot = both_charts, dpi = "screen", width = 33, height = 20, units = "cm")


