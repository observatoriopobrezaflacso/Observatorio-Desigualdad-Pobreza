
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
  
  # Handle single category case (sample doesn't work with size=1 and prob)
  if (length(spec$categories) == 1) {
    synthetic <- rep(spec$categories[1], n)
  } else {
    # Ensure probabilities match categories
    probs <- spec$category_probs
    if (is.null(probs) || length(probs) != length(spec$categories)) {
      # Use uniform probabilities if mismatch
      probs <- rep(1 / length(spec$categories), length(spec$categories))
    }
    
    # Generate synthetic values
    synthetic <- sample(spec$categories, size = n, replace = TRUE, prob = probs)
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
    
    # For large ranges or long IDs, generate digit by digit
    range_size <- id_max - id_min + 1
    if (range_size > 1e9 || id_length > 15) {
      # Very large IDs: generate each digit randomly
      synthetic <- replicate(n, {
        digits <- sample(0:9, id_length, replace = TRUE)
        # Ensure first digit is not 0 (unless id_length matches exactly)
        if (digits[1] == 0 && id_length > 1) digits[1] <- sample(1:9, 1)
        paste0(digits, collapse = "")
      })
    } else if (range_size > 1e7 || id_length > 9) {
      # Large but manageable: use runif and format as string
      synthetic_nums <- floor(runif(n, min = id_min, max = id_max + 1))
      # Convert to character and pad with zeros
      synthetic <- sprintf(paste0("%0", id_length, ".0f"), synthetic_nums)
    } else {
      # For smaller ranges, sample from sequence
      synthetic_nums <- sample(seq(id_min, id_max), size = n, replace = TRUE)
      synthetic <- sprintf(paste0("%0", id_length, "d"), as.integer(synthetic_nums))
    }
    
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
      # Numeric string IDs - handle large ranges
      id_length <- spec$id_length %||% spec$str_lengths[1] %||% 10
      range_size <- spec$id_max - spec$id_min + 1
      
      if (range_size > 1e9 || id_length > 15) {
        # Very large IDs: generate each digit randomly
        synthetic <- replicate(n, {
          digits <- sample(0:9, id_length, replace = TRUE)
          if (digits[1] == 0 && id_length > 1) digits[1] <- sample(1:9, 1)
          paste0(digits, collapse = "")
        })
      } else if (range_size > 1e7 || id_length > 9) {
        synthetic_nums <- floor(runif(n, min = spec$id_min, max = spec$id_max + 1))
        synthetic <- sprintf(paste0("%0", id_length, ".0f"), synthetic_nums)
      } else {
        synthetic_nums <- sample(seq(spec$id_min, spec$id_max), size = n, replace = TRUE)
        synthetic <- sprintf(paste0("%0", id_length, "d"), as.integer(synthetic_nums))
      }
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
    # Handle single category
    if (length(spec$categories) == 1) {
      synthetic <- rep(spec$categories[1], n)
    } else {
      probs <- spec$category_probs
      if (is.null(probs) || length(probs) != length(spec$categories)) {
        probs <- rep(1 / length(spec$categories), length(spec$categories))
      }
      synthetic <- sample(spec$categories, size = n, replace = TRUE, prob = probs)
    }
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

setwd("/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI")

fake_data <- fake_data_creation(data_spec2, n = data_spec$n_original, seed = 42)

# Validate
validate_synthetic_from_spec(fake_data, data_spec)


