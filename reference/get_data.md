# Fetch hospitalisation data

Fetch confirmed US hospital admissions for COVID-19, influenza or RSV
from NHSN through
[`epidatr::pub_covidcast()`](https://cmu-delphi.github.io/epidatr/reference/pub_covidcast.html).

## Usage

``` r
get_data(pathogen, geo_value, revisions = FALSE)
```

## Arguments

- pathogen:

  One of `"covid"`, `"flu"` or `"rsv"`.

- geo_value:

  Geographic values accepted by
  [`epidatr::pub_covidcast()`](https://cmu-delphi.github.io/epidatr/reference/pub_covidcast.html).

- revisions:

  Fetch revision history for
  [`get_ncast()`](https://accidda.github.io/incast/reference/get_ncast.md).
  Defaults to `FALSE`.

## Value

An `incast_data` object (see
[`check_data`](https://accidda.github.io/incast/reference/check_data.md)).

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
get_data(pathogen = "covid", geo_value = "ny")

get_data(pathogen = "covid", geo_value = "ca", revisions = TRUE)
} # }
```
