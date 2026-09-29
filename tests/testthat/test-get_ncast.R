test_that("week_floor floors dates to the ISO week start", {
  x <- as.Date(c("2025-01-15", "2025-01-18"))

  expect_equal(week_floor(x), as.Date(c("2025-01-13", "2025-01-13")))
})

test_that("build_reporting_triangle differences revisions into new reports", {
  df <- data.frame(
    target_end_date = as.Date("2025-01-08"),
    as_of = as.Date(c("2025-01-08", "2025-01-15", "2025-01-22")),
    observation = c(100, 120, 115) # one downward revision
  )

  tri <- build_reporting_triangle(df, estimation_window = 100)

  expect_named(tri, c("reference_date", "report_date", "count"))
  expect_equal(tri$count, c(100, 20, -5)) # negatives kept for baselinenowcast
})

test_that("get_ncast corrects every series and returns one tidy summary", {
  x <- check_data(
    make_weekly_df(locations = c("NY", "CA"), n = 8, revisions = TRUE)
  )

  result <- get_ncast(x, draws = 100)

  expect_s3_class(result, "insight.cast_ncast")
  expect_equal(result$key, "location")
  expect_setequal(unique(result$data$location), c("NY", "CA"))
  expect_true(all(c("ncast_lower", "ncast_upper") %in% names(result$data)))

  s <- result$meta$ncast_summary
  expect_setequal(unique(s$location), c("NY", "CA"))
  expect_contains(
    names(s),
    c("reference_date", "median", "lower", "upper", "q25", "q75", "observed")
  )
  expect_equal(result$meta$max_delay, 2)
})

test_that("get_ncast handles composite keys", {
  df <- make_weekly_df(
    locations = c("NY", "CA"),
    age_groups = c("young", "old"),
    n = 8,
    revisions = TRUE
  )
  x <- check_data(df, key = c("location", "age_group"))

  result <- get_ncast(x, draws = 50)

  expect_equal(result$key, c("location", "age_group"))
  expect_equal(nrow(unique(result$data[result$key])), 4L)
  expect_true(
    all(c("location", "age_group") %in% names(result$meta$ncast_summary))
  )
})

test_that("only the last max_delay weeks are corrected", {
  x <- check_data(make_weekly_df(n = 8, revisions = TRUE))

  result <- get_ncast(x, max_delay = 2, draws = 100)

  corrected <- result$data[!is.na(result$data$ncast_lower), ]
  cutoff <- max(result$data$target_end_date) - 2 * 7

  expect_gt(nrow(corrected), 0)
  expect_true(all(corrected$target_end_date > cutoff))
})

test_that("downward revisions are redistributed, not dropped", {
  df <- make_weekly_df(n = 8, revisions = TRUE)
  late <- which(df$as_of - df$target_end_date == 14)
  df$observation[late[1]] <- 0 # a report far below the previous one

  result <- get_ncast(check_data(df), draws = 50)

  expect_s3_class(result, "insight.cast_ncast")
})

test_that("get_ncast requires revision history", {
  x <- check_data(make_weekly_df(n = 8))

  expect_error(get_ncast(x), "revision history")
})

test_that("get_ncast validates max_delay", {
  x <- check_data(make_weekly_df(n = 8, revisions = TRUE))

  expect_error(get_ncast(x, max_delay = 0), "max_delay")
  expect_error(get_ncast(x, max_delay = 1.5), "positive integer")
  expect_error(get_ncast(x, draws = 1), "integer >= 2")
  expect_error(get_ncast(x, prop_delay = 1), "between 0 and 1")
  expect_error(get_ncast(x, scale_factor = Inf), "positive number")
})

test_that("get_ncast rejects non-weekly data", {
  days <- seq(as.Date("2025-01-01"), by = "day", length.out = 20)
  daily <- data.frame(
    target_end_date = rep(days, each = 2),
    as_of = rep(days, each = 2) + c(0L, 3L),
    observation = rep(c(40, 50), times = 20),
    location = "NY",
    target = "daily cases"
  )
  x <- check_data(daily)

  expect_equal(x$interval, 1L)
  expect_error(get_ncast(x), "weekly data only")
})

test_that("autoplot.insight.cast_ncast returns a faceted ggplot", {
  x <- check_data(
    make_weekly_df(locations = c("NY", "CA"), n = 8, revisions = TRUE)
  )

  p <- autoplot(get_ncast(x, draws = 50))

  expect_s3_class(p, "ggplot")
})
