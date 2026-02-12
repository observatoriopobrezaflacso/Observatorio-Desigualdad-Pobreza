# =============================================================================
# FULL CSV DATA SPECIFICATION (matches YAML detail level)
# =============================================================================
# This script exports data specifications to CSV format with ALL the detail
# needed to generate accurate synthetic data (same as YAML).
#
# Output files:
#   1. *_variables.csv    - Main variable info (one row per variable)
#   2. *_categories.csv   - Category probabilities (one row per category)
#   3. *_quantiles.csv    - Quantiles for continuous variables
#   4. *_labels.csv       - Value labels for labelled variables
# =============================================================================

# Load required packages
lapply(c("haven", "dplyr", "tibble"), function(p) {
  if (!require(p, character.only = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
})

# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x) || is.na(x)) y else x

# Source main functions
script_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) dirname(normalizePath(sub("^--file=", "", file_arg)))
  else getwd()
}, error = function(e) getwd())

source(file.path(script_dir, "fake_data_creation2.R"))

# -----------------------------------------------------------------------------
# EXPORT DATA_SPEC TO MULTIPLE CSV FILES
# -----------------------------------------------------------------------------

#' Export data_spec to comprehensive CSV files
#' @param data_spec data specification object
#' @param output_prefix prefix for output files (e.g., "mydata" -> "mydata_variables.csv")
save_spec_csv_full <- function(data_spec, output_prefix) {

  # -------------------------------------------------------------------------
  # 1. VARIABLES CSV - Main variable information
  # -------------------------------------------------------------------------
  vars_df <- do.call(rbind, lapply(names(data_spec$variables), function(var_name) {
    v <- data_spec$variables[[var_name]]
    data.frame(
      name = var_name,
      type = v$type %||% NA,
      dist_form = v$dist_form %||% NA,
      missing_prop = round(v$missing_prop %||% 0, 6),
      is_labelled = v$is_labelled %||% FALSE,
      is_char_labelled = v$is_char_labelled %||% FALSE,
      is_integer_like = v$is_integer_like %||% FALSE,
      n_unique = v$n_unique %||% NA,
      # Numeric stats
      mean = if (!is.null(v$mean)) round(v$mean, 6) else NA,
      sd = if (!is.null(v$sd)) round(v$sd, 6) else NA,
      min = if (!is.null(v$min)) round(v$min, 6) else NA,
      max = if (!is.null(v$max)) round(v$max, 6) else NA,
      skewness = if (!is.null(v$skewness)) round(v$skewness, 6) else NA,
      cv = if (!is.null(v$cv)) round(v$cv, 6) else NA,
      # Lognormal parameters
      log_mean = if (!is.null(v$log_mean)) round(v$log_mean, 6) else NA,
      log_sd = if (!is.null(v$log_sd)) round(v$log_sd, 6) else NA,
      log_shift = if (!is.null(v$log_shift)) round(v$log_shift, 6) else NA,
      # ID parameters
      id_min = v$id_min %||% NA,
      id_max = v$id_max %||% NA,
      id_length = v$id_length %||% NA,
      # String info
      str_length_min = if (!is.null(v$str_lengths)) v$str_lengths[1] else NA,
      str_length_max = if (!is.null(v$str_lengths)) v$str_lengths[2] else NA,
      # Metadata
      stata_label = v$stata_label %||% NA,
      stata_format = v$stata_format %||% NA,
      stringsAsFactors = FALSE
    )
  }))

  vars_file <- paste0(output_prefix, "_variables.csv")
  write.csv(vars_df, vars_file, row.names = FALSE, na = "")
  message("Saved: ", vars_file, " (", nrow(vars_df), " variables)")

  # -------------------------------------------------------------------------
  # 2. CATEGORIES CSV - Category probabilities
  # -------------------------------------------------------------------------
  cats_list <- list()
  for (var_name in names(data_spec$variables)) {
    v <- data_spec$variables[[var_name]]
    if (!is.null(v$categories) && !is.null(v$category_probs)) {
      for (i in seq_along(v$categories)) {
        cats_list[[length(cats_list) + 1]] <- data.frame(
          variable = var_name,
          category = as.character(v$categories[i]),
          probability = round(v$category_probs[i], 6),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(cats_list) > 0) {
    cats_df <- do.call(rbind, cats_list)
    cats_file <- paste0(output_prefix, "_categories.csv")
    write.csv(cats_df, cats_file, row.names = FALSE)
    message("Saved: ", cats_file, " (", nrow(cats_df), " category entries)")
  }

  # -------------------------------------------------------------------------
  # 3. QUANTILES CSV - For continuous variables
  # -------------------------------------------------------------------------
  quant_list <- list()
  quant_names <- c("1%", "5%", "25%", "50%", "75%", "95%", "99%")

  for (var_name in names(data_spec$variables)) {
    v <- data_spec$variables[[var_name]]
    if (!is.null(v$quantiles)) {
      for (i in seq_along(v$quantiles)) {
        q_name <- names(v$quantiles)[i] %||% quant_names[i]
        quant_list[[length(quant_list) + 1]] <- data.frame(
          variable = var_name,
          quantile = q_name,
          value = round(v$quantiles[i], 6),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(quant_list) > 0) {
    quant_df <- do.call(rbind, quant_list)
    quant_file <- paste0(output_prefix, "_quantiles.csv")
    write.csv(quant_df, quant_file, row.names = FALSE)
    message("Saved: ", quant_file, " (", nrow(quant_df), " quantile entries)")
  }

  # -------------------------------------------------------------------------
  # 4. LABELS CSV - Value labels
  # -------------------------------------------------------------------------
  labels_list <- list()
  for (var_name in names(data_spec$variables)) {
    v <- data_spec$variables[[var_name]]
    if (!is.null(v$value_labels)) {
      for (i in seq_along(v$value_labels)) {
        labels_list[[length(labels_list) + 1]] <- data.frame(
          variable = var_name,
          label = names(v$value_labels)[i],
          value = as.character(v$value_labels[i]),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(labels_list) > 0) {
    labels_df <- do.call(rbind, labels_list)
    labels_file <- paste0(output_prefix, "_labels.csv")
    write.csv(labels_df, labels_file, row.names = FALSE)
    message("Saved: ", labels_file, " (", nrow(labels_df), " label entries)")
  }

  # -------------------------------------------------------------------------
  # 5. METADATA CSV - Dataset info
  # -------------------------------------------------------------------------
  meta_df <- data.frame(
    key = c("n_original", "n_vars", "extraction_date"),
    value = c(
      as.character(data_spec$n_original),
      as.character(data_spec$n_vars),
      as.character(data_spec$extraction_date %||% Sys.time())
    ),
    stringsAsFactors = FALSE
  )
  meta_file <- paste0(output_prefix, "_metadata.csv")
  write.csv(meta_df, meta_file, row.names = FALSE)
  message("Saved: ", meta_file)

  message("\nAll CSV files saved with prefix: ", output_prefix)
}

# -----------------------------------------------------------------------------
# LOAD DATA_SPEC FROM CSV FILES
# -----------------------------------------------------------------------------

#' Load data_spec from comprehensive CSV files
#' @param input_prefix prefix used when saving (e.g., "mydata")
#' @return data_spec object
load_spec_csv_full <- function(input_prefix) {

  # Load metadata
  meta_file <- paste0(input_prefix, "_metadata.csv")
  if (!file.exists(meta_file)) stop("Metadata file not found: ", meta_file)
  meta_df <- read.csv(meta_file, stringsAsFactors = FALSE)
  meta <- setNames(meta_df$value, meta_df$key)

  # Load variables
  vars_file <- paste0(input_prefix, "_variables.csv")
  if (!file.exists(vars_file)) stop("Variables file not found: ", vars_file)
  vars_df <- read.csv(vars_file, stringsAsFactors = FALSE, na.strings = "")

  # Load categories (optional)
  cats_file <- paste0(input_prefix, "_categories.csv")
  cats_df <- if (file.exists(cats_file)) {
    read.csv(cats_file, stringsAsFactors = FALSE)
  } else NULL

  # Load quantiles (optional)
  quant_file <- paste0(input_prefix, "_quantiles.csv")
  quant_df <- if (file.exists(quant_file)) {
    read.csv(quant_file, stringsAsFactors = FALSE)
  } else NULL

  # Load labels (optional)
  labels_file <- paste0(input_prefix, "_labels.csv")
  labels_df <- if (file.exists(labels_file)) {
    read.csv(labels_file, stringsAsFactors = FALSE)
  } else NULL

  # Build variable specifications
  variables <- list()

  for (i in seq_len(nrow(vars_df))) {
    row <- vars_df[i, ]
    var_name <- row$name

    spec <- list(
      name = var_name,
      type = row$type,
      dist_form = row$dist_form,
      missing_prop = row$missing_prop %||% 0,
      is_labelled = isTRUE(row$is_labelled),
      is_char_labelled = isTRUE(row$is_char_labelled),
      is_integer_like = isTRUE(row$is_integer_like),
      n_unique = if (!is.na(row$n_unique)) row$n_unique else NULL
    )

    # Numeric stats
    if (!is.na(row$mean)) spec$mean <- row$mean
    if (!is.na(row$sd)) spec$sd <- row$sd
    if (!is.na(row$min)) spec$min <- row$min
    if (!is.na(row$max)) spec$max <- row$max
    if (!is.na(row$skewness)) spec$skewness <- row$skewness
    if (!is.na(row$cv)) spec$cv <- row$cv

    # Lognormal params
    if (!is.na(row$log_mean)) spec$log_mean <- row$log_mean
    if (!is.na(row$log_sd)) spec$log_sd <- row$log_sd
    if (!is.na(row$log_shift)) spec$log_shift <- row$log_shift

    # ID params
    if (!is.na(row$id_min)) spec$id_min <- row$id_min
    if (!is.na(row$id_max)) spec$id_max <- row$id_max
    if (!is.na(row$id_length)) spec$id_length <- row$id_length

    # String lengths
    if (!is.na(row$str_length_min) && !is.na(row$str_length_max)) {
      spec$str_lengths <- c(row$str_length_min, row$str_length_max)
    }

    # Metadata
    if (!is.na(row$stata_label)) spec$stata_label <- row$stata_label
    if (!is.na(row$stata_format)) spec$stata_format <- row$stata_format

    # Add categories
    if (!is.null(cats_df)) {
      var_cats <- cats_df[cats_df$variable == var_name, ]
      if (nrow(var_cats) > 0) {
        # Determine if categories are numeric or character
        if (row$type == "character" || row$dist_form == "categorical_string") {
          spec$categories <- var_cats$category
        } else {
          spec$categories <- as.numeric(var_cats$category)
        }
        spec$category_probs <- var_cats$probability
      }
    }

    # Add quantiles
    if (!is.null(quant_df)) {
      var_quants <- quant_df[quant_df$variable == var_name, ]
      if (nrow(var_quants) > 0) {
        spec$quantiles <- setNames(var_quants$value, var_quants$quantile)
      }
    }

    # Add value labels
    if (!is.null(labels_df)) {
      var_labels <- labels_df[labels_df$variable == var_name, ]
      if (nrow(var_labels) > 0) {
        spec$value_labels <- setNames(
          as.numeric(var_labels$value),
          var_labels$label
        )
      }
    }

    variables[[var_name]] <- spec
  }

  # Build data_spec
  data_spec <- list(
    variables = variables,
    n_original = as.integer(meta["n_original"]),
    n_vars = as.integer(meta["n_vars"]),
    var_names = names(variables),
    extraction_date = as.POSIXct(meta["extraction_date"])
  )

  class(data_spec) <- c("data_spec", "list")

  message("Loaded specification: ", data_spec$n_vars, " variables")
  return(data_spec)
}

# =============================================================================
# RUN: Extract and save full CSV specification
# =============================================================================

# Input data file
data_file <- file.path(script_dir, "../../Bases/empleo2024.dta")

# Output prefix
output_prefix <- file.path(script_dir, "../../Bases/empleo2024_spec_full")

cat("================================================================================\n")
cat("           FULL CSV SPECIFICATION EXTRACTION\n")
cat("================================================================================\n\n")

if (file.exists(data_file)) {

  # Extract specification
  cat("Extracting specification from:", basename(data_file), "\n\n")
  data_spec <- extract_data_spec(data_file)

  # Save to CSV files
  cat("\nSaving CSV files...\n")
  save_spec_csv_full(data_spec, output_prefix)

  # Test: Load it back and generate data
  cat("\n--------------------------------------------------------------------------------\n")
  cat("Testing: Load from CSV and generate synthetic data\n")
  cat("--------------------------------------------------------------------------------\n\n")

  loaded_spec <- load_spec_csv_full(output_prefix)

  fake_data <- fake_data_creation(loaded_spec, n = 100, seed = 42, verbose = FALSE)
  cat("\nGenerated ", nrow(fake_data), " rows x ", ncol(fake_data), " cols\n")

  # Quick check
  cat("\nDistribution check (area):\n")
  print(round(prop.table(table(as.numeric(fake_data$area))) * 100, 1))

  cat("\n================================================================================\n")
  cat("Done! CSV files saved with prefix:", output_prefix, "\n")
  cat("================================================================================\n")

} else {
  cat("Data file not found:", data_file, "\n")
  cat("Please update the path and run again.\n")
}
