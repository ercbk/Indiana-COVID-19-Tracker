# Get hospitilizations by age from Regenstrief tableau dashboard






pacman::p_load(dplyr, glue, rvest, httr, jsonlite, purrr, stringr)




# This isn't the website url. Its the dashboard api's GET (request) url. Couldn't pull this url using rvest, may be able to using RSelenium but didn't try. Find dashboard's iframe and the url will be value of "src" attribute
# goto site, inspect then classes: area-wrap clearfix > area-section main (the third one) > area-sec-padd >  full_width_text > vizContainer > iframe
get_url <- "https://tableau.bi.iu.edu/t/prd/views/RegenstriefInstituteCOVID-19PublicDashboard/RICOVID-19HospitalizationsandTests?:origin=card_share_link&:embed=y&:isGuestRedirectFromVizportal=y&:showShareOptions=false&:toolbar=false&:tabs=n&:size=1320,3320&&:showVizHome=n&:bootstrapWhenNotified=y&:device=desktop&:apiID=host0#navType=0&navSrc=Parse"

# fyi this json is located at (cont. from iframe above): document >  dj_khtml dj_safari dj_contentbox >  tundra tableau ff-IFrameSizedToWindow > div style="display: none; > textarea id="tsConfigContainer"
dashsite_json <- GET(url = get_url) %>% 
   # get site's html
   content("text") %>% 
   read_html() %>% 
   # contains json from the dashboard api call
   html_node(css = "#tsConfigContainer") %>% 
   html_text() %>% 
   fromJSON()

Sys.sleep(3)

# base_url from get_url above
base_url <- "https://tableau.bi.iu.edu/"
vizql <- dashsite_json$vizql_root
session_id <- dashsite_json$sessionid
sheet_id <- dashsite_json$sheetId
post_url <- glue("{base_url}{vizql}/bootstrapSession/sessions/{session_id}")


dash_api_output <- POST(post_url, body = list(sheet_id = sheet_id), encode = "form")
# sheet id seems to remain constant, but the session id at end of url does change
# dash_api_output <- POST(url = "https://tableau.bi.iu.edu/vizql/t/prd/w/RegenstriefInstituteCOVID-19PublicDashboard/v/RICOVID-19HospitalizationsandTests/bootstrapSession/sessions/3A7033FEEBD34A959FD950982495A84E-3:0",body = list(sheet_id = "RI%20COVID-19%20Hospitalizations%20and%20Tests"), encode = "form")

Sys.sleep(3)

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

# session info and css html stuff (not needed in this instance)
# info <- fromJSON(extract[1,1])

# just fyi, the data which is the third elt does have a number string in "data" which is how it gets matched, but if you save "extract_data" to a text file (see above) it doesn't show the number string for some reason.
# converts data elt to json obj
dash_data_json <- fromJSON(dash_data[1,3])

# names of all the tableau worksheets used on the dashboard
# worksheets = names(dash_data_json$secondaryInfo$presModelMap$vizData$presModelHolder$genPresModelMapPresModel$presModelMap)

# all the numeric and text values for most (if not all) the dashboard charts/worksheets
dataFull = dash_data_json$secondaryInfo$presModelMap$dataDictionary$presModelHolder$genDataDictionaryPresModel$dataSegments[["0"]]$dataColumns

# hospital admissions by age group and sex
hosp_age <- pluck(dataFull$dataValues, 3) %>% 
      .[10:37]

# cleaning
hosp_age_df <- tibble(
      ages = hosp_age[1:9],
      admissions_m = as.numeric(hosp_age[10:18]),
      admissions_f = as.numeric(hosp_age[19:27])
) %>% 
      mutate(admissions_total = admissions_m + admissions_f,
             date = hosp_age[[28]],
             # get month/day/year
             date = str_extract(date, pattern = "\\d+/\\d+/\\d+") %>% 
                   lubridate::mdy(.))


# If the data is new, add it to the old dataset
old_hosp_age_df <- readr::read_rds(glue("{rprojroot::find_rstudio_root_file()}/data/age-hosp-line.rds"))

data_date <- hosp_age_df %>% 
   slice_tail() %>% 
   pull(date)

old_data_date <- old_hosp_age_df %>% 
   slice_tail() %>% 
   pull(date)

if (data_date != old_data_date) {
   new_hosp_age_df <- old_hosp_age_df %>% 
      bind_rows(hosp_age_df)
} else {
   new_hosp_age_df <- old_hosp_age_df
}

readr::write_rds(new_hosp_age_df, glue("{rprojroot::find_rstudio_root_file()}/data/age-hosp-line.rds"))


# columnsData <- dash_data_json$secondaryInfo$presModelMap$vizData$presModelHolder$genPresModelMapPresModel$presModelMap[["Pyramid admissions age value"]]$presModelHolder$genVizDataPresModel$paneColumnsData
# 
# valueIndices <- columnsData$paneColumnsList$vizPaneColumns[[1]]$valueIndices[[2]]
# aliasIndices <- columnsData$paneColumnsList$vizPaneColumns[[1]]$aliasIndices[[2]]
# 
# 
# cstring <- list();
# for(t in dataFull) {
#    if(t$dataType == "cstring"){
#       cstring <- t
#       break
#    }
# }
# data_index <- 1
# name_index <- 1
# frameData <-  list()
# frameNames <- c()
# for(t in dataFull) {
#    for(index in result) {
#       if (t$dataType == index["dataType"]){
#          if (length(index$valueIndices) > 0) {
#             j <- 1
#             vector <- character(length(index$valueIndices))
#             for (it in index$valueIndices){
#                vector[j] <- t$dataValues[it+1]
#                j <- j + 1
#             }
#             frameData[[data_index]] <- vector
#             frameNames[[name_index]] <- paste(index$fieldCaption, "value", sep="-")
#             data_index <- data_index + 1
#             name_index <- name_index + 1
#          }
#          if (length(index$aliasIndices) > 0) {
#             j <- 1
#             vector <- character(length(index$aliasIndices))
#             for (it in index$aliasIndices){
#                if (it >= 0){
#                   vector[j] <- t$dataValues[it+1]
#                } else {
#                   vector[j] <- cstring$dataValues[abs(it)]
#                }
#                j <- j + 1
#             }
#             frameData[[data_index]] <- vector
#             frameNames[[name_index]] <- paste(index$fieldCaption, "alias", sep="-")
#             data_index <- data_index + 1
#             name_index <- name_index + 1
#          }
#       }
#    }
# }

