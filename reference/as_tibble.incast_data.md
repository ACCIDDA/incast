# Plot-ready tibbles from pipeline objects

The data behind each object's
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html),
for building custom plots:

- `incast_data`:

  Observed counts, one row per series and `target_end_date` (latest
  reported value per date when revisions are present).

- `incast_ncast`:

  Weekly nowcast summary, one row per series and reporting week
  (`reference_date`): `median`, 50% (`q25`, `q75`) and 95% (`lower`,
  `upper`) credible intervals, and the reported-so-far `observed` count.

- `incast_fcast`:

  Forecast quantiles per model, one row per `model_id`, series and
  `target_end_date`: `median`, 50% (`q25`, `q75`) and 95% (`lower`,
  `upper`) prediction intervals. Observed counts for context are in
  `x$hub$oracle_output`.

## Usage

``` r
# S3 method for class 'incast_data'
as_tibble(x, ...)

# S3 method for class 'incast_ncast'
as_tibble(x, ...)

# S3 method for class 'incast_fcast'
as_tibble(x, ...)
```

## Arguments

- x:

  An `incast_data`, `incast_ncast` or `incast_fcast` object.

- ...:

  Ignored.

## Value

A tibble.

## See also

[`autoplot.incast_data`](https://accidda.github.io/incast/reference/autoplot.incast_data.md),
[`autoplot.incast_ncast`](https://accidda.github.io/incast/reference/autoplot.incast_ncast.md),
[`autoplot.incast_fcast`](https://accidda.github.io/incast/reference/autoplot.incast_fcast.md)

## Author

Cyril Geismar

## Examples

``` r
example_data |>
  check_data() |>
  as_tibble()
#> # A tibble: 370 × 4
#>    location target          target_end_date observation
#>    <chr>    <chr>           <date>                <dbl>
#>  1 CA       wk inc flu hosp 2022-06-04              432
#>  2 NY       wk inc flu hosp 2022-06-04              124
#>  3 CA       wk inc flu hosp 2022-06-11              391
#>  4 NY       wk inc flu hosp 2022-06-11              103
#>  5 CA       wk inc flu hosp 2022-06-18              305
#>  6 NY       wk inc flu hosp 2022-06-18               92
#>  7 CA       wk inc flu hosp 2022-06-25              238
#>  8 NY       wk inc flu hosp 2022-06-25               65
#>  9 CA       wk inc flu hosp 2022-07-02              193
#> 10 NY       wk inc flu hosp 2022-07-02               45
#> # ℹ 360 more rows
```
