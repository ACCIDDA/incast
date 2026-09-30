# Weekly influenza hospital admissions for New York and California

Weekly confirmed influenza hospital admissions for New York and
California, with revision history, fetched from CDC NHSN through
[`get_data()`](https://accidda.github.io/insight.cast/reference/get_data.md).

## Usage

``` r
example_data
```

## Format

A data frame with 5 columns:

- as_of:

  Date the observation was reported.

- location:

  State abbreviation (`"NY"` or `"CA"`).

- target:

  Forecast target (`"wk inc flu hosp"`).

- target_end_date:

  End date of the epidemiological week.

- observation:

  Confirmed hospital admissions count.

## Source

CDC NHSN via
[`pub_covidcast`](https://cmu-delphi.github.io/epidatr/reference/pub_covidcast.html).

## Details

The archive is pinned to 14 December 2025 so the latest weeks remain
incomplete. Pass it to
[`check_data()`](https://accidda.github.io/insight.cast/reference/check_data.md)
before use. Regenerate it with `data-raw/example_data.R`.

## Examples

``` r
example_data |> check_data()
#> <insightcast_data>
#> Target:   wk inc flu hosp
#> Series:   2 (location)
#> Window:   2022-06-04 to 2025-12-13 (7-day interval)
#> History:  2024-11-17 to 2025-12-14
```
