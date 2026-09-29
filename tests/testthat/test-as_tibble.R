test_that("as_tibble.insightcast_data returns one latest-revision row per series and date", {
  raw <- make_weekly_df(locations = c("NY", "CA"), n = 10, revisions = TRUE)
  x <- check_data(raw)

  out <- as_tibble(x)

  expect_s3_class(out, "tbl_df")
  expect_false("as_of" %in% names(out))
  expect_equal(nrow(out), nrow(unique(out[c("location", "target_end_date")])))

  # The kept value is the most recent report for each series and date.
  latest <- dplyr::slice_max(raw, as_of, by = c(location, target_end_date))
  joined <- dplyr::inner_join(out, latest, by = c("location", "target_end_date"))
  expect_equal(nrow(joined), nrow(out))
  expect_equal(joined$observation.x, joined$observation.y)
})

test_that("as_tibble.insightcast_ncast returns the nowcast summary", {
  x <- check_data(
    make_weekly_df(locations = c("NY", "CA"), n = 8, revisions = TRUE)
  )
  ncast <- get_ncast(x, draws = 100)

  out <- as_tibble(ncast)

  expect_s3_class(out, "tbl_df")
  expect_contains(
    names(out),
    c("location", "reference_date", "lower", "q25", "median", "q75", "upper", "observed")
  )
  expect_setequal(unique(out$location), c("NY", "CA"))
})

test_that("as_tibble.insightcast_fcast keeps every model's quantile bands", {
  x <- check_data(make_weekly_df(n = 12))
  fcast <- get_fcast(x, models = list(NAIVE = fable::NAIVE(observation)), h = 2)

  out <- as_tibble(fcast)

  expect_s3_class(out, "tbl_df")
  expect_setequal(unique(out$model_id), c("NAIVE", "ENSEMBLE"))
  expect_contains(names(out), c("model_id", "lower", "q25", "median", "q75", "upper"))
  expect_false(any(c("output_type_id", "value") %in% names(out)))
  expect_equal(nrow(out), 4L) # 2 models x 1 series x h = 2
})
