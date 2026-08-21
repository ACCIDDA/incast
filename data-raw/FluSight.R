# Packages the saved FluSight backtest and regenerates its score tables.
#
# This script does not refit any incast models. It reads data-raw/incast.csv,
# saves it as a compressed package dataset, downloads the matching FluSight
# forecasts and truth, and recomputes the summaries in vignettes/FluSight.Rmd.

library(dplyr)
library(hubData)
library(hubEvals)

states <- c("CT", "FL", "MD", "NJ", "NY", "NC", "PA")

locations <- read.csv(
  paste0(
    "https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/",
    "v1.2.0/auxiliary-data/locations.csv"
  )
) |>
  as_tibble() |>
  filter(abbreviation %in% states)

hub_fcast <- hubData::connect_hub(
  hubData::s3_bucket("cdcepi-flusight-forecast-hub"),
  file_format = "parquet"
) |>
  filter(
    target == "wk inc flu hosp",
    reference_date >= as.Date("2025-11-22"),
    reference_date <= as.Date("2026-05-23"),
    location %in% locations$location,
    horizon %in% 0:3,
    output_type == "quantile",
    output_type_id %in% c("0.025", "0.25", "0.5", "0.75", "0.975")
  ) |>
  hubData::collect_hub() |>
  # Keep team submissions plus the Hub's ensemble and naive baseline. Other
  # model IDs beginning with "FluSight-" are alternative aggregates, not
  # individual team submissions.
  filter(
    model_id %in% c("FluSight-ensemble", "FluSight-baseline") |
      !startsWith(model_id, "FluSight-")
  )

flusight_submissions <- setdiff(
  unique(hub_fcast$model_id),
  c("FluSight-ensemble", "FluSight-baseline")
)

truth <- read.csv(
  paste0(
    "https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/",
    "v1.2.0/target-data/target-hospital-admissions.csv"
  ),
  colClasses = c(location = "character")
) |>
  as_tibble() |>
  transmute(
    location,
    target_end_date = as.Date(date),
    target = "wk inc flu hosp",
    output_type = "quantile",
    output_type_id = NA_character_,
    oracle_value = value
  )

flusight_forecasts <- read.csv(
  file.path("data-raw", "incast.csv"),
  colClasses = c(location = "character")
) |>
  as_tibble() |>
  mutate(
    reference_date = as.Date(reference_date),
    target_end_date = as.Date(target_end_date),
    output_type_id = as.character(output_type_id)
  )

usethis::use_data(
  flusight_forecasts,
  overwrite = TRUE,
  compress = "xz"
)

score_forecasts <- function(model_out_tbl, by) {
  hubEvals::score_model_out(
    model_out_tbl = model_out_tbl,
    oracle_output = truth,
    metrics = c("wis", "interval_coverage_50", "interval_coverage_95"),
    relative_metrics = "wis",
    baseline = "FluSight-ensemble",
    by = by,
    include_count = TRUE
  )
}

add_model_group <- function(x) {
  x |>
    mutate(
      model_group = case_when(
        model_id == "FluSight-ensemble" ~ "FluSight ensemble",
        model_id == "FluSight-baseline" ~ "FluSight baseline",
        model_id %in% flusight_submissions ~ "FluSight model",
        TRUE ~ "incast model"
      )
    )
}

all_scores <- bind_rows(flusight_forecasts, hub_fcast) |>
  score_forecasts(by = "model_id") |>
  add_model_group() |>
  arrange(wis_scaled_relative_skill)

# Reference models: the top three submissions plus the ones ranked nearest the
# 50th and 75th percentiles, among submissions covering at least 90% of the
# scored forecasts.
ranked_submissions <- all_scores |>
  filter(model_group == "FluSight model", count >= 0.9 * max(count)) |>
  arrange(wis_scaled_relative_skill)

comparison_models <- c(
  head(ranked_submissions$model_id, 3),
  ranked_submissions$model_id[
    ceiling(c(0.5, 0.75) * nrow(ranked_submissions))
  ]
)

flusight_scores <- all_scores |>
  mutate(
    display = model_group != "FluSight model" |
      model_id %in% comparison_models
  )

# The two odin2 models have extremely large location-specific scores and make
# the faceted comparison unreadable. They remain in the overall score table.
flusight_scores_by_location <- bind_rows(
  flusight_forecasts |> filter(!startsWith(model_id, "ODIN2")),
  hub_fcast
) |>
  score_forecasts(by = c("model_id", "location")) |>
  add_model_group() |>
  mutate(
    state = locations$abbreviation[match(location, locations$location)],
    display = model_group != "FluSight model" |
      model_id %in% comparison_models
  ) |>
  arrange(state, wis_scaled_relative_skill)

usethis::use_data(
  flusight_scores,
  flusight_scores_by_location,
  overwrite = TRUE,
  compress = "xz"
)
