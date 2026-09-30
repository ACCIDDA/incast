# Plot a forecast

Plot observed values with a model's median and 50% and 95% prediction
intervals. The ensemble is shown by default.

## Usage

``` r
# S3 method for class 'insightcast_fcast'
autoplot(object, model = "ENSEMBLE", ...)
```

## Arguments

- object:

  An `insightcast_fcast` object returned by
  [`get_fcast`](https://accidda.github.io/insight.cast/reference/get_fcast.md).

- model:

  The model to plot. Defaults to `"ENSEMBLE"`.

- ...:

  Ignored.

## Value

A ggplot object.

## Author

Cyril Geismar
