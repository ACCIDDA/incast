# Fetch hospitalisation data

Fetch confirmed US hospital admissions (COVID-19, influenza or RSV) from
NHSN via
[pub_covidcast](https://cmu-delphi.github.io/epidatr/reference/pub_covidcast.html).

## Usage

``` r
get_data(pathogen, geo_value, revisions = FALSE)
```

## Arguments

- pathogen:

  One of "covid", "flu" or "rsv".

- geo_value:

  Geographic value(s) to fetch, as per
  [pub_covidcast](https://cmu-delphi.github.io/epidatr/reference/pub_covidcast.html).

- revisions:

  Logical. If `TRUE`, fetch the full revision history needed by
  [`get_ncast`](https://accidda.github.io/incast/reference/get_ncast.md).
  Default `FALSE` (latest only).

## Value

An `incast_data` object (see
[`check_data`](https://accidda.github.io/incast/reference/check_data.md)).

## Author

Cyril Geismar

## Examples

``` r
get_data(pathogen = "covid", geo_value = "ny")
#> Warning: No API key found. You will be limited to non-complex queries and encounter rate
#> limits if you proceed.
#> ℹ See `?save_api_key()` for details on obtaining and setting API keys.
#> This warning is displayed once every 8 hours.
#> <incast_data>
#> Target:   wk inc covid hosp
#> Series:   1 (location)
#> Window:   2020-08-08 to 2026-08-01 (7-day interval)

# Revision history for nowcasting
get_data(pathogen = "covid", geo_value = "ca", revisions = TRUE)
#> <incast_data>
#> Target:   wk inc covid hosp
#> Series:   1 (location)
#> Window:   2020-08-08 to 2026-08-01 (7-day interval)
#> History:  2024-11-17 to 2026-08-02
```
