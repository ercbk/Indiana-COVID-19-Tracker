


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
            ind_combo_date = png_dates$newest_date[[5]],
            pos_policy_date = png_dates$newest_date[[6]],
            goog_mob_date = png_dates$newest_date[[3]],
            region_dea_date = png_dates$newest_date[[8]],
            region_pos_date = png_dates$newest_date[[9]],
            county_pos_date = png_dates$newest_date[[1]],
            daily_re_date = png_dates$newest_date[[2]],
            pos_rate_date = png_dates$newest_date[[7]],
            soc_dist_date = png_dates$newest_date[[10]],
            hosp_iv_date = png_dates$newest_date[[4]]
      )
)

# clean-up old pngs and extraneous html output
paths <- png_files %>% 
      group_by(chart) %>% 
      filter(date == min(date)) %>% 
      pull(paths)

if (nrow(png_files) > 36) {
   fs::file_delete(paths)
}

fs::file_delete(glue::glue("{rprojroot::find_rstudio_root_file()}/README.html"))
