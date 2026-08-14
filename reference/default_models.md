# Default forecasting models

Return the models used by
[`get_cv()`](https://accidda.github.io/incast/reference/get_cv.md) and
[`get_fcast()`](https://accidda.github.io/incast/reference/get_fcast.md)
by default.

## Usage

``` r
default_models()
```

## Value

A named list of `fable` model specifications.

## Details

The set contains naive, ETS, Theta and ARIMA models fitted to
`log(observation + 1)`. `fable` transforms forecasts back to the count
scale.

Extend the list to add models:
`c(default_models(), list(CUSTOM = fable::ARIMA(observation)))`.

## Author

Cyril Geismar

## Examples

``` r
default_models()
#> $NAIVE
#> <RW model definition>
#> 
#> $ETS
#> <ETS model definition>
#> 
#> $THETA
#> <theta model definition>
#> 
#> $ARIMA
#> <ARIMA model definition>
#> 
```
