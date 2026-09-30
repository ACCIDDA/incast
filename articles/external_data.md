# Preparing External Data

## Required columns

Pass external surveillance data to
[`check_data()`](https://accidda.github.io/insight.cast/reference/check_data.md)
before nowcasting or forecasting.

The data frame needs four columns:

| Column            | Type      | Description                         |
|-------------------|-----------|-------------------------------------|
| `target_end_date` | Date      | Date represented by the observation |
| `observation`     | numeric   | Observed value                      |
| `location`        | character | Series identifier                   |
| `target`          | character | Target identifier                   |

Add `as_of` to nowcast reporting delays:

| Column  | Type | Description                    |
|---------|------|--------------------------------|
| `as_of` | Date | Date this version was reported |

Use one row per series and `target_end_date`, or one row per revision
when `as_of` is present. Keep one target per call. All series must use
the same reporting interval, calendar and end date, although they may
start on different dates.

`location` is the default series key. Name other key columns with `key`,
for example `check_data(df, key = c("location", "age_group"))`.

## Example

``` r

library(insight.cast)
head(df)
```

    ##   target_end_date observation location             target
    ## 1      2024-01-01          13       NY inc hosp influenza
    ## 2      2024-01-08          15       NY inc hosp influenza
    ## 3      2024-01-15          19       NY inc hosp influenza
    ## 4      2024-01-22          22       NY inc hosp influenza
    ## 5      2024-01-29          25       NY inc hosp influenza
    ## 6      2024-02-05          11       NY inc hosp influenza

``` r

checked <- check_data(df)
checked
```

    ## <insightcast_data>
    ## Target:   inc hosp influenza
    ## Series:   1 (location)
    ## Window:   2024-01-01 to 2024-12-23 (7-day interval)

Use the result directly with
[`get_cv()`](https://accidda.github.io/insight.cast/reference/get_cv.md)
or
[`get_fcast()`](https://accidda.github.io/insight.cast/reference/get_fcast.md).
Use
[`get_ncast()`](https://accidda.github.io/insight.cast/reference/get_ncast.md)
first when revision history is available.
