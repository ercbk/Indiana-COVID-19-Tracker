# Build the OpenTable dataset using RSelenium


# Notes
# 1. Currently having a spot of bother getting RSelenium to work on a Github runner, so need to run this locally everyday instead. Hopefully a temp fix.
# 2. RSelenium requires XML pkg and that pkg isn't maintained for R 3.6.2, so I think the problem might be resolved if I update to R 4.0.3


library(RSelenium); library(glue)

# Use RSelenium to download dataset
# start selenium server; chrome version is the version of the separate chrome driver I d/l'ed
driver <- rsDriver(browser = c("chrome"), chromever = "83.0.4103.39")
Sys.sleep(10)

# browser
chrome <- driver$client
# currently this isn't needed to shutdown selenium server
#server <- driver$server

url <- "https://www.opentable.com/state-of-industry"
# go to website
chrome$navigate(url = url)

# css selector for the data download button
dl_button <- chrome$findElement(using = "css",
                                value = "#content > div > div > main > section:nth-child(2) > div:nth-child(4) > div._3ZR5BNaRxlZSImxhkkEzrb > button > div")

# makes the element flash in the browser so you can confirm you have the right thing
# dl_button$highlightElement()

dl_button$clickElement()
# give it a few secs to d/l
Sys.sleep(5)

filename <- "YoY_Seated_Diner_Data.csv"
download_location <- file.path(Sys.getenv("USERPROFILE"), "Downloads")
# moves file from download folder to data folder in my project directory
file.rename(file.path(download_location, filename), glue("{rprojroot::find_rstudio_root_file()}/data/{filename}"))

# close browser
chrome$close()

# currently this doesn't shutdown the server
# server$stop()

# kill the server manually
installr::kill_process(process = "java.exe")


