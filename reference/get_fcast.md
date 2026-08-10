# Produce a forward forecast

Fit forecasting models to the full time series and generate forecasts
for the next `h` reporting intervals.

## Usage

``` r
get_fcast(
  x,
  models = default_models(),
  h = 4,
  top_n = 3,
  ensemble = c("linear_pool", "quantile_average")
)
```

## Arguments

- x:

  An `incast_*` object.

- models:

  Named list of ordinary `fable` or joint incast model specifications,
  such as [`HHH4`](https://accidda.github.io/incast/reference/HHH4.md).
  Defaults to
  [`default_models`](https://accidda.github.io/incast/reference/default_models.md).
  When `x` is an `incast_cv` object, leave unset to use the top-ranked
  models from cross-validation, or provide a custom set of models.

- h:

  Integer giving the forecast horizon in reporting intervals. Defaults
  to `4`. When `x` is an `incast_cv` object, the default is the
  cross-validation horizon.

- top_n:

  Integer giving the number of top-ranked models to combine into the
  ensemble for each series. Used only when `x` is an `incast_cv` object
  and `models` is not provided. Defaults to `3`.

- ensemble:

  Method used to combine the models into the `ENSEMBLE` forecast.
  `"linear_pool"` (default) mixes the models' predictive distributions
  with equal weights. `"quantile_average"` takes, at each quantile
  level, the median of the models' quantiles using
  [`simple_ensemble`](https://hubverse-org.github.io/hubEnsembles/reference/simple_ensemble.html)

## Value

An `incast_fcast` object containing:

- hub:

  Hub-format forecasts containing `model_out_tbl` and `oracle_output`.

- score:

  Cross-validation model performance scores, or `NULL`.

- meta:

  Forecast settings including models, model selection, ensemble method,
  horizon, series keys, target, reporting interval, nowcast information,
  and evaluation date.

Forecast outputs can be exported with
[`to_respilens`](https://accidda.github.io/incast/reference/to_respilens.md).

## Details

When provided with an `incast_cv` object, the function uses the
cross-validation results to select the best-performing models for each
series and combines them into an equal-weight ensemble. For
`incast_data` or `incast_ncast` objects, all models in `models` are
fitted and forecast.

If the input contains nowcast uncertainty from
[`get_ncast`](https://accidda.github.io/incast/reference/get_ncast.md),
this uncertainty is incorporated into the forecast intervals.

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
ncast <- get_data("covid", "ny", revisions = TRUE) |> get_ncast()
cv <- ncast |> get_cv(eval_start_date = "2025-01-01", h = 4)

get_fcast(cv, top_n = 3) # use cross-validation rankings
get_fcast(cv, models = default_models()) # use custom models
get_fcast(ncast) # forecast directly from nowcast data
} # }
```
