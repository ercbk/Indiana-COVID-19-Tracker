# plot file clean-up



library(dplyr, quietly = TRUE, warn.conflicts = FALSE)

# get plot paths, names, and dates
png_files <- tibble::tibble(paths = fs::dir_ls(glue::glue("{rprojroot::find_rstudio_root_file()}/plots"))) %>% 
      mutate(
            chart = stringr::str_extract(paths,
                                         pattern = "[a-z]*-[a-z]*-[a-z]*"),
            date = stringr::str_extract(paths,
                                        pattern = "[0-9]{4}-[0-9]{2}-[0-9]{2}") %>%
                  as.Date())


# clean-up old pngs and extraneous html output
png_files %>% 
      group_by(chart) %>% 
      add_count() %>% 
      filter(n > 3) %>%
      mutate(rank = rank(date)) %>% 
      # keep last 3
      filter(rank <= max(rank)-3) %>% 
      pull(paths) %>% 
      fs::file_delete(.)
