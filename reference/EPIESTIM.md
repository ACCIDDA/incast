# EpiEstim model for fable

Estimate the effective reproduction number (Rt) with
[`EpiEstim::estimate_R()`](https://mrc-ide.github.io/EpiEstim/reference/estimate_R.html)
and forecast with
[`projections::project()`](https://www.repidemicsconsortium.org/projections/reference/project.html).

## Usage

``` r
EPIESTIM(
  formula,
  mean_si,
  std_si,
  rt_window = 14L,
  n_sim = 100L,
  R_fix_within = TRUE
)
```

## Arguments

- formula:

  Response variable to model, for example `observation`. External
  predictors are not supported.

- mean_si:

  Mean serial interval in days.

- std_si:

  Standard deviation of the serial interval in days.

- rt_window:

  Length of the sliding window (in days) used to estimate Rt. Smaller
  values respond more quickly to recent changes, while larger values
  provide smoother estimates. Defaults to `14`.

- n_sim:

  Number of simulated forecast trajectories. Defaults to `100`.

- R_fix_within:

  Logical indicating whether Rt is held constant within each simulated
  trajectory. Recommended for short forecast horizons.

## Value

A `fable` model specification for use with
[`model`](https://fabletools.tidyverts.org/reference/model.html).

## Author

Cyril Geismar

## Examples

``` r
if (FALSE) { # \dontrun{
example_data |>
  get_fcast(models = EPIESTIM(
    observation,
    mean_si = 4.7,
    std_si = 2.9,
    rt_window = 7
  ))
} # }
```
