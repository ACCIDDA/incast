# Cross-validate forecasting models

Evaluate forecasting models using expanding-window time-series
cross-validation. Starting from `eval_start_date`, models are refitted
at each forecast origin and evaluated over the next `h` time steps.

## Usage

``` r
get_cv(
  x,
  eval_start_date = NULL,
  h = 4,
  models = default_models(),
  step = h,
  n_origins = NULL
)
```

## Arguments

- x:

  An `incast_ncast` object from
  [`get_ncast`](https://accidda.github.io/incast/reference/get_ncast.md)
  or an `incast_data` object from
  [`check_data`](https://accidda.github.io/incast/reference/check_data.md)
  or
  [`get_data`](https://accidda.github.io/incast/reference/get_data.md).

- eval_start_date:

  Date (or character string coercible to a date) giving the first
  forecast origin to evaluate. Must fall within the data window. All
  earlier observations are used as the initial training period. This
  argument is exclusive with `n_origins`.

- h:

  Integer giving the forecast horizon in reporting intervals (for
  example, weeks for weekly data). Defaults to `4`.

- models:

  Named list of `fable` or joint incast model specifications, such as
  [`HHH4`](https://accidda.github.io/incast/reference/HHH4.md). Defaults
  to
  [`default_models`](https://accidda.github.io/incast/reference/default_models.md).

- step:

  Integer giving the number of reporting intervals between successive
  cross-validation origins. Defaults to `h`, resulting in
  non-overlapping evaluation periods.

- n_origins:

  Integer giving the number of forecast origins to evaluate, as an
  alternative to `eval_start_date`. Origins are placed so that the last
  forecast ends at the last observation:
  `eval_start_date = t - ((h - 1) + (n_origins - 1) * step) * interval`,
  where `t` is the last observation date. This argument is exclusive
  with `eval_start_date`.

## Value

An `incast_cv` object containing:

- forecasts:

  Forecasts for each model, series, and cross-validation origin.

- oracle:

  Observed values used for scoring.

- score:

  Model performance metrics, including WIS and interval coverage, for
  each model and series.

- models:

  The evaluated model specifications.

- meta:

  Cross-validation settings including dates, horizon, step, number of
  origins, series keys, target, and reporting interval.

- data:

  Input data with revisions collapsed, used by
  [`get_fcast`](https://accidda.github.io/incast/reference/get_fcast.md).

## Details

Forecast performance is measured using weighted interval score (WIS) and
interval coverage. Models are ranked separately for each series, and the
resulting rankings are used by
[`get_fcast`](https://accidda.github.io/incast/reference/get_fcast.md).

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
cv <- get_data("covid", "ny", revisions = TRUE) |>
  get_ncast() |>
  get_cv(h = 4, n_origins = 16)

# or give the first forecast origin directly:
cv <- get_data("covid", "ny", revisions = TRUE) |>
  get_ncast() |>
  get_cv(eval_start_date = "2025-01-01", h = 4)

cv$score
} # }
```
