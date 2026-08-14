# Plot cross-validation model rankings

Plot model performance using weighted interval score (WIS). Relative WIS
is shown for multiple models; values below 1 are better than average.
Raw WIS is shown for one model.

## Usage

``` r
# S3 method for class 'incast_cv'
autoplot(object, ...)
```

## Arguments

- object:

  An `incast_cv` object returned by
  [`get_cv`](https://accidda.github.io/incast/reference/get_cv.md).

- ...:

  Ignored.

## Value

A ggplot object.

## Author

Cyril Geismar
