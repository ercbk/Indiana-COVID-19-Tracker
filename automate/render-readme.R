


library(dplyr, quietly = TRUE, warn.conflicts = FALSE)

# get plot paths, names, and dates
png_files <- tibble::tibble(paths = fs::dir_ls(glue::glue("{rprojroot::find_rstudio_root_file()}/plots"))) %>% 
      mutate(
            chart = stringr::str_extract(paths,
                                         pattern = "[a-z]*-[a-z]*-[a-z]*"),
            date = stringr::str_extract(paths,
                                         pattern = "[0-9]{4}-[0-9]{2}-[0-9]{2}") %>%
                  as.Date())


# render the charts with latest data
png_dates <- png_files %>% 
      group_by(chart) %>% 
      summarize(newest_date = max(date))


rmarkdown::render(
      "README.Rmd", params = list(
            ind_combo_date = png_dates$newest_date[[6]],
            pos_policy_date = png_dates$newest_date[[8]],
            goog_mob_date = png_dates$newest_date[[4]],
            region_dea_date = png_dates$newest_date[[10]],
            region_pos_date = png_dates$newest_date[[11]],
            county_pos_date = png_dates$newest_date[[1]],
            daily_re_date = png_dates$newest_date[[2]],
            pos_rate_date = png_dates$newest_date[[9]],
            ot_rest_date = png_dates$newest_date[[7]],
            hosp_iv_date = png_dates$newest_date[[5]],
            exc_death_date = png_dates$newest_date[[3]]
      )
)

# clean-up old pngs and extraneous html output
png_files %>% 
   group_by(chart) %>% 
   add_count() %>% 
   filter(n > 3) %>%
   filter(date == min(date)) %>% 
   pull(paths) %>% 
   fs::file_delete(.)


fs::file_delete(glue::glue("{rprojroot::find_rstudio_root_file()}/README.html"))
