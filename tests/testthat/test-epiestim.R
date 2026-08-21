# EPIESTIM depends on the Suggests-only EpiEstim + projections packages.
skip_if_no_epiestim <- function() {
  skip_if_not_installed("EpiEstim", "2.4")
  skip_if_not_installed("projections")
}

# A regular weekly single-series tsibble with steady growth (Rt > 1).
weekly_ts <- function(n = 24, start = as.Date("2024-01-06"), r = 0.08) {
  tsibble::tsibble(
    week = start + 7L * (seq_len(n) - 1L),
    observation = round(50 * exp(r * (seq_len(n) - 1L))),
    index = week
  )
}

test_that("EPIESTIM validates model settings", {
  expect_error(EPIESTIM(observation, mean_si = 0, std_si = 4), "mean_si")
  expect_error(EPIESTIM(observation, mean_si = 5, std_si = Inf), "std_si")
  expect_error(
    EPIESTIM(observation, mean_si = 5, std_si = 4, rt_window = 1.5),
    "positive integer"
  )
  expect_error(
    EPIESTIM(observation, mean_si = 5, std_si = 4, R_fix_within = NA),
    "TRUE.*FALSE"
  )
})

test_that("EPIESTIM fits and forecasts h future periods", {
  skip_if_no_epiestim()
  ts <- weekly_ts()

  fc <- forecast(
    fabletools::model(ts, EPIESTIM(observation, mean_si = 5, std_si = 4)),
    h = 3
  )

  expect_s3_class(fc, "fbl_ts")
  expect_equal(nrow(fc), 3L)
  # Horizon 1 is the period after the training data, not a re-forecast of it.
  expect_equal(as.Date(fc$week), max(ts$week) + 7L * (1:3))
  expect_true(all(is.finite(fc$.mean)))
})

test_that("the most recent observation informs the forecast (last period kept)", {
  skip_if_no_epiestim()
  ts <- weekly_ts()
  spiked <- ts
  spiked$observation[nrow(spiked)] <- spiked$observation[nrow(spiked)] * 10L

  set.seed(1)
  base <- forecast(
    fabletools::model(ts, EPIESTIM(observation, mean_si = 5, std_si = 4)),
    h = 1
  )
  set.seed(1)
  bumped <- forecast(
    fabletools::model(spiked, EPIESTIM(observation, mean_si = 5, std_si = 4)),
    h = 1
  )

  # If the last period were dropped before estimation, the spike could not move
  # the one-step forecast -- this guards against that off-by-one truncation.
  expect_gt(bumped$.mean[1], base$.mean[1])
})

test_that("model_sum, tidy and glance summarise the current Rt", {
  skip_if_no_epiestim()
  mdl <- fabletools::model(weekly_ts(), EPIESTIM(observation, mean_si = 5, std_si = 4))

  expect_output(print(mdl), "EpiEstim")

  td <- fabletools::tidy(mdl)
  expect_setequal(td$term, c("Rt_median", "Rt_lower_95", "Rt_upper_95"))
  expect_true(all(is.finite(td$estimate)))

  gl <- fabletools::glance(mdl)
  expect_true(all(is.finite(c(gl$Rt_median, gl$Rt_lower_95, gl$Rt_upper_95))))
})
