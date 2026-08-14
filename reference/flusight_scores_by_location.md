# Scores from the 2025–26 FluSight backtest by location

Scores from the 2025–26 FluSight backtest by location

## Usage

``` r
flusight_scores_by_location
```

## Format

A data frame with one row per model and location and these columns:

- model_id:

  Model identifier.

- location:

  Two-digit US location code.

- wis:

  Mean weighted interval score.

- interval_coverage_50:

  Empirical coverage of the 50 percent interval.

- interval_coverage_95:

  Empirical coverage of the 95 percent interval.

- wis_relative_skill:

  Pairwise relative WIS.

- wis_scaled_relative_skill:

  Relative WIS scaled to the `FluSight-ensemble`; values below one are
  better.

- count:

  Number of forecast tasks scored.

- model_group:

  One of `"FluSight ensemble"`, `"FluSight model"`, or `"incast model"`.

- state:

  Two-letter state abbreviation.

## Source

Forecasts and target data from the [FluSight Forecast Hub, version
1.2.0](https://github.com/cdcepi/FluSight-forecast-hub/tree/v1.2.0).

## See also

[flusight_scores](https://accidda.github.io/incast/reference/flusight_scores.md)
