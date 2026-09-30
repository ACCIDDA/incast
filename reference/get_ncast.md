# Nowcast right-truncated surveillance data

Estimate final counts for recent, incomplete weeks using
[baselinenowcast](https://baselinenowcast.epinowcast.org/). The last
`max_delay` weeks are replaced; earlier observations are unchanged.
Downward revisions are redistributed with
[`baselinenowcast::preprocess_negative_values()`](https://baselinenowcast.epinowcast.org/reference/preprocess_negative_values.html).

## Usage

``` r
get_ncast(x, max_delay = 2, draws = 1000, prop_delay = 0.5, scale_factor = 3)
```

## Arguments

- x:

  An `insightcast_data` object with revision history.

- max_delay:

  Number of recent weeks to nowcast. Defaults to `2`.

- draws:

  Number of posterior samples. Defaults to `1000`.

- prop_delay:

  Proportion of reference times used to estimate delays. Must be between
  0 and 1. Defaults to `0.5`.

- scale_factor:

  Multiplier applied to `max_delay` to set the estimation window.
  Defaults to `3`.

## Value

An `insightcast_ncast` object with the shared backbone (`key`, `target`,
`window`, `interval`, `history`) plus:

- data:

  Corrected series with `ncast_lower` and `ncast_upper` 95% credible
  interval bounds.

- meta:

  Nowcast settings and a per-series `ncast_summary`.

## Details

Weekly data only; other cadences are rejected (the rest of the pipeline
is cadence-agnostic).

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
x <- get_data(pathogen = "covid", geo_value = "ca", revisions = TRUE)
ncast <- get_ncast(x)
autoplot(ncast)
} # }
```
