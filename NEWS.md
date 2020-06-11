
## Changelog

  - 2020-04-12 - Georgia started separating non-state residents from
    their patient counts. Neither The New York Times nor Georgia
    adjusted the counts prior to the change. Without an adjustment, it
    destroyed the coherence of the data, so I’ve replaced them with
    South Carolina in the daily growth rate chart.

  - 2020-05-07 - The New York Times
    [decided](https://github.com/nytimes/covid-19-data/blob/master/PROBABLE-CASES-NOTE.md)
    to combine “probable” and “confirmed” positive cases and deaths in
    their datesets so that the data would remain consistent across all
    states. I think it provides a more accurate description of what’s
    going, so I’ve decided to keep their data source and discard Indiana
    State Department of Health’s (ISDH). The ramification is that many
    charts’ data will be a day late. Hopefully ISDH will opensource
    their probable cases and probable deaths, so the charts can return
    to being up-to-date.  

  - 2020-05-11 - The calculation of the rate for the Positive Test Rate
    chart was changed from using total counts to a rolling calculation
    over a 3 day windows. The interpretation has also changed based on
    the Johns Hopkins
    [article](https://coronavirus.jhu.edu/testing/testing-positivity).  

  - 2020-05-12 - Replaced the chart that compares daily growth rates and
    doubling times of states with similar population densities with a
    social distancing chart that uses Google Maps data. The daily growth
    rates chart ceased being interesting as doubling times and rates
    have pretty much plateaued. Also, I don’t want to present too many
    charts at once as it might create some information overload. If a
    second or third wave happens, then this chart might return.  

  - 2020-05-26 - Changed wording of the Hospitalizations - Ventilators -
    ICU Beds chart title. I misinterpreted the description of the
    hospitalizations data. I thought I was calculating the daily number
    of people being admitted to the hospital for COVID-19 when it was
    the change in the present count of people hospitalized for COVID-19.
    It’s still relevant because the governor’s speech used present count
    and not daily admittance as a guideline anyways. Apologees though.  

  - 2020-05-29 - County chart - Instead of using all the historic data
    to calculate average daily growth rates, I’m switching to only using
    data over the past 2 weeks which will make the estimates more
    sensitive to outbreaks if they happen.  

  - 2020-06-11 - Replaced the Apple Mobility chart with an OpenTables
    chart. Driving levels seem to have returned to pre-COVID levels, and
    with reopening stages well underway, it’ll be more useful to monitor
    how industries, like restaurants, hard-hit by COVID are recovering.
    The Apple Mobility chart will likely return if a second wave emerges
    though.
