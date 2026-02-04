# =============================================================================
# SYNTHETIC DATA GENERATION FROM SPECIFICATION
# =============================================================================
# This script generates synthetic datasets from a data specification object
# WITHOUT requiring access to the original data at runtime.
#
# Two main workflows:
# 1. Extract data_spec from original data (one-time, optional)
# 2. Generate synthetic data from data_spec (can be shared/reused)
# =============================================================================

lapply(c("haven", "dplyr", "purrr", "vctrs", "tibble"), function(p) {
  if (!require(p, character.only = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
})

# -----------------------------------------------------------------------------
# Helper Functions for Synthetic Generation
# -----------------------------------------------------------------------------

#' Null-coalescing operator (return first non-NULL value)
`%||%` <- function(x, y) if (is.null(x)) y else x

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

#' Detect if a numeric variable is likely categorical (few unique values)
#' @param x numeric vector
#' @param threshold maximum proportion of unique values to total for categorical
is_likely_categorical <- function(x, threshold = 0.05) {
  x_clean <- x[!is.na(x)]
  if (length(x_clean) == 0) return(TRUE)
  n_unique <- length(unique(x_clean))
  (n_unique / length(x_clean) < threshold) | (n_unique <= 30)
}

#' Check if underlying data of a haven_labelled variable is character
#' @param x variable to check
is_character_labelled <- function(x) {
  if (!inherits(x, "haven_labelled")) return(FALSE)
  underlying <- vctrs::vec_data(x)
  is.character(underlying)
}

# -----------------------------------------------------------------------------
# DATA SPECIFICATION EXTRACTION (from original data - one-time step)
# -----------------------------------------------------------------------------

#' Detect if a variable is high-cardinality (likely an ID or unique identifier)
#' @param n_unique number of unique values
#' @param n_total total number of non-missing observations
#' @param max_categories maximum number of categories to store (default 100)
#' @return TRUE if high-cardinality
is_high_cardinality <- function(n_unique, n_total, max_categories = 100) {
  if (n_total == 0) return(FALSE)
  # High cardinality if: more than max_categories unique values OR
  
  # uniqueness ratio > 50% (most values are unique, suggesting IDs)
  (n_unique > max_categories) || (n_unique / n_total > 0.5)
}

#' Extract specification for a single variable
#' @param x variable to analyze
#' @param var_name name of the variable
#' @param max_categories maximum number of categories to store (default 100)
#' @return list with complete variable specification
extract_variable_spec <- function(x, var_name, max_categories = 100) {
  spec <- list(
    name = var_name,
    class = class(x),
    n_original = length(x),
    missing_prop = mean(is.na(x)),
    is_labelled = inherits(x, "haven_labelled"),
    is_char_labelled = is_character_labelled(x),
    stata_label = attr(x, "label"),
    value_labels = attr(x, "labels"),
    stata_format = attr(x, "format.stata")
  )
  
  # Determine distribution type and extract relevant parameters
  if (spec$is_char_labelled) {
    # Character-labelled variables
    spec$type <- "character_labelled"
    x_raw <- vctrs::vec_data(x)
    x_clean <- x_raw[!is.na(x_raw)]
    
    if (length(x_clean) > 0) {
      spec$n_unique <- length(unique(x_clean))
      spec$str_lengths <- range(nchar(x_clean))
      
      # Check if high-cardinality (ID-like)
      if (is_high_cardinality(spec$n_unique, length(x_clean), max_categories)) {
        # Treat as ID - don't store all values
        spec$dist_form <- "high_cardinality_id"
        spec$is_numeric_string <- all(grepl("^[0-9]+$", x_clean))
        
        if (spec$is_numeric_string) {
          orig_nums <- as.numeric(x_clean)
          spec$id_min <- min(orig_nums)
          spec$id_max <- max(orig_nums)
          spec$id_length <- spec$str_lengths[1]
        }
        # Don't store categories - will generate random IDs
      } else {
        # Low cardinality - store categories
        spec$dist_form <- "categorical"
        freq_table <- table(x_clean)
        spec$categories <- names(freq_table)
        spec$category_probs <- as.numeric(freq_table) / sum(freq_table)
      }
    }
    
  } else if (is.numeric(x)) {
    x_clean <- x[!is.na(x)]
    spec$type <- "numeric"
    
    if (length(x_clean) > 0) {
      # Basic statistics
      spec$min <- min(x_clean)
      spec$max <- max(x_clean)
      spec$mean <- mean(x_clean)
      spec$sd <- sd(x_clean)
      spec$skewness <- calc_skewness(x_clean)
      spec$is_integer_like <- all(x_clean == floor(x_clean))
      spec$n_unique <- length(unique(x_clean))
      
      # Quantiles for non-normal distributions
      spec$quantiles <- quantile(x_clean, probs = c(0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99))
      
      # Coefficient of variation
      spec$cv <- spec$sd / (abs(spec$mean) + 0.001)
      
      # Check if this is a numeric ID (high cardinality integer)
      if (spec$is_integer_like && is_high_cardinality(spec$n_unique, length(x_clean), max_categories)) {
        spec$dist_form <- "numeric_id"
        # Only store range, not all values
      } else if (spec$is_labelled || is_likely_categorical(x)) {
        spec$dist_form <- "categorical"
        freq_table <- table(x_clean)
        spec$categories <- as.numeric(names(freq_table))
        spec$category_probs <- as.numeric(freq_table) / sum(freq_table)
      } else if (spec$cv > 2 || abs(spec$skewness) > 3) {
        spec$dist_form <- "heavy_tailed"
      } else if (abs(spec$skewness) > 1) {
        if (spec$min >= 0 && spec$skewness > 0) {
          spec$dist_form <- "lognormal"
          # Store log-scale parameters
          shift <- ifelse(spec$min == 0, 1, 0)
          x_shifted <- x_clean + shift
          spec$log_mean <- mean(log(x_shifted))
          spec$log_sd <- sd(log(x_shifted))
          spec$log_shift <- shift
        } else {
          spec$dist_form <- "skewed_empirical"
        }
      } else {
        spec$dist_form <- "normal"
      }
    } else {
      spec$dist_form <- "empty"
    }
    
  } else if (is.character(x)) {
    spec$type <- "character"
    x_clean <- x[!is.na(x)]
    
    if (length(x_clean) > 0) {
      spec$str_lengths <- range(nchar(x_clean))
      spec$is_numeric_string <- all(grepl("^[0-9]+$", x_clean))
      spec$n_unique <- length(unique(x_clean))
      
      # For ID-like strings with fixed length
      unique_lengths <- unique(nchar(x_clean))
      spec$fixed_length <- length(unique_lengths) == 1
      
      # Check if high-cardinality (ID-like variable)
      if (is_high_cardinality(spec$n_unique, length(x_clean), max_categories)) {
        # High cardinality - treat as ID, don't store all values
        if (spec$is_numeric_string) {
          spec$dist_form <- "numeric_id"
          orig_nums <- as.numeric(x_clean)
          spec$id_min <- min(orig_nums)
          spec$id_max <- max(orig_nums)
          spec$id_length <- spec$str_lengths[1]
        } else {
          # Alphanumeric high-cardinality - store pattern info only
          spec$dist_form <- "alphanumeric_id"
          # Analyze character composition for generation
          all_chars <- unlist(strsplit(x_clean, ""))
          spec$has_digits <- any(grepl("[0-9]", all_chars))
          spec$has_letters <- any(grepl("[a-zA-Z]", all_chars))
          spec$has_upper <- any(grepl("[A-Z]", all_chars))
          spec$has_lower <- any(grepl("[a-z]", all_chars))
        }
      } else if (spec$fixed_length && spec$is_numeric_string && spec$str_lengths[1] <= 9) {
        # Low cardinality numeric string
        spec$dist_form <- "numeric_id"
        orig_nums <- as.numeric(x_clean)
        spec$id_min <- min(orig_nums)
        spec$id_max <- max(orig_nums)
        spec$id_length <- spec$str_lengths[1]
      } else {
        # Low cardinality - store categories
        spec$dist_form <- "categorical_string"
        freq_table <- table(x_clean)
        spec$categories <- names(freq_table)
        spec$category_probs <- as.numeric(freq_table) / sum(freq_table)
      }
    } else {
      spec$dist_form <- "empty"
    }
    
  } else {
    spec$type <- "other"
    spec$dist_form <- "unknown"
  }
  
  return(spec)
}

#' Extract complete data specification from a dataset
#' @param data data frame or path to data file
#' @param verbose print progress messages
#' @return list containing specifications for all variables
extract_data_spec <- function(data, verbose = TRUE) {
  
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
  
  if (!is.data.frame(data)) {
    stop("Input must be a data frame, tibble, or path to a data file.")
  }
  
  var_names <- names(data)
  n_vars <- length(var_names)
  
  if (verbose) {
    message("Extracting specification from ", nrow(data), " rows x ", n_vars, " columns...")
    pb <- txtProgressBar(min = 0, max = n_vars, style = 3)
  }
  
  specs <- vector("list", n_vars)
  names(specs) <- var_names
  
  for (i in seq_along(var_names)) {
    specs[[var_names[i]]] <- extract_variable_spec(data[[var_names[i]]], var_names[i])
    if (verbose) setTxtProgressBar(pb, i)
  }
  
  if (verbose) close(pb)
  
  # Create data_spec object
  data_spec <- list(
    variables = specs,
    n_original = nrow(data),
    n_vars = n_vars,
    var_names = var_names,
    extraction_date = Sys.time()
  )
  
  class(data_spec) <- c("data_spec", "list")
  
  if (verbose) message("Specification extracted successfully!")
  
  return(data_spec)
}

#' Save data specification to file
#' @param data_spec data specification object
#' @param file path to save the specification
save_data_spec <- function(data_spec, file) {
  saveRDS(data_spec, file)
  message("Data specification saved to: ", file)
}

#' Load data specification from file
#' @param file path to the specification file
load_data_spec <- function(file) {
  data_spec <- readRDS(file)
  if (!inherits(data_spec, "data_spec")) {
    warning("Loaded object may not be a valid data_spec")
  }
  return(data_spec)
}

# -----------------------------------------------------------------------------
# SYNTHETIC DATA GENERATION FROM SPECIFICATION
# -----------------------------------------------------------------------------

#' Generate synthetic values for a categorical variable from spec
#' @param spec variable specification
#' @param n number of values to generate
generate_categorical_from_spec <- function(spec, n) {
  if (is.null(spec$categories) || length(spec$categories) == 0) {
    return(rep(NA, n))
  }
  
  # Generate synthetic values
  synthetic <- sample(spec$categories, size = n, replace = TRUE, prob = spec$category_probs)
  
  # Add NAs
  if (spec$missing_prop > 0) {
    na_indices <- sample(1:n, size = round(n * spec$missing_prop), replace = FALSE)
    synthetic[na_indices] <- NA
  }
  
  return(synthetic)
}

#' Generate synthetic values for a continuous numeric variable from spec
#' @param spec variable specification
#' @param n number of values to generate
generate_continuous_from_spec <- function(spec, n) {
  
  if (spec$dist_form == "empty" || is.null(spec$mean)) {
    return(rep(NA_real_, n))
  }
  
  # Handle zero variance
  if (is.na(spec$sd) || spec$sd == 0) {
    synthetic <- rep(spec$mean, n)
  } else if (spec$dist_form == "heavy_tailed") {
    # For heavy-tailed, use quantile-based generation
    # Sample from quantiles with interpolation
    probs <- c(0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99)
    quantiles <- spec$quantiles
    
    u <- runif(n)
    synthetic <- approx(c(0, probs, 1),
                        c(spec$min, quantiles, spec$max),
                        xout = u, rule = 2)$y
    
    # Add small noise
    noise_sd <- spec$sd * 0.05
    synthetic <- synthetic + rnorm(n, mean = 0, sd = noise_sd)
    synthetic <- pmax(synthetic, spec$min)
    synthetic <- pmin(synthetic, spec$max)
    
  } else if (spec$dist_form == "lognormal") {
    if (!is.null(spec$log_sd) && is.finite(spec$log_sd) && spec$log_sd > 0) {
      synthetic <- rlnorm(n, meanlog = spec$log_mean, sdlog = spec$log_sd) - spec$log_shift
    } else {
      synthetic <- rnorm(n, mean = spec$mean, sd = max(spec$sd, 0.01))
    }
    
  } else if (spec$dist_form == "skewed_empirical") {
    # Use quantile-based generation for skewed data
    probs <- c(0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99)
    quantiles <- spec$quantiles
    
    u <- runif(n)
    synthetic <- approx(c(0, probs, 1),
                        c(spec$min, quantiles, spec$max),
                        xout = u, rule = 2)$y
    
    # Add small noise
    noise_sd <- spec$sd * 0.1
    synthetic <- synthetic + rnorm(n, mean = 0, sd = noise_sd)
    
  } else {
    # Normal distribution
    synthetic <- rnorm(n, mean = spec$mean, sd = spec$sd)
  }
  
  # Enforce bounds
  synthetic <- pmax(synthetic, spec$min - 0.01 * abs(spec$min))
  synthetic <- pmin(synthetic, spec$max + 0.01 * abs(spec$max))
  
  # Round if integer-like
  if (isTRUE(spec$is_integer_like)) {
    synthetic <- round(synthetic)
  }
  
  # Add NAs
  if (spec$missing_prop > 0) {
    na_count <- round(n * spec$missing_prop)
    if (na_count > 0) {
      na_indices <- sample(1:n, size = na_count, replace = FALSE)
      synthetic[na_indices] <- NA
    }
  }
  
  return(synthetic)
}

#' Generate synthetic ID strings from spec
#' @param spec variable specification
#' @param n number of values to generate
generate_id_from_spec <- function(spec, n) {
  
  if (spec$dist_form == "empty") {
    return(rep(NA_character_, n))
  }
  
  if (spec$dist_form == "numeric_id") {
    # Generate numeric IDs within range
    id_min <- spec$id_min %||% 1
    id_max <- spec$id_max %||% (10^spec$id_length - 1)
    id_length <- spec$id_length %||% spec$str_lengths[1] %||% 10
    
    synthetic_nums <- sample(seq(id_min, id_max), size = n, replace = TRUE)
    synthetic <- sprintf(paste0("%0", id_length, "d"), synthetic_nums)
    
  } else if (spec$dist_form == "alphanumeric_id") {
    # Generate random alphanumeric IDs matching pattern
    str_len <- spec$str_lengths[1] %||% 10
    
    # Build character pool based on detected patterns
    char_pool <- c()
    if (isTRUE(spec$has_digits)) char_pool <- c(char_pool, 0:9)
    if (isTRUE(spec$has_upper)) char_pool <- c(char_pool, LETTERS)
    if (isTRUE(spec$has_lower)) char_pool <- c(char_pool, letters)
    
    # Fallback if no pattern detected
    if (length(char_pool) == 0) char_pool <- c(0:9, letters)
    
    synthetic <- replicate(n, paste0(sample(char_pool, str_len, replace = TRUE), collapse = ""))
    
  } else if (spec$dist_form == "categorical_string") {
    # Sample from categories (only for low-cardinality)
    synthetic <- sample(spec$categories, size = n, replace = TRUE, prob = spec$category_probs)
    
  } else {
    # Fallback - generate random alphanumeric
    str_len <- spec$str_lengths[1] %||% 10
    synthetic <- replicate(n, paste0(sample(c(0:9, letters), str_len, replace = TRUE), collapse = ""))
  }
  
  # Add NAs
  if (spec$missing_prop > 0 && n > 0) {
    na_count <- max(1, round(n * spec$missing_prop))
    na_indices <- sample(1:n, size = min(na_count, n), replace = FALSE)
    synthetic[na_indices] <- NA_character_
  }
  
  return(synthetic)
}

#' Generate synthetic values for character-labelled variable from spec
#' @param spec variable specification
#' @param n number of values to generate
generate_char_labelled_from_spec <- function(spec, n) {
  
  # Handle high-cardinality ID-like variables
  if (spec$dist_form == "high_cardinality_id") {
    # Generate IDs without storing all original values
    if (isTRUE(spec$is_numeric_string) && !is.null(spec$id_min)) {
      # Numeric string IDs
      id_length <- spec$id_length %||% spec$str_lengths[1] %||% 10
      synthetic_nums <- sample(seq(spec$id_min, spec$id_max), size = n, replace = TRUE)
      synthetic <- sprintf(paste0("%0", id_length, "d"), synthetic_nums)
    } else {
      # Alphanumeric IDs - generate random strings
      str_len <- spec$str_lengths[1] %||% 10
      synthetic <- replicate(n, paste0(sample(c(0:9, letters, LETTERS), str_len, replace = TRUE), collapse = ""))
    }
  } else {
    # Low cardinality - sample from stored categories
    if (is.null(spec$categories) || length(spec$categories) == 0) {
      return(rep(NA_character_, n))
    }
    synthetic <- sample(spec$categories, size = n, replace = TRUE, prob = spec$category_probs)
  }
  
  # Add NAs
  if (spec$missing_prop > 0) {
    na_count <- round(n * spec$missing_prop)
    if (na_count > 0) {
      na_indices <- sample(1:n, size = na_count, replace = FALSE)
      synthetic[na_indices] <- NA_character_
    }
  }
  
  return(synthetic)
}

#' Apply Stata/haven attributes from specification
#' @param synthetic synthetic variable
#' @param spec variable specification
apply_stata_attributes <- function(synthetic, spec) {
  
  # Apply haven_labelled class if needed
  if (isTRUE(spec$is_labelled) && !is.null(spec$value_labels)) {
    if (isTRUE(spec$is_char_labelled)) {
      # For character-labelled variables
      class(synthetic) <- spec$class
      attr(synthetic, "labels") <- spec$value_labels
    } else {
      # For numeric-labelled variables
      synthetic <- haven::labelled(synthetic, labels = spec$value_labels)
    }
  }
  
  # Copy variable label
  if (!is.null(spec$stata_label)) {
    attr(synthetic, "label") <- spec$stata_label
  }
  
  # Copy Stata format
  if (!is.null(spec$stata_format)) {
    attr(synthetic, "format.stata") <- spec$stata_format
  }
  
  return(synthetic)
}

#' Generate synthetic numeric IDs from spec
#' @param spec variable specification
#' @param n number of values to generate
generate_numeric_id_from_spec <- function(spec, n) {
  # Generate unique-ish integer IDs within the original range
  synthetic <- sample(seq(spec$min, spec$max), size = n, replace = TRUE)
  
  # Add NAs
  if (spec$missing_prop > 0) {
    na_count <- round(n * spec$missing_prop)
    if (na_count > 0) {
      na_indices <- sample(1:n, size = na_count, replace = FALSE)
      synthetic[na_indices] <- NA_real_
    }
  }
  
  return(synthetic)
}

#' Generate synthetic variable from specification
#' @param spec variable specification
#' @param n number of values to generate
generate_variable_from_spec <- function(spec, n) {
  
  # Handle completely missing variables
  if (spec$missing_prop == 1) {
    if (spec$type == "character" || spec$type == "character_labelled") {
      synthetic <- rep(NA_character_, n)
    } else {
      synthetic <- rep(NA_real_, n)
    }
    return(apply_stata_attributes(synthetic, spec))
  }
  
  # Generate based on type and distribution form
  if (spec$type == "character_labelled") {
    synthetic <- generate_char_labelled_from_spec(spec, n)
    
  } else if (spec$type == "character") {
    synthetic <- generate_id_from_spec(spec, n)
    
  } else if (spec$type == "numeric") {
    if (spec$dist_form == "categorical") {
      synthetic <- generate_categorical_from_spec(spec, n)
    } else if (spec$dist_form == "numeric_id") {
      # High-cardinality numeric ID
      synthetic <- generate_numeric_id_from_spec(spec, n)
    } else {
      synthetic <- generate_continuous_from_spec(spec, n)
    }
    
  } else {
    # Fallback
    synthetic <- rep(NA, n)
  }
  
  # Apply attributes
  synthetic <- apply_stata_attributes(synthetic, spec)
  
  return(synthetic)
}

# -----------------------------------------------------------------------------
# MAIN FUNCTION: Generate synthetic data from specification
# -----------------------------------------------------------------------------

#' Create synthetic data from a data specification
#'
#' Generates a synthetic dataset using only the information stored in a
#' data_spec object, without requiring access to the original data.
#'
#' @param data_spec A data specification object (from extract_data_spec or manually created)
#' @param n Number of rows to generate. Default uses original dataset size.
#' @param seed Random seed for reproducibility. Default is 12345.
#' @param verbose Print progress messages. Default is TRUE.
#'
#' @return A tibble with synthetic data matching the specification.
#'
#' @examples
#' # From a saved specification
#' data_spec <- load_data_spec("my_data_spec.rds")
#' fake_df <- fake_data_creation(data_spec, n = 1000)
#'
#' # From a manually defined specification
#' fake_df <- fake_data_creation(my_manual_spec, n = 500)
#'
fake_data_creation <- function(data_spec, n = NULL, seed = 12345, verbose = TRUE) {
  
  set.seed(seed)
  
  # Validate input
  
  if (!is.list(data_spec) || is.null(data_spec$variables)) {
    stop("data_spec must be a list with a 'variables' component containing variable specifications.")
  }
  
  # Set number of rows
  if (is.null(n)) {
    n <- data_spec$n_original
    if (is.null(n)) {
      stop("n must be specified if data_spec does not contain n_original")
    }
  }
  
  var_specs <- data_spec$variables
  var_names <- names(var_specs)
  n_vars <- length(var_names)
  
  if (verbose) {
    message("Generating synthetic data: ", n, " rows x ", n_vars, " columns...")
    pb <- txtProgressBar(min = 0, max = n_vars, style = 3)
  }
  
  synthetic_list <- vector("list", n_vars)
  names(synthetic_list) <- var_names
  
  for (i in seq_along(var_names)) {
    var_name <- var_names[i]
    synthetic_list[[var_name]] <- generate_variable_from_spec(var_specs[[var_name]], n)
    
    if (verbose) setTxtProgressBar(pb, i)
  }
  
  if (verbose) close(pb)
  
  # Combine into tibble
  synthetic_df <- as_tibble(synthetic_list)
  
  if (verbose) {
    message("Done! Synthetic dataset created successfully.")
    message("\nVariable type summary:")
    type_counts <- table(sapply(var_specs, function(s) s$type))
    print(type_counts)
  }
  
  return(synthetic_df)
}

# -----------------------------------------------------------------------------
# VALIDATION FUNCTION
# -----------------------------------------------------------------------------

#' Validate synthetic data against specification
#' @param synthetic Synthetic dataset
#' @param data_spec Data specification used for generation
#' @param sample_vars Number of variables to sample for detailed comparison
validate_synthetic_from_spec <- function(synthetic, data_spec, sample_vars = 10) {
  
  message("=== Validation Report (vs Specification) ===\n")
  
  var_specs <- data_spec$variables
  
  # Check dimensions
  message("Dimensions:")
  message("  Spec (original): ", data_spec$n_original, " rows")
  message("  Synthetic:       ", nrow(synthetic), " x ", ncol(synthetic))
  
  # Check column names match
  if (!all(names(synthetic) == data_spec$var_names)) {
    warning("Column names do not match specification!")
  } else {
    message("  Column names: Match")
  }
  
  # Sample variables for detailed comparison
  vars_to_check <- sample(data_spec$var_names, min(sample_vars, length(data_spec$var_names)))
  
  message("\nDetailed comparison for sampled variables:")
  for (v in vars_to_check) {
    message("\n--- ", v, " ---")
    spec <- var_specs[[v]]
    synth <- synthetic[[v]]
    
    message("  Type: ", spec$type, " (", spec$dist_form, ")")
    message("  NA%:  Spec=", round(spec$missing_prop * 100, 1), "% -> Synth=",
            round(mean(is.na(synth)) * 100, 1), "%")
    
    if (spec$type == "numeric" && spec$dist_form != "categorical") {
      synth_clean <- synth[!is.na(synth)]
      if (length(synth_clean) > 0 && !is.null(spec$mean)) {
        message("  Mean: Spec=", round(spec$mean, 2), " -> Synth=",
                round(mean(synth_clean), 2))
        message("  SD:   Spec=", round(spec$sd, 2), " -> Synth=",
                round(sd(synth_clean), 2))
        message("  Range: Spec=[", round(spec$min, 2), ", ", round(spec$max, 2),
                "] -> Synth=[", round(min(synth_clean), 2), ", ",
                round(max(synth_clean), 2), "]")
      }
    }
    
    # Check labels preserved
    if (isTRUE(spec$is_labelled)) {
      labels_match <- identical(attr(synth, "labels"), spec$value_labels)
      message("  Labels preserved: ", ifelse(labels_match, "Yes", "No"))
    }
  }
  
  message("\n=== End of Validation ===")
}

# -----------------------------------------------------------------------------
# HELPER: Manually create a variable specification
# -----------------------------------------------------------------------------

#' Create a single variable specification manually
#' @param name Variable name
#' @param type Variable type: "numeric", "character", "character_labelled"
#' @param dist_form Distribution form: "normal", "lognormal", "categorical",
#'   "heavy_tailed", "skewed_empirical", "numeric_id", "categorical_string"
#' @param ... Additional parameters depending on type and dist_form
#' @return A variable specification list
create_var_spec <- function(name, type, dist_form, ...) {
  spec <- list(
    name = name,
    type = type,
    dist_form = dist_form,
    class = switch(type,
                   "numeric" = "numeric",
                   "character" = "character",
                   "character_labelled" = c("haven_labelled", "vctrs_vctr", "character")),
    ...
  )
  
  # Set defaults
  if (is.null(spec$missing_prop)) spec$missing_prop <- 0
  if (is.null(spec$is_labelled)) spec$is_labelled <- FALSE
  if (is.null(spec$is_char_labelled)) spec$is_char_labelled <- (type == "character_labelled")
  
  return(spec)
}

#' Create a complete data specification from a list of variable specs
#' @param ... Variable specifications (from create_var_spec)
#' @param n_original Optional: original dataset size
#' @return A data_spec object
create_data_spec <- function(..., n_original = NULL) {
  var_specs <- list(...)
  
  # Handle if a single list was passed
  if (length(var_specs) == 1 && is.list(var_specs[[1]]) && !is.null(var_specs[[1]]$name)) {
    var_specs <- var_specs
  } else if (length(var_specs) == 1 && is.list(var_specs[[1]])) {
    var_specs <- var_specs[[1]]
  }
  
  # Name the list by variable names
  var_names <- sapply(var_specs, function(s) s$name)
  names(var_specs) <- var_names
  
  data_spec <- list(
    variables = var_specs,
    n_original = n_original,
    n_vars = length(var_specs),
    var_names = var_names,
    creation_date = Sys.time()
  )
  
  class(data_spec) <- c("data_spec", "list")
  
  return(data_spec)
}

# =============================================================================
# EXAMPLE USAGE
# =============================================================================

# -----------------------------------------------------------------------------
# Example 1: Manually define a data specification
# -----------------------------------------------------------------------------

# Define specifications for example variables
example_spec <- create_data_spec(
  
  # Numeric ID variable (e.g., person ID)
  create_var_spec(
    name = "id",
    type = "character",
    dist_form = "numeric_id",
    id_min = 1000,
    id_max = 9999,
    id_length = 4,
    str_lengths = c(4, 4),
    missing_prop = 0
  ),
  
  # Continuous normal variable (e.g., age)
  create_var_spec(
    name = "age",
    type = "numeric",
    dist_form = "normal",
    mean = 42,
    sd = 15,
    min = 18,
    max = 85,
    is_integer_like = TRUE,
    missing_prop = 0.02
  ),
  
  # Right-skewed variable (e.g., income)
  create_var_spec(
    name = "income",
    type = "numeric",
    dist_form = "lognormal",
    mean = 45000,
    sd = 30000,
    min = 0,
    max = 500000,
    log_mean = 10.2,
    log_sd = 0.8,
    log_shift = 1,
    is_integer_like = FALSE,
    missing_prop = 0.15,
    quantiles = c(`1%` = 8000, `5%` = 12000, `25%` = 25000,
                  `50%` = 38000, `75%` = 55000, `95%` = 95000, `99%` = 150000)
  ),
  
  # Categorical labelled variable (e.g., education level)
  create_var_spec(
    name = "education",
    type = "numeric",
    dist_form = "categorical",
    categories = c(1, 2, 3, 4, 5),
    category_probs = c(0.10, 0.25, 0.35, 0.20, 0.10),
    missing_prop = 0.05,
    is_labelled = TRUE,
    value_labels = c("Primary" = 1, "Secondary" = 2, "Technical" = 3,
                     "University" = 4, "Postgrad" = 5),
    stata_label = "Highest education level completed"
  ),
  
  # Binary variable (e.g., employed)
  create_var_spec(
    name = "employed",
    type = "numeric",
    dist_form = "categorical",
    categories = c(0, 1),
    category_probs = c(0.35, 0.65),
    missing_prop = 0.01,
    is_labelled = TRUE,
    value_labels = c("No" = 0, "Yes" = 1),
    stata_label = "Currently employed"
  ),
  
  # Character categorical variable (e.g., region)
  create_var_spec(
    name = "region",
    type = "character",
    dist_form = "categorical_string",
    categories = c("North", "South", "East", "West", "Central"),
    category_probs = c(0.15, 0.25, 0.20, 0.18, 0.22),
    missing_prop = 0.03
  ),
  
  n_original = 5000
)

# Generate synthetic data from the manual specification
# fake_data <- fake_data_creation(example_spec, n = 1000)
# print(fake_data)
# validate_synthetic_from_spec(fake_data, example_spec)

# -----------------------------------------------------------------------------
# Example 2: Extract specification from real data, then generate
# -----------------------------------------------------------------------------

# Step 1: Extract specification (one-time, requires original data)
data_spec <- extract_data_spec("path/to/original_data.dta")
save_data_spec(data_spec, "my_data_spec.rds")

# Step 2: Generate synthetic data (can be done without original data)
data_spec <- load_data_spec("my_data_spec.rds")
fake_data <- fake_data_creation(data_spec, n = 1000)

# -----------------------------------------------------------------------------
# Full workflow example with the empleo2024 dataset (commented out)
# -----------------------------------------------------------------------------

setwd("/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI")

# One-time: Extract and save specification
data_spec <- extract_data_spec(
  "/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/empleo2024.dta"
)

save_data_spec(data_spec, "Procesamiento/Bases/empleo2024_spec.rds")

# # Later: Generate synthetic data from saved specification
data_spec <- load_data_spec("Procesamiento/Bases/empleo2024_spec.rds")
fake_data <- fake_data_creation(data_spec, n = data_spec$n_original, seed = 42)

# # Validate
validate_synthetic_from_spec(fake_data, data_spec)

