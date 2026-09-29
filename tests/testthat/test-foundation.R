# Building a FOUNDATION() definition never forecasts, so those tests always run.
# The live-forecast test below downloads the Python stack and model weights, so
# it is opt-in: set INCAST_TEST_FOUNDATION=1 to run it.

test_that("FOUNDATION() builds a fable model definition without invoking Python", {
  skip_if_not_installed("reticulate")
  mdl <- FOUNDATION(observation, backend = "chronos")
  expect_s3_class(mdl, "mdl_defn")
  expect_s3_class(FOUNDATION(observation, backend = "moirai"), "mdl_defn")
})

test_that("FOUNDATION() defaults model_id per backend and validates arguments", {
  skip_if_not_installed("reticulate")
  expect_error(FOUNDATION(observation, backend = "nope"))
  expect_error(FOUNDATION(observation, n_samples = 1), "integer >= 2")
  expect_error(FOUNDATION(observation, n_samples = 2.5), "integer >= 2")
  expect_error(FOUNDATION(observation, device = "tpu"))
  # NULL model_id resolves to the backend default.
  expect_identical(foundation_backend("timesfm")$default_model, "google/timesfm-2.5-200m-pytorch")
  expect_identical(foundation_backend("moirai")$default_model, "Salesforce/moirai-1.1-R-small")
})

test_that("FOUNDATION() plumbs draws through to a hub forecast (mocked)", {
  skip_if_not_installed("reticulate")
  # Replace the Python call with a deterministic sample so the rest of the path
  # (train -> forecast -> dist_sample -> back-transform -> hub) is exercised
  # offline, without any Python backend installed.
  testthat::local_mocked_bindings(
    foundation_sample_paths = function(backend, context, h, model_id, device, n_samples) {
      probs <- (seq_len(n_samples) - 0.5) / n_samples
      matrix(
        rep(stats::qnorm(probs, mean = log(100), sd = 0.1), each = h),
        nrow = h,
        ncol = n_samples
      )
    },
    .package = "insight.cast"
  )

  df <- check_data(data.frame(
    target_end_date = seq(as.Date("2020-01-01"), by = "week", length.out = 60),
    observation = rep(100, 60),
    target = "wk inc covid hosp",
    location = "NY"
  ))
  fcast <- get_fcast(
    df,
    models = list(
      CHRONOS = FOUNDATION(log(observation), backend = "chronos", model_id = "amazon/chronos-t5-tiny")
    ),
    h = 2
  )
  expect_s3_class(fcast, "insight.cast_fcast")
  expect_true("CHRONOS" %in% fcast$hub$model_out_tbl$model_id)
  expect_true(all(is.finite(fcast$hub$model_out_tbl$value)))

  # The median forecast should be back-transformed from log scale to ~100
  # (i.e. exp(log(100))), confirming fable applied the inverse transform to the
  # sample distribution rather than leaving it on the log scale (~4.6).
  med <- subset(
    fcast$hub$model_out_tbl,
    model_id == "CHRONOS" & output_type_id == "0.5"
  )$value
  expect_true(all(med > 50 & med < 200))
})

test_that("FOUNDATION() forecasts through the fable interface (live chronos)", {
  skip_if_not(nzchar(Sys.getenv("INCAST_TEST_FOUNDATION")), "set INCAST_TEST_FOUNDATION=1 to run")
  df <- check_data(data.frame(
    target_end_date = seq(as.Date("2020-01-01"), by = "week", length.out = 60),
    observation = 50 + 10 * sin(2 * pi * seq_len(60) / 8),
    target = "wk inc covid hosp",
    location = "NY"
  ))
  fcast <- get_fcast(
    df,
    models = list(
      CHRONOS = FOUNDATION(log(observation), backend = "chronos", model_id = "amazon/chronos-t5-tiny")
    ),
    h = 2
  )
  expect_s3_class(fcast, "insight.cast_fcast")
  expect_true("CHRONOS" %in% fcast$hub$model_out_tbl$model_id)
  expect_true(all(is.finite(fcast$hub$model_out_tbl$value)))
})
