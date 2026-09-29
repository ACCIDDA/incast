# Regenerates data-raw/insight.cast.csv using a top-three ensemble for each state and
# forecast round. Run from the package root. Completed rounds are cached so an
# interrupted run can resume and future top_n changes can reuse CV results.

stopifnot(file.exists("DESCRIPTION"), file.exists("vignettes/FluSight.Rmd"))

devtools::load_all(".")

library(dplyr)
library(fable)
library(fable.prophet)
library(igraph)
library(insight.cast.odin)
library(reticulate)
library(surveillance)

states <- c("CT", "FL", "MD", "NJ", "NY", "NC", "PA")
cv_seasons <- 2022:2024
all_reference_dates <- seq.Date(
  from = as.Date("2025-11-22"),
  to = as.Date("2026-05-23"),
  by = "1 week"
)

shard_total <- as.integer(Sys.getenv("FLUSIGHT_SHARD_TOTAL", "1"))
shard_index <- as.integer(Sys.getenv("FLUSIGHT_SHARD_INDEX", "1"))
stopifnot(
  !is.na(shard_total), shard_total >= 1L,
  !is.na(shard_index), shard_index %in% seq_len(shard_total)
)

reference_dates <- all_reference_dates[
  (seq_along(all_reference_dates) - 1L) %% shard_total + 1L == shard_index
]

locations <- read.csv(
  paste0(
    "https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/",
    "v1.2.0/auxiliary-data/locations.csv"
  )
) |>
  as_tibble() |>
  filter(abbreviation %in% states)

revision_history <- get_data(
  pathogen = "flu",
  geo_value = tolower(states),
  revisions = TRUE
)$data

population <- locations |>
  mutate(population = population / sum(population)) |>
  pull(population, name = abbreviation)

neighbourhood <- graph_from_data_frame(
  rbind(
    c("CT", "NY"),
    c("MD", "PA"),
    c("NJ", "NY"),
    c("NJ", "PA"),
    c("NY", "PA")
  ),
  directed = FALSE,
  vertices = locations$abbreviation
) |>
  as_adjacency_matrix(sparse = FALSE)

annual_seasonality <- addSeason2formula(
  f = ~1,
  S = 1,
  period = round(365.25 / 7)
)

my_models <- c(
  default_models(),
  list(
    CUSTOM_ARIMA = ARIMA(observation ~ pdq(1, 1, 0)),
    ODIN2_SIR = odin_sir(observation),
    ODIN2_SEIR = odin_seir(observation),
    HHH4_AR_END = HHH4(
      observation,
      control = list(
        ar = list(f = ~1, lag = 1),
        ne = list(f = ~ -1),
        end = list(f = annual_seasonality),
        family = "NegBin1"
      ),
      population = population
    ),
    HHH4_FULL = HHH4(
      observation,
      control = list(
        ar = list(f = ~1, lag = 1),
        ne = list(f = ~1, lag = 1, normalize = FALSE),
        end = list(f = annual_seasonality),
        family = "NegBin1"
      ),
      neighbourhood = neighbourhood,
      population = population
    ),
    PROPHET = prophet(observation ~ season("year")),
    NNETAR = NNETAR(observation),
    CHRONOS = FOUNDATION(log1p(observation), "chronos"),
    TIMESFM = FOUNDATION(log1p(observation), "timesfm")
  )
)

cache_dir <- file.path("data-raw", "flusight-cache")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
data.table::setDTthreads(1L)

fcast_round <- function(ref_date) {
  ref_date <- as.Date(ref_date)
  round_id <- format(ref_date)
  cv_path <- file.path(cache_dir, paste0("cv-", round_id, ".rds"))
  forecast_path <- file.path(
    cache_dir,
    paste0("forecast-top3-", round_id, ".rds")
  )

  message("Round ", round_id)

  if (file.exists(forecast_path)) {
    message("  using cached top-three forecast")
    return(readRDS(forecast_path))
  }

  round_data <- revision_history |>
    filter(as_of <= ref_date - 6L) |>
    check_data()

  last_observed_date <- round_data$window[["to"]]
  last_target_date <- ref_date + 3L * 7L
  stopifnot(last_observed_date < ref_date)

  forecast_steps <- as.integer(
    last_target_date - last_observed_date
  ) %/% 7L

  aligned_weeks <- seq.Date(
    from = ref_date,
    by = "-52 weeks",
    length.out = length(cv_seasons) + 1L
  )[-1L]

  cv_origins <- sort(c(
    aligned_weeks,
    aligned_weeks + 7L,
    aligned_weeks + 14L
  ))

  cv <- if (file.exists(cv_path)) {
    message("  using cached cross-validation")
    readRDS(cv_path)
  } else {
    value <- get_cv(
      round_data,
      h = 4,
      origins = cv_origins,
      models = my_models
    )
    saveRDS(value, cv_path, compress = "gzip")
    value
  }

  value <- get_fcast(
    cv,
    h = forecast_steps,
    top_n = 3,
    ensemble = "linear_pool"
  )$hub$model_out_tbl |>
    transmute(
      model_id = if_else(model_id == "ENSEMBLE", "insight.cast", model_id),
      reference_date = ref_date,
      target,
      horizon = as.integer(target_end_date - ref_date) %/% 7L,
      location = locations$location[match(location, locations$abbreviation)],
      target_end_date,
      output_type,
      output_type_id,
      value = round(value)
    ) |>
    filter(horizon %in% 0:3)

  saveRDS(value, forecast_path, compress = "gzip")
  value
}

rounds <- lapply(reference_dates, function(ref_date) {
  tryCatch(
    fcast_round(ref_date),
    error = function(e) {
      warning("Round ", ref_date, " failed: ", conditionMessage(e))
      NULL
    }
  )
})

failed <- reference_dates[vapply(rounds, is.null, logical(1L))]
if (length(failed)) {
  stop("Failed rounds: ", paste(failed, collapse = ", "))
}

flusight_forecasts <- bind_rows(rounds)

expected_insightcast_rows <- length(reference_dates) * length(states) * 4L * 5L
stopifnot(sum(flusight_forecasts$model_id == "insight.cast") == expected_insightcast_rows)

if (shard_total == 1L) {
  write.csv(
    flusight_forecasts,
    file.path("data-raw", "insight.cast.csv"),
    row.names = FALSE
  )
  message("Saved ", nrow(flusight_forecasts), " rows to data-raw/insight.cast.csv")
  message("Packaging forecasts and recomputing FluSight scores")
  sys.source(
    file.path("data-raw", "FluSight.R"),
    envir = new.env(parent = globalenv())
  )
} else {
  message(
    "Shard ", shard_index, "/", shard_total, " completed ",
    length(reference_dates), " rounds"
  )
}
