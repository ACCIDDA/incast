# Python engine for FOUNDATION(). A backend is one entry in foundation_backends():
# `deps` (PyPI packages to provision), `load(model_id, device)` returning the
# Python pipeline, and `sample(pipeline, context, h, n_samples, model_id)`
# returning an h x n_samples matrix of draws. Session caching, the macOS OpenMP
# guard, torch threading, and quantile->sample inversion are shared below, so
# adding a model is one list entry.

# Session cache of loaded pipelines, keyed by "<backend>@<model_id>@<device>".
.incast_pipelines <- new.env(parent = emptyenv())


ensure_reticulate <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop(
      "Package 'reticulate' is required for FOUNDATION(). ",
      "Install it with install.packages(\"reticulate\").",
      call. = FALSE
    )
  }
}


# Expand an h x length(levels) matrix of forecast quantiles to h x n_samples
# draws by reading the quantile function at evenly spaced probabilities. Tails
# are clamped at the outermost level (rule = 2), so the extreme intervals of the
# quantile-only backends (Chronos-Bolt, TimesFM) are approximate.
quantiles_to_paths <- function(qmat, levels, n_samples) {
  probs <- (seq_len(n_samples) - 0.5) / n_samples
  t(apply(qmat, 1L, function(v) {
    stats::approx(levels, v, xout = probs, rule = 2)$y
  }))
}


# Backend registry. The TimesFM/Sundial Python call shapes follow each library's
# documented usage; verify against the installed version on first run.
foundation_backends <- function() {
  list(
    chronos = list(
      # Classic Chronos 1.x: same t5/bolt weights as 2.x but compatible with
      # transformers < 4.48, so it coexists with the sundial backend.
      deps = c("chronos-forecasting>=1.5,<2", "torch"),
      default_model = "amazon/chronos-t5-small",
      load = function(model_id, device) {
        chronos <- reticulate::import("chronos", delay_load = FALSE)
        chronos$BaseChronosPipeline$from_pretrained(
          model_id,
          device_map = device
        )
      },
      sample = function(pipeline, context, h, n_samples, model_id) {
        torch <- reticulate::import("torch", delay_load = FALSE)
        ctx <- torch$tensor(context)
        if (grepl("bolt", model_id, ignore.case = TRUE)) {
          # Chronos-Bolt predicts only nine decile levels; invert them to draws.
          levels <- seq(0.1, 0.9, by = 0.1)
          out <- pipeline$predict_quantiles(
            context = ctx,
            prediction_length = h,
            quantile_levels = as.list(levels)
          )
          q <- out[[1]]$cpu()$float()$numpy() # shape [1, h, 9]
          quantiles_to_paths(matrix(q[1, , ], nrow = h), levels, n_samples)
        } else {
          # Original Chronos: autoregressive sample paths, shape [1, n_samples, h].
          out <- pipeline$predict(
            context = ctx,
            prediction_length = h,
            num_samples = n_samples
          )
          a <- out$cpu()$float()$numpy()
          t(matrix(a[1, , ], nrow = n_samples, ncol = h))
        }
      }
    ),
    timesfm = list(
      deps = "timesfm[torch]",
      default_model = "google/timesfm-2.5-200m-pytorch",
      load = function(model_id, device) {
        timesfm <- reticulate::import("timesfm", delay_load = FALSE)
        # TimesFM 2.5: load weights, then compile a decode function with generous
        # context/horizon bounds (rounded up to the patch size internally). The
        # library selects the device; torch_compile off skips the slow inductor
        # pass for one-series-at-a-time forecasting.
        model <- timesfm$TimesFM_2p5_200M_torch$from_pretrained(
          model_id,
          torch_compile = FALSE
        )
        model$compile(timesfm$ForecastConfig(
          max_context = 2048L,
          max_horizon = 256L,
          normalize_inputs = TRUE,
          fix_quantile_crossing = TRUE
        ))
        model
      },
      sample = function(pipeline, context, h, n_samples, model_id) {
        # forecast() returns (point, quantiles); quantiles are [1, horizon, 10]
        # with column 1 the mean and columns 2:10 the 0.1..0.9 deciles.
        out <- pipeline$forecast(horizon = h, inputs = list(context))
        levels <- seq(0.1, 0.9, by = 0.1)
        qmat <- matrix(
          out[[2]][1, seq_len(h), 2:10],
          nrow = h,
          ncol = length(levels)
        )
        quantiles_to_paths(qmat, levels, n_samples)
      }
    ),
    sundial = list(
      # Sundial's remote code needs an older transformers: it reads
      # DynamicCache.seen_tokens (removed in 4.44) and its attention path breaks
      # under the 4.41 mask/cache refactor, so 4.40.x is the proven window
      # (compatible with the chronos 1.x pin above).
      deps = c("transformers==4.40.1", "torch"),
      default_model = "thuml/sundial-base-128m",
      load = function(model_id, device) {
        transformers <- reticulate::import("transformers", delay_load = FALSE)
        model <- transformers$AutoModelForCausalLM$from_pretrained(
          model_id,
          trust_remote_code = TRUE
        )
        list(model = model$to(device)$eval(), device = device)
      },
      sample = function(pipeline, context, h, n_samples, model_id) {
        torch <- reticulate::import("torch", delay_load = FALSE)
        n <- length(context)
        seqs <- torch$tensor(context)$float()$reshape(1L, n)$to(pipeline$device)
        # Sundial is generative: num_samples raw draws, shape [1, n_samples, h].
        out <- pipeline$model$generate(
          seqs,
          max_new_tokens = h,
          num_samples = n_samples
        )
        a <- out$cpu()$float()$numpy()
        t(matrix(a[1, , ], nrow = n_samples, ncol = h))
      }
    ),
    moirai = list(
      # Salesforce Moirai: a masked-encoder universal forecaster on its own
      # Lightning/GluonTS stack - it never imports `transformers`, so it coexists
      # with sundial's 4.40.1 pin and chronos's <4.48. uni2ts pins torch<2.5.
      # Calling forward() with an explicit patch_size forecasts straight from a
      # value vector (dates/frequency are only needed on the GluonTS predictor).
      deps = c("uni2ts", "torch"),
      default_model = "Salesforce/moirai-1.1-R-small",
      load = function(model_id, device) {
        moirai <- reticulate::import("uni2ts.model.moirai", delay_load = FALSE)
        list(
          module = moirai$MoiraiModule$from_pretrained(model_id),
          device = device
        )
      },
      sample = function(pipeline, context, h, n_samples, model_id) {
        torch <- reticulate::import("torch", delay_load = FALSE)
        moirai <- reticulate::import("uni2ts.model.moirai", delay_load = FALSE)
        n <- length(context)
        # patch_size fixed at 16 so short histories still form at least one patch.
        hp <- list(
          prediction_length = h,
          context_length = n,
          patch_size = 16L,
          num_samples = n_samples,
          target_dim = 1L,
          feat_dynamic_real_dim = 0L,
          past_feat_dynamic_real_dim = 0L
        )
        # Size a forecaster to this context/horizon around the cached weights
        # (cheap). MoiraiForecast stashes its config via Lightning's
        # save_hyperparameters(), which reads the constructor's call frame - that
        # comes up empty when __init__ runs through reticulate, so forward() would
        # raise "AttributeDict has no attribute patch_size". Re-set hparams here.
        model <- do.call(
          moirai$MoiraiForecast,
          c(list(module = pipeline$module), hp)
        )
        model$hparams$update(reticulate::r_to_py(hp))
        model <- model$to(pipeline$device)$eval()
        past_target <- torch$tensor(context)$float()$reshape(1L, n, 1L)$to(
          pipeline$device
        )
        past_observed <- torch$ones_like(past_target)$bool()
        past_is_pad <- torch$zeros(1L, n)$bool()$to(pipeline$device)
        # Masked-encoder forward -> sample paths, shape [1, n_samples, h]; reshape
        # to [n_samples, h] (univariate target dim collapses) then transpose.
        out <- model(
          past_target,
          past_observed,
          past_is_pad,
          num_samples = n_samples
        )
        a <- out$reshape(n_samples, h)$cpu()$float()$numpy()
        t(a)
      }
    )
  )
}


foundation_backend <- function(backend) foundation_backends()[[backend]]


# Load (and cache) a backend's Python pipeline for the session, so cross-
# validation (which refits at every origin) initialises each model only once.
load_foundation_pipeline <- function(backend, model_id, device) {
  key <- paste(backend, model_id, device, sep = "@")
  if (!is.null(.incast_pipelines[[key]])) {
    return(.incast_pipelines[[key]])
  }

  ensure_reticulate()
  spec <- foundation_backend(backend)
  reticulate::py_require(spec$deps)

  # R's BLAS and torch each bundle an OpenMP runtime; loading both segfaults on
  # macOS unless the duplicate is allowed. Set before torch is imported.
  if (!nzchar(Sys.getenv("KMP_DUPLICATE_LIB_OK"))) {
    Sys.setenv(KMP_DUPLICATE_LIB_OK = "TRUE")
  }

  # Force torch single-threaded: with R's OpenMP pool already warm from fable
  # fitting, torch's multi-threaded forward pass races it and segfaults on macOS.
  torch <- reticulate::import("torch", delay_load = FALSE)
  torch$set_num_threads(1L)

  pipeline <- spec$load(model_id, device)
  .incast_pipelines[[key]] <- pipeline
  pipeline
}


# Zero-shot forecast: an h x n_samples matrix of draws from `backend`.
foundation_sample_paths <- function(
  backend,
  context,
  h,
  model_id,
  device,
  n_samples
) {
  spec <- foundation_backend(backend)
  pipeline <- load_foundation_pipeline(backend, model_id, device)
  paths <- spec$sample(
    pipeline,
    as.numeric(context),
    as.integer(h),
    as.integer(n_samples),
    model_id
  )
  matrix(as.numeric(paths), nrow = h, ncol = n_samples)
}
