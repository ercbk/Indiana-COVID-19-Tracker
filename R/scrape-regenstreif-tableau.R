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

#Sys.sleep(3)

# base_url from get_url above
base_url <- "https://tableau.bi.iu.edu/"
vizql <- dashsite_json$vizql_root
session_id <- dashsite_json$sessionid
sheet_id <- dashsite_json$sheetId
post_url <- glue("{base_url}{vizql}/bootstrapSession/sessions/{session_id}")


dash_api_output <- POST(post_url, body = list(sheet_id = sheet_id), encode = "form")

#Sys.sleep(3)

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
# info <- fromJSON(extract[1,1])

# just fyi, the data which is the third elt does have a number string in "data" which is how it gets matched, but if you save "extract_data" to a text file (see above) it doesn't show the number string for some reason.
# converts data elt to json obj
dash_data_json <- fromJSON(dash_data[1,3])

# names of all the tableau worksheets used on the dashboard
# worksheets = names(dash_data_json$secondaryInfo$presModelMap$vizData$presModelHolder$genPresModelMapPresModel$presModelMap)

# all the numeric and text values for most (if not all) the dashboard charts/worksheets
dataFull = dash_data_json$secondaryInfo$presModelMap$dataDictionary$presModelHolder$genDataDictionaryPresModel$dataSegments[["0"]]$dataColumns


# tableau worksheets I'm interested in.
hosp_admiss_grps <- list(admissions_f = "Pyramid admissions female",
                      admissions_m = "Pyramid admissions male")

# subset the metadata from the female/male hospitalization tableau worksheets
wrksht_dat <- map(hosp_admiss_grps, function (x) {
   dash_data_json$secondaryInfo$presModelMap$vizData$presModelHolder$genPresModelMapPresModel$presModelMap[[x]]$presModelHolder$genVizDataPresModel$paneColumnsData}) %>%
   # going to get the age group labels from the json even though I could just type them out. Indices for them located in either worksheet
   append(list(ages = wrksht_dat[[1]]))

alias_indices <- list(admissions_f = 6, admissions_m = 6, ages = 2) 

# data is located in giant json sea of data values, so we need the indices of the values we want
value_indices <- map2(wrksht_dat, alias_indices, function (x, y) {
   # zero indexed so need to add 1 to indices
   x$paneColumnsList$vizPaneColumns[[1]]$aliasIndices[[y]] + 1
})

vec_classes = list(admissions_f = "numeric", admissions_m = "numeric", ages = "character" )
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
   # hardcoding timestamp index for now. Not sure how to otherwise get it.
   mutate(timestamp = pluck(dataFull$dataValues, 3)[[1026]],
          date = str_extract(timestamp, pattern = "\\d+/\\d+/\\d+") %>% 
             lubridate::mdy(.),
          # total admissions per age group
          admissions_total = admissions_f + admissions_m) %>% 
   relocate(date, where(is.character), .before = where(is.numeric)) %>% 
   select(-timestamp)

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

