# =============================================================================
# SYNTHETIC DATA GENERATION FUNCTION
# =============================================================================
# This function creates a synthetic version of a dataset that preserves:
# - Variable types (numeric, character, labelled)
# - Marginal distributions (mean, variance, skewness)
# - Missing value patterns
# - Categorical proportions
# - Stata attributes (labels, formats)
# =============================================================================

lapply(c("haven","dplyr","purrr","vctrs"), function(p) {
  if (!require(p, character.only = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
})

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

#' Detect if a numeric variable is likely categorical (few unique values)
#' @param x numeric vector
#' @param threshold maximum proportion of unique values to total for categorical
is_likely_categorical <- function(x, threshold = 0.05) {
  x_clean <- x[!is.na(x)]
  if (length(x_clean) == 0) return(TRUE)
  n_unique <- length(unique(x_clean))
  # If less than 5% unique values OR fewer than 30 unique values, treat as categorical
  (n_unique / length(x_clean) < threshold) | (n_unique <= 30)
}

#' Calculate skewness
#' @param x numeric vector
calc_skewness <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 3) return(0)
  n <- length(x)
  m <- mean(x)
  s <- sd(x)
  if (s == 0) return(0)
  sum((x - m)^3) / (n * s^3)
}

#' Generate synthetic values for a categorical variable
#' @param x original vector
#' @param n number of values to generate
#' @param na_prop proportion of NAs

generate_categorical <- function(x, n, na_prop = NULL) {
  x_clean <- x[!is.na(x)]

  if (length(x_clean) == 0) {
    return(rep(NA, n))
  }

  # Get value frequencies
  freq_table <- table(x_clean)
  values <- names(freq_table)
  probs <- as.numeric(freq_table) / sum(freq_table)

  # Generate synthetic values
  synthetic <- sample(values, size = n, replace = TRUE, prob = probs)

  # Convert back to original type
  if (is.numeric(x_clean)) {
    synthetic <- as.numeric(synthetic)
  }

  # Add NAs
  if (is.null(na_prop)) {
    na_prop <- mean(is.na(x))
  }
  if (na_prop > 0) {
    na_indices <- sample(1:n, size = round(n * na_prop), replace = FALSE)
    synthetic[na_indices] <- NA
  }

  return(synthetic)
}

#' Generate synthetic values for a continuous numeric variable
#' @param x original vector
#' @param n number of values to generate
generate_continuous <- function(x, n) {
  x_clean <- x[!is.na(x)]
  na_prop <- mean(is.na(x))

  if (length(x_clean) == 0) {
    return(rep(NA, n))
  }

  # Calculate statistics
  x_mean <- mean(x_clean)
  x_sd <- sd(x_clean)
  x_min <- min(x_clean)
  x_max <- max(x_clean)
  x_skew <- calc_skewness(x_clean)

  # Coefficient of variation to detect heavy-tailed distributions
  cv <- x_sd / abs(x_mean + 0.001)

  # Handle zero variance
  if (is.na(x_sd) || x_sd == 0) {
    synthetic <- rep(x_mean, n)
  } else if (cv > 2 || abs(x_skew) > 3) {
    # For highly variable or extremely skewed data, use empirical bootstrap
    # This better preserves extreme values and heavy tails
    synthetic <- sample(x_clean, size = n, replace = TRUE)
    # Add small noise proportional to local density
    noise_sd <- x_sd * 0.05
    synthetic <- synthetic + rnorm(n, mean = 0, sd = noise_sd)
    # Ensure bounds
    synthetic <- pmax(synthetic, x_min)
    synthetic <- pmin(synthetic, x_max)
  } else if (abs(x_skew) > 1) {
    # For moderately skewed distributions, use log-normal or shifted distributions
    if (x_min >= 0 && x_skew > 0) {
      # Right-skewed, non-negative: use log-normal
      # Shift data to avoid log(0)
      shift <- ifelse(x_min == 0, 1, 0)
      x_shifted <- x_clean + shift

      # Parameters for log-normal
      log_mean <- mean(log(x_shifted))
      log_sd <- sd(log(x_shifted))

      if (is.finite(log_sd) && log_sd > 0) {
        synthetic <- rlnorm(n, meanlog = log_mean, sdlog = log_sd) - shift
      } else {
        synthetic <- rnorm(n, mean = x_mean, sd = max(x_sd, 0.01))
      }
    } else {
      # Use empirical quantile-based approach for other skewed data
      synthetic <- sample(x_clean, size = n, replace = TRUE)
      # Add small noise
      noise_sd <- x_sd * 0.1
      synthetic <- synthetic + rnorm(n, mean = 0, sd = noise_sd)
    }
  } else {
    # Approximately normal: use normal distribution
    synthetic <- rnorm(n, mean = x_mean, sd = x_sd)
  }

  # Enforce bounds (with small buffer)
  synthetic <- pmax(synthetic, x_min - 0.01 * abs(x_min))
  synthetic <- pmin(synthetic, x_max + 0.01 * abs(x_max))

  # Check if original was integer-like
  if (all(x_clean == floor(x_clean))) {
    synthetic <- round(synthetic)
  }

  # Add NAs
  if (na_prop > 0) {
    na_indices <- sample(1:n, size = round(n * na_prop), replace = FALSE)
    synthetic[na_indices] <- NA
  }

  return(synthetic)
}

#' Generate synthetic ID strings that follow the pattern of the original
#' @param x original character vector
#' @param n number of values to generate
generate_id_string <- function(x, n) {
  x_clean <- x[!is.na(x)]
  na_prop <- mean(is.na(x))

  if (length(x_clean) == 0) {
    return(rep(NA_character_, n))
  }

  # Analyze string patterns
  str_lengths <- nchar(x_clean)
  unique_lengths <- unique(str_lengths)

  # Check if all strings are the same length (likely coded IDs)
  if (length(unique_lengths) == 1) {
    str_len <- unique_lengths[1]

    # Check if numeric string
    is_numeric_string <- all(grepl("^[0-9]+$", x_clean))

    if (is_numeric_string && str_len <= 9) {
      # For short numeric strings, generate from range
      orig_nums <- as.numeric(x_clean)
      synthetic_nums <- sample(
        seq(min(orig_nums), max(orig_nums)),
        size = n,
        replace = TRUE
      )
      synthetic <- sprintf(paste0("%0", str_len, "d"), synthetic_nums)
    } else {
      # For long numeric strings or alphanumeric, sample from original values
      # This preserves valid ID patterns for long identifiers
      synthetic <- sample(x_clean, size = n, replace = TRUE)
    }
  } else {
    # Variable length strings - sample from original
    synthetic <- sample(x_clean, size = n, replace = TRUE)
  }

  # Add NAs
  if (na_prop > 0 && n > 0) {
    na_count <- max(1, round(n * na_prop))
    na_indices <- sample(1:n, size = min(na_count, n), replace = FALSE)
    synthetic[na_indices] <- NA_character_
  }

  return(synthetic)
}

#' Copy Stata/haven attributes from original to synthetic variable
#' @param original original variable with attributes
#' @param synthetic synthetic variable to add attributes to
copy_stata_attributes <- function(original, synthetic) {

  # Check if original is character-labelled (special case)
  is_char_lbl <- is_character_labelled(original)

  # For haven_labelled class, copy labels
  if (inherits(original, "haven_labelled")) {
    labels <- attr(original, "labels")

    if (!is.null(labels)) {
      if (is_char_lbl) {
        # For character-labelled variables, manually set class and attributes
        # because haven::labelled() doesn't handle character values with numeric labels
        class(synthetic) <- class(original)
        attr(synthetic, "labels") <- labels
      } else {
        # For numeric-labelled variables, use haven::labelled
        synthetic <- haven::labelled(synthetic, labels = labels)
      }
    }
  }

  # Copy label attribute (variable description)
  if (!is.null(attr(original, "label"))) {
    attr(synthetic, "label") <- attr(original, "label")
  }

  # Copy format.stata attribute
  if (!is.null(attr(original, "format.stata"))) {
    attr(synthetic, "format.stata") <- attr(original, "format.stata")
  }

  return(synthetic)
}

#' Check if underlying data of a haven_labelled variable is character
#' @param x variable to check
is_character_labelled <- function(x) {
  if (!inherits(x, "haven_labelled")) return(FALSE)
  # Check the underlying data type
  underlying <- vctrs::vec_data(x)
  is.character(underlying)
}

#' Analyze a single variable and return its characteristics
#' @param x variable to analyze
#' @param var_name name of the variable
analyze_variable <- function(x, var_name) {
  analysis <- list(
    name = var_name,
    class = class(x),
    type = NA_character_,
    n = length(x),
    n_missing = sum(is.na(x)),
    missing_prop = mean(is.na(x)),
    n_unique = length(unique(x[!is.na(x)])),
    is_labelled = inherits(x, "haven_labelled"),
    is_char_labelled = is_character_labelled(x),
    has_stata_label = !is.null(attr(x, "label")),
    stata_label = attr(x, "label"),
    has_value_labels = !is.null(attr(x, "labels"))
  )

  # For character-labelled variables, treat as character
  if (analysis$is_char_labelled) {
    analysis$type <- "character_labelled"
    x_raw <- vctrs::vec_data(x)
    x_clean <- x_raw[!is.na(x_raw)]

    if (length(x_clean) > 0) {
      analysis$str_lengths <- range(nchar(x_clean))
      analysis$is_numeric_string <- all(grepl("^[0-9]+$", x_clean))
    }
  } else if (is.numeric(x)) {
    x_clean <- x[!is.na(x)]
    analysis$type <- "numeric"

    if (length(x_clean) > 0) {
      analysis$min <- min(x_clean)
      analysis$max <- max(x_clean)
      analysis$mean <- mean(x_clean)
      analysis$sd <- sd(x_clean)
      analysis$skewness <- calc_skewness(x_clean)
      analysis$is_integer_like <- all(x_clean == floor(x_clean))
      analysis$is_categorical <- is_likely_categorical(x)
    }
  } else if (is.character(x)) {
    analysis$type <- "character"
    x_clean <- x[!is.na(x)]

    if (length(x_clean) > 0) {
      analysis$str_lengths <- range(nchar(x_clean))
      analysis$is_numeric_string <- all(grepl("^[0-9]+$", x_clean))
    }
  }
  
  return(analysis)
}

#' Generate synthetic values for a character-labelled variable
#' @param x original haven_labelled character vector
#' @param n number of values to generate
generate_char_labelled <- function(x, n) {
  # Get underlying character values
  x_raw <- vctrs::vec_data(x)
  x_clean <- x_raw[!is.na(x_raw)]
  na_prop <- mean(is.na(x_raw))

  if (length(x_clean) == 0) {
    return(rep(NA_character_, n))
  }

  # Get value frequencies
  freq_table <- table(x_clean)
  values <- names(freq_table)
  probs <- as.numeric(freq_table) / sum(freq_table)

  # Generate synthetic values
  synthetic <- sample(values, size = n, replace = TRUE, prob = probs)

  # Add NAs
  if (na_prop > 0) {
    na_indices <- sample(1:n, size = round(n * na_prop), replace = FALSE)
    synthetic[na_indices] <- NA_character_
  }

  return(synthetic)
}

#' Generate synthetic values for a single variable
#' @param x original variable
#' @param n number of values to generate
#' @param analysis pre-computed analysis (optional)
generate_synthetic_variable <- function(x, n, analysis = NULL) {
  if (is.null(analysis)) {
    analysis <- analyze_variable(x, "temp")
  }

  # Handle completely missing variables
  if (analysis$n_missing == analysis$n) {
    if (analysis$is_char_labelled || analysis$type == "character") {
      synthetic <- rep(NA_character_, n)
    } else {
      synthetic <- rep(NA_real_, n)
    }
    return(copy_stata_attributes(x, synthetic))
  }

  # Generate based on type
  if (analysis$type == "character_labelled") {
    # Character-labelled variables (chr+lbl in Stata)
    synthetic <- generate_char_labelled(x, n)
  } else if (analysis$type == "character") {
    synthetic <- generate_id_string(x, n)
  } else if (analysis$type == "numeric") {
    if (analysis$is_categorical || analysis$is_labelled) {
      synthetic <- generate_categorical(x, n, analysis$missing_prop)
    } else {
      synthetic <- generate_continuous(x, n)
    }
  } else {
    # Fallback: sample from original
    synthetic <- sample(x, size = n, replace = TRUE)
  }

  # Copy attributes
  synthetic <- copy_stata_attributes(x, synthetic)

  return(synthetic)
}

# -----------------------------------------------------------------------------
# Main Function
# -----------------------------------------------------------------------------

#' Create a synthetic (fake) version of a dataset
#'
#' This function generates a synthetic dataset that preserves the structure,
#' variable types, distributions, and missing patterns of the original data.
#'
#' @param data A data frame or tibble to create synthetic data from.
#'   Can also be a file path to a .dta, .csv, .rds, or .sav file.
#' @param n Number of rows in the synthetic dataset.
#'   Default is NULL, which uses the same number of rows as the original.
#' @param seed Random seed for reproducibility. Default is 12345.
#' @param verbose Print progress messages. Default is TRUE.
#'
#' @return A tibble with synthetic data matching the structure of the original.
#'
#' @examples
#' # From a data frame
#' fake_df <- fake_data_creation(original_data)
#'
#' # From a file path
#' fake_df <- fake_data_creation("path/to/data.dta")
#'
#' # With custom number of rows
#' fake_df <- fake_data_creation(original_data, n = 1000)
#'
fake_data_creation <- function(data, n = NULL, seed = 12345, verbose = TRUE) {

  set.seed(seed)

  # Load data if path is provided
  if (is.character(data) && length(data) == 1 && file.exists(data)) {
    if (verbose) message("Loading data from: ", data)

    ext <- tolower(tools::file_ext(data))
    data <- switch(ext,
      "dta" = haven::read_dta(data),
      "sav" = haven::read_sav(data),
      "csv" = readr::read_csv(data, show_col_types = FALSE),
      "rds" = readRDS(data),
      stop("Unsupported file format: ", ext)
    )
  }

  # Validate input
  if (!is.data.frame(data)) {
    stop("Input must be a data frame, tibble, or path to a data file.")
  }

  # Set number of rows
  if (is.null(n)) {
    n <- nrow(data)
  }

  if (verbose) {
    message("Original data: ", nrow(data), " rows x ", ncol(data), " columns")
    message("Generating synthetic data with ", n, " rows...")
  }

  # Analyze all variables
  var_names <- names(data)
  n_vars <- length(var_names)

  if (verbose) {
    message("Analyzing ", n_vars, " variables...")
  }

  analyses <- map(var_names, ~analyze_variable(data[[.x]], .x))
  names(analyses) <- var_names

  # Generate synthetic data
  if (verbose) {
    pb <- txtProgressBar(min = 0, max = n_vars, style = 3)
  }

  synthetic_list <- vector("list", n_vars)
  names(synthetic_list) <- var_names

  for (i in seq_along(var_names)) {
    var_name <- var_names[i]
    synthetic_list[[var_name]] <- generate_synthetic_variable(
      data[[var_name]],
      n,
      analyses[[var_name]]
    )

    if (verbose) {
      setTxtProgressBar(pb, i)
    }
  }

  if (verbose) {
    close(pb)
  }

  # Combine into data frame
  synthetic_df <- as_tibble(synthetic_list)

  if (verbose) {
    message("Done! Synthetic dataset created successfully.")
    message("\nVariable type summary:")

    type_counts <- table(sapply(analyses, function(a) {
      if (a$is_labelled) "labelled" else a$type
    }))
    print(type_counts)
  }

  return(synthetic_df)
}

#' Validate synthetic data against original
#'
#' @param original Original dataset
#' @param synthetic Synthetic dataset
#' @param sample_vars Number of variables to sample for detailed comparison
validate_synthetic <- function(original, synthetic, sample_vars = 10) {

  message("=== Validation Report ===\n")

  # Check dimensions
  message("Dimensions:")
  message("  Original:  ", nrow(original), " x ", ncol(original))
  message("  Synthetic: ", nrow(synthetic), " x ", ncol(synthetic))

  # Check column names match
  if (!all(names(original) == names(synthetic))) {
    warning("Column names do not match!")
  } else {
    message("  Column names: Match")
  }

  # Check types
  type_match <- sapply(names(original), function(v) {
    class(original[[v]])[1] == class(synthetic[[v]])[1]
  })
  message("  Type matches: ", sum(type_match), "/", length(type_match))

  # Sample some variables for detailed comparison
  vars_to_check <- sample(names(original), min(sample_vars, ncol(original)))

  message("\nDetailed comparison for sampled variables:")
  for (v in vars_to_check) {
    message("\n--- ", v, " ---")
    orig <- original[[v]]
    synth <- synthetic[[v]]

    message("  Class: ", paste(class(orig), collapse=", "), " -> ",
            paste(class(synth), collapse=", "))
    message("  NA%:   ", round(mean(is.na(orig)) * 100, 1), "% -> ",
            round(mean(is.na(synth)) * 100, 1), "%")

    if (is.numeric(orig)) {
      orig_clean <- orig[!is.na(orig)]
      synth_clean <- synth[!is.na(synth)]

      if (length(orig_clean) > 0 && length(synth_clean) > 0) {
        message("  Mean:  ", round(mean(orig_clean), 2), " -> ",
                round(mean(synth_clean), 2))
        message("  SD:    ", round(sd(orig_clean), 2), " -> ",
                round(sd(synth_clean), 2))
        message("  Range: [", round(min(orig_clean), 2), ", ",
                round(max(orig_clean), 2), "] -> [",
                round(min(synth_clean), 2), ", ",
                round(max(synth_clean), 2), "]")
      }
    }

    # Check if labelled attributes preserved
    if (inherits(orig, "haven_labelled")) {
      labels_match <- identical(attr(orig, "labels"), attr(synth, "labels"))
      message("  Labels preserved: ", ifelse(labels_match, "Yes", "No"))
    }
  }

  message("\n=== End of Validation ===")
}

# -----------------------------------------------------------------------------
# Example Usage (commented out)
# -----------------------------------------------------------------------------

# Generate synthetic data
fake_data <- fake_data_creation(
  "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/empleo2024.dta",
  n = NULL,  # Same number of rows as original
  seed = 12345,
  verbose = TRUE
)

# Load original data
original_data <- haven::read_dta("/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/empleo2024.dta")

# Validate
validate_synthetic(original_data, fake_data)

saveRDS(fake_data, "SRI/Procesamiento/Bases/fake_empleo2024.rds")


# Save synthetic data
haven::write_dta(fake_data, "SRI/Procesamiento/Bases/fake_empleo2024.dta")


fake_data <- haven::read_dta("/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/fake_empleo2024.dta")
