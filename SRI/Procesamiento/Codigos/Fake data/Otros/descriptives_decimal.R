# =============================================================================
#  Descriptive statistics of the data
# =============================================================================

lapply(c("haven", "dplyr", "purrr", "vctrs", "tibble"), function(p) {
  if (!require(p, character.only = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
})

# -----------------------------------------------------------------------------
# Helper Functions
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
# ADDED: Helper function to check if string contains decimal pattern
# -----------------------------------------------------------------------------

#' Check if a character variable contains decimal values (e.g., ".0")
#' @param x character vector
#' @return TRUE if any value contains a decimal point followed by digits
contains_decimal <- function(x) {
  x_clean <- x[!is.na(x)]
  if (length(x_clean) == 0) return(FALSE)
  any(grepl("\\.0", x_clean))  # ADDED: Check for ".0" pattern
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

  # ---------------------------------------------------------------------------
  # ADDED: Treat "" and " " as missing values (NA)
  # ---------------------------------------------------------------------------
  if (is.character(x)) {
    x[x == "" | x == " "] <- NA  # ADDED: Convert empty strings and single spaces to NA
    spec$missing_prop <- mean(is.na(x))  # ADDED: Recalculate missing proportion after conversion
  }
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # ADDED: Check if character variable should be treated as numeric
  # If the variable is character and contains ".0", convert to numeric
  # ---------------------------------------------------------------------------
  if (is.character(x) && contains_decimal(x)) {
    x <- as.numeric(x)  # ADDED: Convert string to numeric
  }
  # ---------------------------------------------------------------------------

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
