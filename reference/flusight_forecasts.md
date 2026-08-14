# Forecasts from the 2025–26 FluSight backtest

Precomputed forecasts from every successfully fitted `incast` candidate.
For each state and forecast round, the candidate selected by real-time
cross-validation is duplicated with `model_id = "incast"`.

## Usage

``` r
flusight_forecasts
```

## Format

A data frame with 52,500 rows and 9 columns:

- model_id:

  Model identifier.

- reference_date:

  Date defining the forecast round.

- target:

  Forecast target.

- horizon:

  Forecast horizon in weeks, from 0 through 3.

- location:

  Two-digit US location code.

- target_end_date:

  End date of the predicted week.

- output_type:

  Forecast output type; always `"quantile"`.

- output_type_id:

  Quantile probability.

- value:

  Forecast value.

## Source

Generated with `incast` from CDC NHSN influenza hospital admission data
for the 2025–26 FluSight season.
