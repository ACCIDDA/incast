# Joint endemic-epidemic model

`HHH4()` fits
[`surveillance::hhh4()`](https://rdrr.io/pkg/surveillance/man/hhh4.html)
jointly to all series and returns simulated forecasts for
[`get_cv()`](https://accidda.github.io/insight.cast/reference/get_cv.md)
and
[`get_fcast()`](https://accidda.github.io/insight.cast/reference/get_fcast.md).

## Usage

``` r
HHH4(formula, control, neighbourhood = NULL, population = NULL, n_sim = 500L)
```

## Arguments

- formula:

  Use `observation`. Units come from the single key supplied to
  [`check_data()`](https://accidda.github.io/insight.cast/reference/check_data.md).

- control:

  A
  [`surveillance::hhh4()`](https://rdrr.io/pkg/surveillance/man/hhh4.html)
  control list.

- neighbourhood:

  Optional named adjacency or neighbourhood-order matrix.

- population:

  Optional named population vector or time-by-unit matrix.

- n_sim:

  Number of joint forecast simulations. Defaults to `500`.

## Value

A joint model specification for
[`get_cv()`](https://accidda.github.io/insight.cast/reference/get_cv.md)
or
[`get_fcast()`](https://accidda.github.io/insight.cast/reference/get_fcast.md).

## Details

Model components and `control` options are documented in
[`surveillance::hhh4()`](https://rdrr.io/pkg/surveillance/man/hhh4.html).
`insight.cast` manages `control$subset`, so do not supply it. Data must
have one series key, and all unit-indexed inputs must be named with its
values. Fractional observations are rounded to counts before fitting.

## See also

[`vignette("hhh4")`](https://accidda.github.io/insight.cast/articles/hhh4.md),
[`surveillance::hhh4()`](https://rdrr.io/pkg/surveillance/man/hhh4.html)

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
states <- c("CT", "NY")
W <- matrix(
  c(0, 1, 1, 0),
  2, 2,
  byrow = TRUE,
  dimnames = list(states, states)
)
population <- c(CT = 3.6, NY = 20)
population <- population / sum(population)

get_data("flu", tolower(states)) |>
  get_cv(
    h = 4,
    n_origins = 8,
    models = list(
      HHH4 = HHH4(
        observation,
        control = list(
          ar = list(f = ~1),
          ne = list(f = ~1, normalize = TRUE),
          end = list(
            f = surveillance::addSeason2formula(~1, S = 1, period = 52)
          ),
          family = "NegBin1"
        ),
        neighbourhood = W,
        population = population
      )
    )
  )
} # }
```
