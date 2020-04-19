


library(dplyr, quietly = TRUE, warn.conflicts = FALSE)

# get plot paths, names, and dates
png_files <- tibble::tibble(paths = fs::dir_ls(glue::glue("{rprojroot::find_rstudio_root_file()}/plots"))) %>% 
      mutate(
            chart = stringr::str_extract(paths,
                                         pattern = "[a-z]*-[a-z]*-[a-z]*"),
            date = stringr::str_extract(paths,
                                         pattern = "[0-9]{4}-[0-9]{2}-[0-9]{2}") %>%
                  as.Date())

print(png_files)

# render the charts with latest data
png_dates <- png_files %>% 
      group_by(chart) %>% 
      summarize(newest_date = max(date))

png_dates

rmarkdown::render(
      "README.Rmd", params = list(
            ind_combo_date = png_dates$newest_date[[3]],
            pos_policy_date = png_dates$newest_date[[4]],
            density_pos_date = png_dates$newest_date[[2]],
            region_dea_date = png_dates$newest_date[[5]],
            region_pos_date = png_dates$newest_date[[6]],
            county_pos_date = png_dates$newest_date[[1]]
      )
)

# clean-up old pngs and extraneous html output
paths <- png_files %>% 
      group_by(chart) %>% 
      filter(date == min(date)) %>% 
      pull(paths)

if (nrow(png_files) > 18) {
   fs::file_delete(paths)
}

fs::file_delete(glue::glue("{rprojroot::find_rstudio_root_file()}/README.html"))
