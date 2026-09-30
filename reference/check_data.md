# Validate surveillance data

Validate and standardise surveillance data for nowcasting and
forecasting.

## Usage

``` r
check_data(data, key = "location")
```

## Arguments

- data:

  A data frame with `target_end_date` (`Date`), `observation` (numeric),
  `target` (character) and the key columns. Add `as_of` (`Date`) for
  revision history. An `insightcast_data` object is returned unchanged.

- key:

  Character vector naming the columns that identify a series. Defaults
  to `"location"`.

## Value

An `insightcast_data` object containing:

- data:

  Validated data with standardised column types.

- key:

  Names of the key columns.

- target:

  Target variable name.

- window:

  Start and end dates of the data.

- interval:

  Reporting interval in days.

- history:

  Logical indicating whether multiple revisions are available.

## Details

Data must contain one row per time series and reporting date (and
`as_of`, if present). All series must have the same reporting interval,
share the same reporting dates, and end on the same date. Series may
begin at different times and may contain missing reporting periods.

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
x <- get_data("covid", c("ny", "ca")) |> check_data()
my_x <- read.csv("my_data.csv") |>
  check_data(key = c("location", "age_group"))
} # }
```
