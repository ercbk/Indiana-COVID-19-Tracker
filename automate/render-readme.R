


library(dplyr, quietly = TRUE)

# get plot paths, names, and dates
png_files <- tibble::tibble(paths = fs::dir_ls(here::here("plots"))) %>% 
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
            ind_combo_date = png_dates$newest_date[[3]],
            density_pos_date = png_dates$newest_date[[2]],
            region_dea_date = png_dates$newest_date[[4]],
            region_pos_date = png_dates$newest_date[[5]],
            county_pos_date = png_dates$newest_date[[1]]
      )
)

# clean-up old pngs and extraneous html output
paths <- png_files %>% 
      group_by(chart) %>% 
      filter(date == min(date)) %>% 
      pull(paths)

# fs::file_delete(paths)
fs::file_delete(glue::glue("{here::here()}/README.html"))
