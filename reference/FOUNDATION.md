# Forecast with a pretrained time-series model

`FOUNDATION()` provides access to large pretrained forecasting models
within `fable`. Unlike traditional statistical models, these models do
not require training on the supplied data. The fitting step stores the
observed history, and forecasts are generated directly from the
pretrained model.

## Usage

``` r
FOUNDATION(
  formula,
  backend = c("chronos", "timesfm", "sundial", "moirai"),
  model_id = NULL,
  device = c("cpu", "cuda"),
  n_samples = 200L
)
```

## Arguments

- formula:

  The series to forecast, for example `observation`. For count data, use
  `log(observation)` if variance stabilisation is required. `fable`
  automatically back-transforms forecasts. Additional predictors are not
  supported.

- backend:

  Pretrained model backend to use: `"chronos"`, `"timesfm"`,
  `"sundial"`, or `"moirai"`.

- model_id:

  Optional Hugging Face model identifier. If `NULL`, the default model
  for the selected backend is used.

- device:

  Computation device: `"cpu"` (default) or `"cuda"`.

- n_samples:

  Number of forecast samples to generate. Defaults to `200`.

## Value

A `fable` model specification for use with
[`model`](https://fabletools.tidyverts.org/reference/model.html),
[`get_cv`](https://accidda.github.io/insight.cast/reference/get_cv.md),
or
[`get_fcast`](https://accidda.github.io/insight.cast/reference/get_fcast.md).

## Details

Forecasts are returned in the same format as other `fable` models,
allowing them to be used with functions such as
[`get_cv`](https://accidda.github.io/insight.cast/reference/get_cv.md)
and
[`get_fcast`](https://accidda.github.io/insight.cast/reference/get_fcast.md).

The models run through Python using `reticulate`. On the first forecast
in a session, required Python dependencies and model weights are
installed and downloaded automatically. These are cached for subsequent
forecasts.

Available models (`backend`):

- `"chronos"`:

  Amazon Chronos. Default: `amazon/chronos-t5-small`.

- `"timesfm"`:

  Google TimesFM. Default: `google/timesfm-2.5-200m-pytorch`.

- `"sundial"`:

  Tsinghua Sundial. Default: `thuml/sundial-base-128m`.

- `"moirai"`:

  Salesforce Moirai. Default: `Salesforce/moirai-1.1-R-small`.

Some models provide only a limited number of quantiles, so extreme
prediction intervals may be approximate.

## See also

[`default_models`](https://accidda.github.io/insight.cast/reference/default_models.md)

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
ncast <- get_data("covid", "ny", revisions = TRUE) |> get_ncast()
get_fcast(ncast, models = c(
  default_models(),
  list(
    CHRONOS = FOUNDATION(log(observation), "chronos"),
    MOIRAI  = FOUNDATION(log(observation), "moirai")
  )
))
} # }
```
