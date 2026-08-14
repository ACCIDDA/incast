# Forecasting the 2026 Ebola Outbreak

## Overview

In May 2026, the Democratic Republic of the Congo reported an Ebola
outbreak caused by the Bundibugyo strain. By July, 2,423 cases and 967
deaths had been reported. This example forecasts incidence using
surveillance data from the [Institut National de Recherche
Biomédicale](https://github.com/INRB-UMIE/BDBV2026-Data).

The vignette loads precomputed data, cross-validation and forecast
objects. Model-fitting chunks are disabled, but all plots are generated
when the article is built.

## Data

The example uses the six locations with the most confirmed cases.
Missing days carry the previous cumulative count forwards, and downward
revisions are removed. Leading zeros are dropped before log
transformation.

``` r

library(dplyr)
library(tidyr)
library(ggplot2)

ebola <- read.csv(
  "https://raw.githubusercontent.com/scc-usc/ebola2026/refs/heads/main/hubverse_observed_data.csv"
) |>
  filter(
    target == "insp_sitrep__cumulative_confirmed_cases__daily",
    !is.na(location)
  ) |>
  mutate(target_end_date = as.Date(target_end_date))

top_locations <- ebola |>
  slice_max(target_end_date, by = location) |>
  slice_max(observation, n = 6) |>
  pull(location)

ebola <- ebola |>
  filter(location %in% top_locations) |>
  arrange(location, target_end_date) |>
  group_by(location) |>
  complete(
    target_end_date = seq(
      min(target_end_date),
      max(target_end_date),
      by = "day"
    )
  ) |>
  fill(observation, .direction = "down") |>
  mutate(observation = cummax(coalesce(observation, 0))) |>
  filter(cumsum(observation > 0) > 0) |>
  ungroup() |>
  mutate(target = "insp_sitrep__cumulative_confirmed_cases__daily")
```

## `incast` workflow

### Validate the data

[`check_data()`](https://accidda.github.io/incast/reference/check_data.md)
standardises the columns and returns an `incast_data` object.

``` r

library(incast)
data <- ebola |> check_data()
```

``` r

data
#> <incast_data>
#> Target:   insp_sitrep__cumulative_confirmed_cases__daily
#> Series:   6 (location)
#> Window:   2026-05-15 to 2026-07-26 (1-day interval)
data |> autoplot()
```

![Daily cumulative confirmed cases by
location.](ebola_2026_files/figure-html/show-data-1.png)

Daily cumulative confirmed cases by location.

Revision history is unavailable, so the workflow skips
[`get_ncast()`](https://accidda.github.io/incast/reference/get_ncast.md).

### Cross-validation

Compare the default models with a custom ARIMA model, a neural network,
Prophet and four foundation models:

``` r

library(fable)
library(fable.prophet)

models <- c(
  default_models(),
  list(
    CUSTOM_ARIMA = ARIMA(log(observation) ~ pdq(1, 1, 0)),
    NNETAR = NNETAR(log(observation), n_networks = 10),
    PROPHET = prophet(log(observation)),
    CHRONOS = FOUNDATION(log(observation), "chronos"),
    TIMESFM = FOUNDATION(log(observation), "timesfm"),
    SUNDIAL = FOUNDATION(log(observation), "sundial"),
    MOIRAI = FOUNDATION(log(observation), "moirai")
  )
)
```

Forecast seven days ahead from 16 daily origins. The evaluation covers
22 days.

``` r

cv <- data |>
  get_cv(
    h = 7,
    step = 1,
    n_origins = 16,
    models = models
  )
```

``` r

cv
#> <incast_cv>
#> Target:   insp_sitrep__cumulative_confirmed_cases__daily
#> Series:   6 (location)
#> Window:   2026-05-15 to 2026-07-26 (1-day interval)
#> CV:       11 models x 16 origins (h = 7)
cv |>
  autoplot() +
  ggplot2::scale_x_continuous(transform = "log2")
```

![Cross-validation performance by model and
location.](ebola_2026_files/figure-html/show-cv-1.png)

Cross-validation performance by model and location.

[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
shows relative WIS from `cv$score`. Raw WIS depends on the scale of each
series; relative WIS supports comparison across locations. On the log
scale, 0.5 and 2 are equally far from the reference value of 1.

Use `cv$score` for custom summaries, such as raw WIS by model and
location:

``` r

cv$score |>
  group_by(location) |>
  arrange(wis, .by_group = TRUE) |>
  mutate(model_id_ordered = paste(model_id, location, sep = "__")) |>
  ggplot(aes(y = reorder(model_id_ordered, wis), x = wis)) +
  facet_wrap(~location, scales = "free") +
  geom_col(aes(fill = model_id), show.legend = FALSE) +
  scale_y_discrete(labels = \(x) sub("__.*$", "", x)) +
  theme_classic() +
  labs(y = "Model", x = "WIS")
```

![](ebola_2026_files/figure-html/cv-custom-plot-1.png)

### Forecasting

By default,
[`get_fcast()`](https://accidda.github.io/incast/reference/get_fcast.md)
combines the three best models for each location.

``` r

fcast <- cv |> get_fcast()
```

``` r

fcast
#> <incast_fcast>
#> Target:   insp_sitrep__cumulative_confirmed_cases__daily
#> Series:   6 (location)
#> Forecast: 2026-07-27 to 2026-08-02 (h = 7)
#> Models:   9 + ENSEMBLE
fcast$meta$selection
#> # A tibble: 18 × 2
#>    location  model_id    
#>    <chr>     <chr>       
#>  1 Bunia     SUNDIAL     
#>  2 Bunia     TIMESFM     
#>  3 Bunia     MOIRAI      
#>  4 Katwa     NNETAR      
#>  5 Katwa     MOIRAI      
#>  6 Katwa     PROPHET     
#>  7 Lita      PROPHET     
#>  8 Lita      THETA       
#>  9 Lita      ARIMA       
#> 10 Mongbwalu MOIRAI      
#> 11 Mongbwalu NNETAR      
#> 12 Mongbwalu SUNDIAL     
#> 13 Nizi      ETS         
#> 14 Nizi      ARIMA       
#> 15 Nizi      CUSTOM_ARIMA
#> 16 Rwampara  SUNDIAL     
#> 17 Rwampara  TIMESFM     
#> 18 Rwampara  NNETAR
```

[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
shows the median and 50% and 95% prediction intervals.

``` r

fcast |> autoplot()
```

![Ensemble forecast by
location.](ebola_2026_files/figure-html/fcast-plot-1.png)

Ensemble forecast by location.

Use
[`as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
to build a custom plot:

``` r

fcast |>
  as_tibble() |>
  ggplot() +
  geom_ribbon(
    aes(x = target_end_date, ymin = lower, ymax = upper, fill = model_id),
    alpha = 0.2,
    show.legend = FALSE
  ) +
  geom_line(
    aes(x = target_end_date, y = median, colour = model_id),
    show.legend = TRUE
  ) +
  facet_wrap(~location, scales = "free") +
  geom_line(
    data = fcast$hub$oracle_output |>
      filter(target_end_date >= as.Date("2026-07-01")),
    aes(x = target_end_date, y = oracle_value),
    colour = "black"
  ) +
  theme_classic() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank()
  )
```

![Forecasts by model with observed values in
black.](ebola_2026_files/figure-html/fcast-custom-plot-1.png)

Forecasts by model with observed values in black.
