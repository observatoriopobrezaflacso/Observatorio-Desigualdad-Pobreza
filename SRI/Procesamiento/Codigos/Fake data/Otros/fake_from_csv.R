# =============================================================================
# GENERATE SYNTHETIC DATA FROM CSV SPECIFICATION
# =============================================================================
# This script reads a CSV summary of data specifications and generates
# synthetic data. It's a lighter alternative to the full YAML specification.
#
# Note: CSV has less detail than YAML (no category probabilities, no quantiles),
# so this uses uniform distributions for categories and normal/uniform for
# continuous variables.
# =============================================================================

# Load required packages
lapply(c("haven", "dplyr", "tibble"), function(p) {
  if (!require(p, character.only = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
})

# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x) || is.na(x)) y else x

# -----------------------------------------------------------------------------
# READ CSV AND CONVERT TO DATA_SPEC
# -----------------------------------------------------------------------------

#' Read CSV specification and convert to data_spec format
#' @param csv_file path to CSV specification file
#' @param n_rows number of rows for the synthetic data (required since CSV doesn't store this)
#' @return data_spec object
read_csv_spec <- function(csv_file, n_rows = 1000) {

  # Read CSV
  csv_data <- read.csv(csv_file, stringsAsFactors = FALSE)

  message("Read specification for ", nrow(csv_data), " variables from CSV")

  # Convert each row to a variable specification
  variables <- lapply(seq_len(nrow(csv_data)), function(i) {
    row <- csv_data[i, ]

    spec <- list(
      name = row$name,
      type = row$type,
      dist_form = row$dist_form,
      missing_prop = (row$missing_pct %||% 0) / 100,
      is_labelled = isTRUE(row$is_labelled),
      is_char_labelled = (row$type == "character_labelled"),
      stata_label = if (!is.na(row$stata_label)) row$stata_label else NULL
    )

    # Add numeric parameters if available
    if (row$type == "numeric") {
      if (!is.na(row$mean)) spec$mean <- row$mean
      if (!is.na(row$sd)) spec$sd <- row$sd
      if (!is.na(row$min)) spec$min <- row$min
      if (!is.na(row$max)) spec$max <- row$max
      spec$is_integer_like <- (row$dist_form %in% c("categorical", "numeric_id"))
    }

    # Add category count for categorical variables
    if (!is.na(row$n_categories) && row$n_categories > 0) {
      spec$n_categories <- row$n_categories
    }

    # Add n_unique for ID variables
    if (!is.na(row$n_unique)) {
      spec$n_unique <- row$n_unique
    }

    return(spec)
  })

  names(variables) <- csv_data$name

  # Create data_spec object
  data_spec <- list(
    variables = variables,
    n_original = n_rows,
    n_vars = nrow(csv_data),
    var_names = csv_data$name,
    source = "csv"
  )

  class(data_spec) <- c("data_spec", "list")

  return(data_spec)
}

# -----------------------------------------------------------------------------
# GENERATE SYNTHETIC DATA FROM CSV SPEC
# -----------------------------------------------------------------------------

#' Generate a single variable from CSV-based spec
#' @param spec variable specification
#' @param n number of values to generate
generate_var_from_csv_spec <- function(spec, n) {

  # Calculate number of non-missing values
  n_missing <- round(n * (spec$missing_prop %||% 0))
  n_valid <- n - n_missing

  # Generate based on distribution form
  if (spec$dist_form == "categorical") {
    # Categorical: generate integers from 1 to n_categories (or min to max)
    if (!is.null(spec$min) && !is.null(spec$max)) {
      categories <- seq(spec$min, spec$max)
    } else if (!is.null(spec$n_categories)) {
      categories <- seq_len(spec$n_categories)
    } else {
      categories <- 1:5  # default
    }
    synthetic <- sample(categories, n_valid, replace = TRUE)

  } else if (spec$dist_form == "numeric_id") {
    # Numeric ID: generate unique-ish integers in range
    if (!is.null(spec$min) && !is.null(spec$max)) {
      synthetic <- sample(seq(spec$min, spec$max), n_valid, replace = TRUE)
    } else {
      synthetic <- sample(seq_len(n_valid * 10), n_valid, replace = TRUE)
    }

  } else if (spec$dist_form %in% c("normal", "lognormal", "heavy_tailed", "skewed_empirical")) {
    # Continuous: use normal distribution with provided mean/sd
    mean_val <- spec$mean %||% 0
    sd_val <- spec$sd %||% 1

    if (spec$dist_form == "lognormal" && mean_val > 0) {
      # Approximate lognormal
      synthetic <- abs(rnorm(n_valid, mean = mean_val, sd = sd_val))
    } else {
      synthetic <- rnorm(n_valid, mean = mean_val, sd = sd_val)
    }

    # Enforce bounds if available
    if (!is.null(spec$min)) synthetic <- pmax(synthetic, spec$min)
    if (!is.null(spec$max)) synthetic <- pmin(synthetic, spec$max)

    # Round if integer-like
    if (isTRUE(spec$is_integer_like)) {
      synthetic <- round(synthetic)
    }

  } else if (spec$dist_form == "categorical_string") {
    # String categories: generate placeholder strings
    n_cats <- spec$n_categories %||% 5
    categories <- paste0("cat_", seq_len(n_cats))
    synthetic <- sample(categories, n_valid, replace = TRUE)

  } else if (spec$dist_form == "high_cardinality_id") {
    # High cardinality string ID
    id_length <- 10
    synthetic <- replicate(n_valid, paste0(sample(c(0:9, letters), id_length, replace = TRUE), collapse = ""))

  } else {
    # Default: random values
    synthetic <- rnorm(n_valid)
  }

  # Add NAs
  if (n_missing > 0) {
    full_vector <- c(synthetic, rep(NA, n_missing))
    synthetic <- sample(full_vector)  # shuffle to distribute NAs
  }

  # Convert character types
  if (spec$type %in% c("character", "character_labelled")) {
    synthetic <- as.character(synthetic)
  }

  return(synthetic)
}

#' Generate synthetic data from CSV specification
#' @param csv_file path to CSV specification file
#' @param n number of rows to generate
#' @param seed random seed for reproducibility
#' @param verbose print progress messages
#' @return tibble with synthetic data
fake_data_from_csv <- function(csv_file, n = 1000, seed = 12345, verbose = TRUE) {

  set.seed(seed)

  # Read CSV spec
  data_spec <- read_csv_spec(csv_file, n_rows = n)

  if (verbose) {
    message("Generating ", n, " rows x ", data_spec$n_vars, " columns...")
    pb <- txtProgressBar(min = 0, max = data_spec$n_vars, style = 3)
  }

  # Generate each variable
  synthetic_list <- vector("list", data_spec$n_vars)
  names(synthetic_list) <- data_spec$var_names

  for (i in seq_along(data_spec$var_names)) {
    var_name <- data_spec$var_names[i]
    synthetic_list[[var_name]] <- generate_var_from_csv_spec(data_spec$variables[[var_name]], n)

    if (verbose) setTxtProgressBar(pb, i)
  }

  if (verbose) close(pb)

  # Combine into tibble
  synthetic_df <- as_tibble(synthetic_list)

  if (verbose) {
    message("Done! Generated ", nrow(synthetic_df), " rows x ", ncol(synthetic_df), " columns")
  }

  return(synthetic_df)
}

# -----------------------------------------------------------------------------
# SUMMARY FUNCTION
# -----------------------------------------------------------------------------

#' Print summary of CSV specification
#' @param csv_file path to CSV specification file
print_csv_spec_summary <- function(csv_file) {

  csv_data <- read.csv(csv_file, stringsAsFactors = FALSE)

  cat("\n")
  cat("================================================================================\n")
  cat("                    CSV SPECIFICATION SUMMARY\n")
  cat("================================================================================\n\n")

  cat("Variables:        ", nrow(csv_data), "\n\n")

  cat("VARIABLE TYPES:\n")
  type_table <- table(csv_data$type)
  for (t in names(type_table)) {
    cat("  ", sprintf("%-25s", t), ": ", type_table[t], "\n")
  }

  cat("\nDISTRIBUTION FORMS:\n")
  dist_table <- table(csv_data$dist_form)
  for (d in names(dist_table)) {
    cat("  ", sprintf("%-25s", d), ": ", dist_table[d], "\n")
  }

  cat("\nMISSING DATA:\n")
  high_missing <- csv_data[csv_data$missing_pct > 50, c("name", "missing_pct")]
  if (nrow(high_missing) > 0) {
    cat("  Variables with >50% missing:\n")
    for (i in seq_len(min(10, nrow(high_missing)))) {
      cat("    ", sprintf("%-30s", high_missing$name[i]), ": ",
          sprintf("%5.1f%%", high_missing$missing_pct[i]), "\n")
    }
    if (nrow(high_missing) > 10) {
      cat("    ... and ", nrow(high_missing) - 10, " more\n")
    }
  } else {
    cat("  No variables with >50% missing\n")
  }

  cat("\n================================================================================\n")
}

# =============================================================================
# RUN EXAMPLE (set run_example = TRUE to execute)
# =============================================================================

run_example <- TRUE

if (run_example) {

  # Get the directory where this script is located
  script_dir <- tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) {
    getwd()
  })

  # Base path (go up from Codigos/Fake data to SRI level)
  base_path <- file.path(script_dir, "..", "..", "..")

  # Path to CSV specification
  csv_file <- file.path(base_path, "Procesamiento/Bases/empleo2024_spec_summary.csv")

  # Check if file exists
  if (file.exists(csv_file)) {

    # Print summary
    print_csv_spec_summary(csv_file)

    # Generate synthetic data
    fake_data <- fake_data_from_csv(csv_file, n = 1000, seed = 42)

    # Show result
    cat("\nGenerated data preview:\n")
    print(fake_data[1:10, 1:8])

    # Save synthetic data
    output_file <- file.path(base_path, "Procesamiento/Bases/empleo2024_fake_from_csv.csv")
    write.csv(fake_data, output_file, row.names = FALSE)
    cat("\nSynthetic data saved to:", output_file, "\n")

  } else {
    cat("CSV file not found at:", csv_file, "\n")
    cat("Please provide the correct path to your CSV specification file.\n")
  }
}
