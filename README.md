
# Indiana COVID-19 Tracker

![Noon
Update](https://github.com/ercbk/Indiana-COVID-19-Tracker/workflows/Noon%20Update/badge.svg)
![Evening
Update](https://github.com/ercbk/Indiana-COVID-19-Tracker/workflows/Evening%20Update/badge.svg)

This repository collects and processes datasets for
[Indiana-COVID-19-Website](https://github.com/ercbk/Indiana-COVID-19-Website).
It also has creates charts for the [“Static
Charts”](https://ercbk.github.io/Indiana-COVID-19-Website/static.html)
tab of the Indiana COVID-19 Tracker website.  
The changelog for the entire Indiana COVID-19 Tracker project is located
in
[NEWS.md](https://github.com/ercbk/Indiana-COVID-19-Tracker/blob/master/NEWS.md).  
  
  
  

## Weekly COVID-19 Cases by Age

#### Description

Processed data for
[heatmaps](https://ercbk.github.io/Indiana-COVID-19-Website/demographics.html#cases-by-age)
that show a breakdown of weekly COVID-19 cases by age group.

#### Raw Sources

Indiana Data Hub: [COVID-19 CASE
DEMOGRAPHICS](%22https://hub.mph.in.gov/dataset/62ddcb15-bbe8-477b-bb2e-175ee5af8629/resource/2538d7f1-391b-4733-90b3-9e95cd5f3ea6/download/covid_report_demographics.xlsx%22)  
tidycensus R package: [website](https://walker-data.com/tidycensus/),
2018 age populations for Indiana

#### Notes

Other variables:  
- `end_date`: ordered factor; date of the last day of the weekly
interval  
- `daily_cases`: Vestigial column that was used during processing,
shouldn’t have been included  
- `pop`: Vestigial column used to calculate `prop_cases`  
  
  

<style>html {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', 'Fira Sans', 'Droid Sans', Arial, sans-serif;
}

#eotjbcumxw .gt_table {
  display: table;
  border-collapse: collapse;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#eotjbcumxw .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#eotjbcumxw .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#eotjbcumxw .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 0;
  padding-bottom: 4px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#eotjbcumxw .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#eotjbcumxw .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#eotjbcumxw .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#eotjbcumxw .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#eotjbcumxw .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#eotjbcumxw .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#eotjbcumxw .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#eotjbcumxw .gt_group_heading {
  padding: 8px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
}

#eotjbcumxw .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#eotjbcumxw .gt_from_md > :first-child {
  margin-top: 0;
}

#eotjbcumxw .gt_from_md > :last-child {
  margin-bottom: 0;
}

#eotjbcumxw .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#eotjbcumxw .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 12px;
}

#eotjbcumxw .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#eotjbcumxw .gt_first_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
}

#eotjbcumxw .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#eotjbcumxw .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#eotjbcumxw .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#eotjbcumxw .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#eotjbcumxw .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#eotjbcumxw .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding: 4px;
}

#eotjbcumxw .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#eotjbcumxw .gt_sourcenote {
  font-size: 90%;
  padding: 4px;
}

#eotjbcumxw .gt_left {
  text-align: left;
}

#eotjbcumxw .gt_center {
  text-align: center;
}

#eotjbcumxw .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#eotjbcumxw .gt_font_normal {
  font-weight: normal;
}

#eotjbcumxw .gt_font_bold {
  font-weight: bold;
}

#eotjbcumxw .gt_font_italic {
  font-style: italic;
}

#eotjbcumxw .gt_super {
  font-size: 65%;
}

#eotjbcumxw .gt_footnote_marks {
  font-style: italic;
  font-size: 65%;
}
</style>
<div id="eotjbcumxw" style="overflow-x:auto;overflow-y:auto;width:auto;height:auto;"><table class="gt_table" style="table-layout: fixed;">
  <colgroup>
    <col/>
    <col/>
    <col style="width:475px;"/>
  </colgroup>
  
  <thead class="gt_col_headings">
    <tr>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1">Variable</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1"><strong>N = 392</strong><sup class="gt_footnote_marks">1</sup></th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1">Definition</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr>
      <td class="gt_row gt_left">age_grp</td>
      <td class="gt_row gt_left"></td>
      <td class="gt_row gt_left">Age group</td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">0 to 19</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">20 to 29</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">30 to 39</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">40 to 49</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">50 to 59</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">60 to 69</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">70 to 79</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">80 and older</td>
      <td class="gt_row gt_left">49 (12%)</td>
      <td class="gt_row gt_left"></td>
    </tr>
    <tr>
      <td class="gt_row gt_left">weekly_cases</td>
      <td class="gt_row gt_left">788 (399, 2,106)</td>
      <td class="gt_row gt_left">Weekly count of COVID-19 confirmed cases</td>
    </tr>
    <tr>
      <td class="gt_row gt_left">prop_cases</td>
      <td class="gt_row gt_left">0.97 (0.62, 2.95)</td>
      <td class="gt_row gt_left">Number of cases scaled to per 1000 residents per age group</td>
    </tr>
  </tbody>
  
  <tfoot>
    <tr class="gt_footnotes">
      <td colspan="3">
        <p class="gt_footnote">
          <sup class="gt_footnote_marks">
            <em>1</em>
          </sup>
          n (%); Median (IQR)
          <br />
        </p>
      </td>
    </tr>
  </tfoot>
</table></div>

  
  
  
