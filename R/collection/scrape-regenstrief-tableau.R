# Get hospitilizations by age and mortality rate from Regenstrief tableau dashboard

# https://www.regenstrief.org/covid-dashboard/


# Set-up ----

pacman::p_load(dplyr, glue, rvest, httr, jsonlite, purrr, stringr)




#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# 1 Pull data from Tableau API ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# Dashboard api's GET (request) url. Couldn't pull this url using rvest, may be able to using RSelenium or Splash but didn't try. Find dashboard's iframe and the url will be value of "src" attribute
# goto site, inspect then classes: body > area-wrap clearfix > area-section main (the third one) > area-sec-padd >  full_width_text > vizContainerTests > iframe
get_url <- "https://tableau.bi.iu.edu/t/prd/views/RegenstriefInstituteCOVID-19HospitalizationsandTestsPublicDashboard/RICOVID-19HospitalizationsandTests?:origin=card_share_link&:embed=y&:isGuestRedirectFromVizportal=y&:showShareOptions=false&:toolbar=false&:tabs=n&:size=1320,3110&&:showVizHome=n&:bootstrapWhenNotified=y&:device=desktop&:apiID=host0#navType=0&navSrc=Parse"

# fyi this json is located at (cont. from iframe above): document >  dj_khtml dj_safari dj_contentbox >  tundra tableau ff-IFrameSizedToWindow > div style="display: none; > textarea id="tsConfigContainer"
dashsite_json <- GET(url = get_url) %>% 
   # get site's html
   content("text") %>% 
   read_html() %>% 
   # contains json from the dashboard api call
   html_node(css = "#tsConfigContainer") %>% 
   html_text() %>% 
   fromJSON()

# robots.txt asks for a 5 sec delay between hits
Sys.sleep(5)

# base_url from get_url above
base_url <- "https://tableau.bi.iu.edu/"
vizql <- dashsite_json$vizql_root
session_id <- dashsite_json$sessionid
sheet_id <- dashsite_json$sheetId
post_url <- glue("{base_url}{vizql}/bootstrapSession/sessions/{session_id}")


dash_api_output <- POST(post_url, body = list(sheet_id = sheet_id), encode = "form", timeout(300))


dash_text <- content(dash_api_output, "text")

# can look at the output easier in notepad++ to try and pick out a regex pattern to extract data
# fileConn <- file("tableau-scrape-output.txt")
# writeLines(dash_text, fileConn)
# close(fileConn)


# This regex should only match two elts, but the first gets repeated for some reason. So there's three.
# Think you could just pull a pattern with "secondaryInfo" but this is how the dude in SO did it.
# \\d+ is looking for a string of numbers
# followed by a ";"
# then everything between two curly braces
# then repeats pattern
# outputs a matrix
dash_data <- str_match(dash_text, "\\d+;(\\{.*\\})\\d+;(\\{.*\\})")

# session info and css html stuff (may use to try and find timestamp)
# info <- fromJSON(dash_data[1,1])

# just fyi, the data which is the third elt does have a number string in "data" which is how it gets matched, but if you save "dash_data" to a text file (see above) it doesn't show the number string for some reason.
# converts data elt to json obj
dash_data_json <- fromJSON(dash_data[1,3])

# names of all the tableau worksheets used on the dashboard
# worksheets <- names(dash_data_json$secondaryInfo$presModelMap$vizData$presModelHolder$genPresModelMapPresModel$presModelMap)

# all the numeric and text values for most (if not all) the dashboard charts/worksheets
dataFull = dash_data_json$secondaryInfo$presModelMap$dataDictionary$presModelHolder$genDataDictionaryPresModel$dataSegments[["0"]]$dataColumns



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# 2 Admissions by gender ----
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# tableau worksheets I'm interested in.
hosp_admiss_grps <- list(admissions_f = "Pyramid admissions female",
                      admissions_m = "Pyramid admissions male")

# subset the metadata from the female/male hospitalization tableau worksheets
wrksht_dat <- map(hosp_admiss_grps, function (x) {
   dash_data_json$secondaryInfo$presModelMap$vizData$presModelHolder$genPresModelMapPresModel$presModelMap[[x]]$presModelHolder$genVizDataPresModel$paneColumnsData}) %>%
   # going to get the age group labels from the json even though I could just type them out. Indices for them located in either worksheet. So just copying the 1st one
   append(list(ages = .[[1]]))

# vizDataColumns > columnIndices > fieldCaption to look at the data fields available and their indices
alias_indices <- list(admissions_f = 5, admissions_m = 5, ages = 2) 

# data is located in giant json sea of data values, so we need the indices of the values we want
value_indices <- map2(wrksht_dat, alias_indices, function (x, y) {
   # zero indexed so need to add 1 to indices
   x$paneColumnsList$vizPaneColumns[[1]]$aliasIndices[[y]] + 1
})

# wrksht_dat[[1]][["vizDataColumns"]][["dataType"]] tells the classes of available fields
vec_classes = list(admissions_f = "numeric", admissions_m = "numeric", ages = "character" )

# use indices to pull values from the json
hosp_age_df <- map2_dfc(value_indices, vec_classes, function (x, y) {
   if (y == "numeric") {
      hosp_col <- map_dbl(x, function(a) {
         # pulls values from dataValues$integer
         pluck(dataFull$dataValues, 1)[[a]]
      })
   } else {
      hosp_col <- map_chr(x, function(b) {
         # pulls values from dataValues$cstring
         pluck(dataFull$dataValues, 3)[[b]]
      })
      return(hosp_col)
   }
}) %>% 
   # timestamp doesn't have an index, so need to regex it
   mutate(timestamp = str_subset(pluck(dataFull$dataValues, 3), "\\d+/\\d+/\\d+ \\d+:\\d+:\\d+"),
          date = str_extract(timestamp, pattern = "\\d+/\\d+/\\d+") %>% 
             lubridate::mdy(.),
          # total admissions per age group
          admissions_total = admissions_f + admissions_m) %>% 
   relocate(date, where(is.character), .before = where(is.numeric)) %>% 
   select(-timestamp)





#@@@@@@@@@@@@@@@@@@@@@@@@@
# 3 Mortality Rate ----
#@@@@@@@@@@@@@@@@@@@@@@@@@


# Get tableau worksheet with hospital mortality rate
mort_wrksht_dat <- dash_data_json$secondaryInfo$presModelMap$vizData$presModelHolder$genPresModelMapPresModel$presModelMap[["Mort Rate"]]$presModelHolder$genVizDataPresModel$paneColumnsData

# vizDataColumns > columnIndices and vizDataColumns > fieldCaption to look at the data fields available and their indices
mort_alias_indices <- list(deaths_total = 4, hosp_total = 5, death_rate = 6) 

# data is located in giant json sea of data values, so we need the indices of the values we want
mort_val_indices <- map(mort_alias_indices, function (y) {
      # zero indexed so need to add 1 to indices
      mort_wrksht_dat$paneColumnsList$vizPaneColumns[[1]]$aliasIndices[[y]] + 1
})

# wrksht_dat[[1]][["vizDataColumns"]][["dataType"]] tells the classes
mort_vec_classes = list(deaths_total = "integer", hosp_full = "integer",  death_rate = "double")

# use indices to pull the values from the json
hosp_mort_vals <- map2_dfc(mort_val_indices, mort_vec_classes, function(x, y){
      if (y == "integer") {
            mort_col <- map_dbl(x, function(s) {
                  # pulls values from dataValues$integer
                  pluck(dataFull$dataValues, 1)[[s]]
            })
      } else {
            mort_col <- map_dbl(x, function(t) {
                  # pulls values from dataValues$real
                  pluck(dataFull$dataValues, 2)[[t]]
            })
      }
      return(mort_col)
}) %>% 
      mutate(timestamp = str_subset(pluck(dataFull$dataValues, 3), "\\d+/\\d+/\\d+ \\d+:\\d+:\\d+"),
             date = str_extract(timestamp, pattern = "\\d+/\\d+/\\d+") %>% 
                   lubridate::mdy(.)) %>% 
      relocate(date, everything()) %>% 
      select(-timestamp)




# Save ----


# If the data is new, add it to the old dataset
old_hosp_age_df <- readr::read_rds(glue("{rprojroot::find_rstudio_root_file()}/data/age-hosp-line.rds"))
old_hosp_mort_vals <- readr::read_rds(glue("{rprojroot::find_rstudio_root_file()}/data/mort-hosp-line.rds"))

data_date <- hosp_age_df %>% 
      slice_tail() %>% 
      pull(date)

old_data_date <- old_hosp_age_df %>% 
      slice_tail() %>% 
      pull(date)

if (data_date > old_data_date) {
      new_hosp_age_df <- old_hosp_age_df %>% 
            bind_rows(hosp_age_df)
      new_hosp_mort_vals <- old_hosp_mort_vals %>% 
            bind_rows(hosp_mort_vals)
} else {
      new_hosp_age_df <- old_hosp_age_df
      new_hosp_mort_vals <- old_hosp_mort_vals
}

readr::write_rds(new_hosp_age_df, glue("{rprojroot::find_rstudio_root_file()}/data/age-hosp-line.rds"))
readr::write_rds(new_hosp_mort_vals, glue("{rprojroot::find_rstudio_root_file()}/data/mort-hosp-line.rds"))
